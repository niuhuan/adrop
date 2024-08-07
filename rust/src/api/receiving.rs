use std::ops::{Deref, DerefMut};
use alipan::AdriveOpenFileType;
use alipan::response::AdriveOpenFile;
use async_recursion::async_recursion;
use base64::Engine;
use flutter_rust_bridge::for_generated::futures::TryStreamExt;
use lazy_static::lazy_static;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::Mutex;
use tokio_util::io::StreamReader;
use crate::api::download::download_info;
use crate::custom_crypto::{decrypt_file_name, decryptor_from_key};
use crate::data_obj::enums::{FileItemType, ReceivingTaskState};
use crate::data_obj::ReceivingTask;
use crate::define::{get_alipan_client, ram_space_info};
use crate::frb_generated::StreamSink;
use crate::utils::join_paths;

lazy_static! {
    static ref RECEIVING_TASKS: Mutex::<Vec<ReceivingTask>> = Mutex::new(Vec::new());
    static ref RECEIVING_CALL_BACKS: Mutex<Option<StreamSink<Vec<ReceivingTask>>>> = Mutex::new(None);
}

pub async fn register_receiving_task(listener: StreamSink<Vec<ReceivingTask>>) -> anyhow::Result<()> {
    let mut rcb = RECEIVING_CALL_BACKS.lock().await;
    *rcb = Some(listener);
    drop(rcb);
    Ok(())
}

pub async fn unregister_receiving_task() -> anyhow::Result<()> {
    let mut rcb = RECEIVING_CALL_BACKS.lock().await;
    *rcb = None;
    drop(rcb);
    Ok(())
}

pub async fn list_receiving_tasks() -> anyhow::Result<Vec<ReceivingTask>> {
    Ok(RECEIVING_TASKS.lock().await.clone())
}

async fn sync_tasks_to_dart(tasks: Vec<ReceivingTask>) -> anyhow::Result<()> {
    let rcb = RECEIVING_CALL_BACKS.lock().await;
    if let Some(rcb) = rcb.deref() {
        rcb.add(tasks)
            .map_err(|e| anyhow::anyhow!(e))?;
    }
    drop(rcb);
    Ok(())
}

pub(crate) async fn receiving_job() {
    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(15)).await;
        let space_info = if let Ok(space_info) = ram_space_info().await {
            if space_info.drive_id.is_empty() {
                continue;
            }
            space_info
        } else {
            println!("space info is failed");
            break;
        };
        let download_info = if let Ok(download_info) = download_info().await {
            if let Some(download_info) = download_info {
                download_info
            } else {
                println!("download info is empty");
                continue;
            }
        } else {
            println!("download info is failed");
            break;
        };
        let cloud_files = if let Ok(list_files) = list_files(
            space_info.drive_id.as_str(),
            space_info.this_device_folder_file_id.as_str(),
        ).await {
            list_files
        } else {
            continue;
        };
        let lock = RECEIVING_TASKS.lock().await;
        let exists_task_file_ids_string = lock.deref().iter().map(|x| x.file_id.clone()).collect::<Vec<String>>();
        drop(lock);
        let exists_task_file_ids = exists_task_file_ids_string.iter().map(|x| x.as_str()).collect::<Vec<&str>>();
        let password = if let Ok(password) = base64::prelude::BASE64_URL_SAFE.decode(space_info.true_pass_base64.as_str()) {
            password
        } else {
            println!("password decode failed");
            break;
        };
        let mut add_tasks = vec![];
        for x in &cloud_files {
            if x.name.ends_with(".adroptmp") {
                continue;
            }
            if exists_task_file_ids.contains(&x.file_id.as_str()) {
                continue;
            }
            let file_name = if let Ok(file_name) = decrypt_file_name(x.name.as_str(), password.as_slice()) {
                file_name
            } else {
                continue;
            };
            let (name, path, _tmp_path) = if let Ok(data) = take_file_name(
                download_info.download_to.as_str(),
                file_name.as_str(),
            ).await {
                data
            } else {
                break;
            };
            println!("添加任务 : {}", path);
            add_tasks.push(ReceivingTask {
                task_id: uuid::Uuid::new_v4().to_string(),
                drive_id: x.drive_id.clone(),
                file_id: x.file_id.clone(),
                file_name: name,
                file_path: path,
                file_item_type: {
                    match &x.r#type {
                        AdriveOpenFileType::File => FileItemType::File,
                        AdriveOpenFileType::Folder => FileItemType::Folder,
                    }
                },
                task_state: ReceivingTaskState::Init,
                error_msg: "".to_string(),
            });
        }
        if !add_tasks.is_empty() {
            let mut lock = RECEIVING_TASKS.lock().await;
            for x in add_tasks {
                lock.deref_mut().push(x);
            }
            let sync = lock.deref().clone();
            drop(lock);
            let _ = sync_tasks_to_dart(sync).await;
        }
        // download file
        loop {
            let mut task = None;
            let mut lock = RECEIVING_TASKS.lock().await;
            if lock.is_empty() {
                drop(lock);
                break;
            }
            for x in lock.deref_mut() {
                if x.task_state == ReceivingTaskState::Init {
                    x.task_state = ReceivingTaskState::Receiving;
                    task = Some(x.clone());
                    break;
                }
            }
            let sync = lock.deref().clone();
            drop(lock);
            let _ = sync_tasks_to_dart(sync).await;
            if let Some(task) = task {
                if let Err(e) = download_item(&task, password.as_slice()).await {
                    println!("下载出错 : {} : {}", task.file_path, e);
                    let mut lock = RECEIVING_TASKS.lock().await;
                    for x in lock.deref_mut() {
                        if x.task_id == task.task_id {
                            x.task_state = ReceivingTaskState::Failed;
                            x.error_msg = e.to_string();
                            break;
                        }
                    }
                    let sync = lock.deref().clone();
                    drop(lock);
                    let _ = sync_tasks_to_dart(sync).await;
                } else {
                    println!("下载成功 : {}", task.file_path);
                    let mut lock = RECEIVING_TASKS.lock().await;
                    for x in lock.deref_mut() {
                        if x.task_id == task.task_id {
                            x.task_state = ReceivingTaskState::Success;
                            break;
                        }
                    }
                    let sync = lock.deref().clone();
                    drop(lock);
                    let _ = sync_tasks_to_dart(sync).await;
                }
            } else {
                break;
            }
        }
    }
}

async fn take_file_name(download_to: &str, file_name: &str) -> anyhow::Result<(String, String, String)> {
    let raw_name_path = join_paths(vec![download_to, file_name]);
    let raw_name_path_tmp = raw_name_path.clone() + ".adroptmp";
    if tokio::fs::try_exists(raw_name_path.as_str()).await? || tokio::fs::try_exists(raw_name_path_tmp.as_str()).await? {
        let (file_name, ext) = if let Some(pos) = file_name.rfind(".") {
            let (file_name, ext) = file_name.split_at(pos);
            (file_name, ext)
        } else {
            (file_name, "")
        };
        let mut i = 1;
        loop {
            let new_file_name = format!("{}({}){}", file_name, i, ext);
            let new_raw_name_path = join_paths(vec![download_to, new_file_name.as_str()]);
            let new_raw_name_path_tmp = new_raw_name_path.clone() + ".adroptmp";
            if !tokio::fs::try_exists(new_raw_name_path.as_str()).await? && !tokio::fs::try_exists(new_raw_name_path_tmp.as_str()).await? {
                return Ok((new_file_name, new_raw_name_path, new_raw_name_path_tmp));
            }
            i += 1;
        }
    } else {
        return Ok((file_name.to_string(), raw_name_path, raw_name_path_tmp));
    }
}

async fn list_files(drive_id: &str, folder_id: &str) -> anyhow::Result<Vec<AdriveOpenFile>> {
    let client = get_alipan_client();
    let mut open_file_list: Vec<AdriveOpenFile> = vec![];
    let mut list = client
        .adrive_open_file_list()
        .await
        .drive_id(drive_id)
        .parent_file_id(folder_id)
        .request()
        .await?;
    for x in list.items {
        open_file_list.push(x);
    }
    while list.next_marker.is_some() {
        list = client
            .adrive_open_file_list()
            .await
            .drive_id(drive_id)
            .parent_file_id(folder_id)
            .marker(list.next_marker.unwrap())
            .request()
            .await?;
        for x in list.items {
            open_file_list.push(x);
        }
    }
    Ok(open_file_list)
}

async fn download_item(task: &ReceivingTask, password: &[u8]) -> anyhow::Result<()> {
    println!("download item: {}", task.file_path);
    let client = get_alipan_client();
    let cloud_file = client.adrive_open_file_get()
        .await
        .drive_id(task.drive_id.as_str())
        .file_id(task.file_id.as_str())
        .request()
        .await?;
    match &cloud_file.r#type {
        AdriveOpenFileType::File => {
            download_one_file(&cloud_file, task.file_path.as_str(), password).await
        }
        AdriveOpenFileType::Folder => {
            download_one_folder(&cloud_file, task.file_path.as_str(), password).await
        }
    }
}

async fn download_one_file(cloud_file: &AdriveOpenFile, file_path: &str, password: &[u8]) -> anyhow::Result<()> {
    println!("download file: {}", file_path);
    download_file(cloud_file, file_path, password).await?;
    remove_cloud_file(cloud_file).await?;
    Ok(())
}

async fn download_one_folder(cloud_file: &AdriveOpenFile, file_path: &str, password: &[u8]) -> anyhow::Result<()> {
    println!("download folder: {}", file_path);
    download_folder(cloud_file, file_path, password).await?;
    remove_cloud_file(cloud_file).await?;
    Ok(())
}

async fn download_file(cloud_file: &AdriveOpenFile, file_path: &str, password: &[u8]) -> anyhow::Result<()> {
    println!("download file: {}", file_path);
    let client = get_alipan_client();
    let url = client
        .adrive_open_file_get_download_url()
        .await
        .drive_id(cloud_file.drive_id.as_str())
        .file_id(cloud_file.file_id.as_str())
        .request()
        .await?
        .url;
    down_to_file_with_password(url, file_path, password).await?;
    Ok(())
}

#[async_recursion]
async fn download_folder(cloud_file: &AdriveOpenFile, file_path: &str, password: &[u8]) -> anyhow::Result<()> {
    println!("download folder: {}", file_path);
    tokio::fs::create_dir_all(file_path).await?;
    let children = list_files(cloud_file.drive_id.as_str(), cloud_file.file_id.as_str()).await?;
    for x in &children {
        let file_name = decrypt_file_name(x.name.as_str(), password)?;
        let file_path = join_paths(vec![file_path, file_name.as_str()]);
        match &x.r#type {
            AdriveOpenFileType::File => {
                download_file(x, file_path.as_str(), password).await?;
            }
            AdriveOpenFileType::Folder => {
                download_folder(x, file_path.as_str(), password).await?;
            }
        }
    }
    Ok(())
}

async fn remove_cloud_file(cloud_file: &AdriveOpenFile) -> anyhow::Result<()> {
    let client = get_alipan_client();
    client.adrive_open_file_recyclebin_trash()
        .await
        .drive_id(cloud_file.drive_id.as_str())
        .file_id(cloud_file.file_id.as_str())
        .request()
        .await?;
    Ok(())
}


async fn down_to_file_with_password(
    url: String,
    path: &str,
    password: &[u8],
) -> anyhow::Result<()> {
    let stream = reqwest::get(url)
        .await?
        .error_for_status()?
        .bytes_stream()
        .map_err(convert_err);
    let mut reader = StreamReader::new(stream);
    let mut file = tokio::fs::File::create(path).await?;
    let mut decryptor = decryptor_from_key(password)?;
    let mut buffer_data = vec![0u8; (1 << 20) + 16];
    let buffer = buffer_data.as_mut_slice();
    let mut position = 0;
    loop {
        let n = reader.read(&mut buffer[position..]).await?;
        position += n;
        if n == 0 {
            let item = decryptor
                .decrypt_last(&buffer[..position])
                .map_err(|e| anyhow::anyhow!("解密时出错(3): {}", e))?;
            file.write_all(&item).await?;
            file.flush().await?;
            break;
        }
        if position == buffer.len() {
            position = 0;
            let item = decryptor
                .decrypt_next(&buffer[..])
                .map_err(|e| anyhow::anyhow!("解密时出错(2): {}", e))?;
            file.write_all(&item).await?;
        }
    }
    Ok(())
}

fn convert_err(err: reqwest::Error) -> std::io::Error {
    std::io::Error::other(err)
}
