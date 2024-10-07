use std::cmp::max;
use crate::api::download::download_info;
use crate::custom_crypto::{decrypt_file_name, decryptor_from_key};
use crate::data_obj::enums::{FileItemType, ReceivingTaskClearType, ReceivingTaskState};
use crate::data_obj::ReceivingTask;
use crate::define::{get_alipan_client, ram_space_info};
use crate::frb_generated::StreamSink;
use crate::utils::join_paths;
use alipan::response::AdriveOpenFile;
use alipan::{AdriveClient, AdriveOpenFileType, ErrorInfo};
use async_recursion::async_recursion;
use base64::Engine;
use flutter_rust_bridge::for_generated::futures::TryStreamExt;
use lazy_static::lazy_static;
use std::ops::{Deref, DerefMut};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::Mutex;
use tokio_util::io::StreamReader;
use crate::database::properties::property::load_int_default_property;

lazy_static! {
    static ref RECEIVING_TASKS: Mutex::<Vec<ReceivingTask>> = Mutex::new(Vec::new());
    static ref RECEIVING_CALL_BACKS: Mutex<Option<StreamSink<Vec<ReceivingTask>>>> =
        Mutex::new(None);
    static ref RECEIVED_CALL_BACKS: Mutex<Option<StreamSink<ReceivingTask>>> =
        Mutex::new(None);
    static ref RECEIVE_LIMIT_TIME_WIDTH: Mutex<i64> = Mutex::new(60);
    static ref RECEIVE_LIMIT_TIME_FILE: Mutex<i64> = Mutex::new(3);
    static ref RECEIVE_LIMIT_TIME_WIDTH_START: Mutex<i64> = Mutex::new(0);
    static ref RECEIVE_LIMIT_TIME_FILE_COUNT: Mutex<i64> = Mutex::new(0);
}

pub async fn register_receiving_task(
    listener: StreamSink<Vec<ReceivingTask>>,
) -> anyhow::Result<()> {
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

pub async fn register_received(
    listener: StreamSink<ReceivingTask>,
) -> anyhow::Result<()> {
    let mut rcb = RECEIVED_CALL_BACKS.lock().await;
    *rcb = Some(listener);
    drop(rcb);
    Ok(())
}

pub async fn unregister_received() -> anyhow::Result<()> {
    let mut rcb = RECEIVED_CALL_BACKS.lock().await;
    *rcb = None;
    drop(rcb);
    Ok(())
}

async fn notify_received(task: ReceivingTask) -> anyhow::Result<()> {
    let rcb = RECEIVED_CALL_BACKS.lock().await;
    if let Some(rcb) = rcb.deref() {
        rcb.add(task).map_err(|e| anyhow::anyhow!(e))?;
    }
    drop(rcb);
    Ok(())
}

pub async fn list_receiving_tasks() -> anyhow::Result<Vec<ReceivingTask>> {
    Ok(RECEIVING_TASKS.lock().await.clone())
}

pub async fn clear_receiving_tasks(clear_types: Vec<ReceivingTaskClearType>) -> anyhow::Result<()> {
    let download_info = if let Ok(download_info) = download_info().await {
        if let Some(download_info) = download_info {
            download_info
        } else {
            return Err(anyhow::anyhow!("download info is empty"));
        }
    } else {
        return Err(anyhow::anyhow!("download info is failed"));
    };
    let mut lock = RECEIVING_TASKS.lock().await;
    for clear_type in clear_types {
        match clear_type {
            ReceivingTaskClearType::Unset => {}
            ReceivingTaskClearType::ClearSuccess => {
                lock.retain(|x| x.task_state != ReceivingTaskState::Success);
            }
            ReceivingTaskClearType::RetryFailed => {
                for x in lock.deref_mut() {
                    if x.task_state == ReceivingTaskState::Failed {
                        x.task_state = ReceivingTaskState::Init;
                        match x.file_item_type {
                            FileItemType::File => {
                                let _ = tokio::fs::remove_file(x.file_path.as_str()).await;
                            }
                            FileItemType::Folder => {
                                let _ = tokio::fs::remove_dir_all(x.file_path.as_str()).await;
                            }
                        }
                        if let Ok((_name, path, _tmp_path)) =
                            take_file_name(download_info.download_to.as_str(), x.file_name.as_str()).await
                        {
                            x.file_path = path;
                        };
                    }
                }
            }
            ReceivingTaskClearType::CancelFailedAndDeleteCloud => {
                let space_info = ram_space_info().await?;
                let client = get_alipan_client();
                let mut remove_task_id_list = vec![];
                let mut remove_failed_task_list = vec![];
                for x in lock.deref() {
                    if x.task_state == ReceivingTaskState::Failed {
                        if let Err(err) = client
                            .adrive_open_file_recyclebin_trash()
                            .await
                            .drive_id(space_info.drive_id.as_str())
                            .file_id(x.file_id.as_str())
                            .request()
                            .await
                        {
                            match err.inner {
                                ErrorInfo::ServerError(err) => {
                                    if err.code == "404" {
                                        remove_task_id_list.push(x.task_id.clone());
                                    } else {
                                        remove_failed_task_list.push(x.clone());
                                    }
                                }
                                _ => {
                                    remove_failed_task_list.push(x.clone());
                                }
                            }
                        };
                        remove_task_id_list.push(x.task_id.clone());
                    }
                }
                for x in lock.deref() {
                    if remove_task_id_list.contains(&x.task_id) {
                        match x.file_item_type {
                            FileItemType::File => {
                                let _ = tokio::fs::remove_file(x.file_path.as_str()).await;
                            }
                            FileItemType::Folder => {
                                let _ = tokio::fs::remove_dir_all(x.file_path.as_str()).await;
                            }
                        }
                    }
                }
                lock.retain(|x| !remove_task_id_list.contains(&x.task_id));
                // todo 通知失败的任务
            }
        }
    }
    let sync = lock.deref().clone();
    drop(lock);
    let _ = sync_tasks_to_dart(sync).await;
    Ok(())
}

pub async fn receiving_task_set_removed(task_id: String, reason: i64) -> anyhow::Result<()> {
    let mut lock = RECEIVING_TASKS.lock().await;
    for x in lock.deref_mut() {
        if x.task_id == task_id {
            x.file_removed = reason;
            break;
        }
    }
    let sync = lock.deref().clone();
    drop(lock);
    let _ = sync_tasks_to_dart(sync).await;
    Ok(())
}

async fn sync_tasks_to_dart(tasks: Vec<ReceivingTask>) -> anyhow::Result<()> {
    let rcb = RECEIVING_CALL_BACKS.lock().await;
    if let Some(rcb) = rcb.deref() {
        rcb.add(tasks).map_err(|e| anyhow::anyhow!(e))?;
    }
    drop(rcb);
    Ok(())
}

async fn exists_task_file_ids() -> Vec<String> {
    let lock = RECEIVING_TASKS.lock().await;
    let exists_task_file_ids_string = lock
        .deref()
        .iter()
        .map(|x| x.file_id.clone())
        .collect::<Vec<String>>();
    drop(lock);
    exists_task_file_ids_string
}

async fn first_init_receiving_tasks() -> Option<ReceivingTask> {
    let mut lock = RECEIVING_TASKS.lock().await;
    if lock.is_empty() {
        drop(lock);
        return None;
    }
    for x in lock.deref_mut() {
        if x.task_state == ReceivingTaskState::Init {
            let task = Some(x.clone());
            drop(lock);
            return task;
        }
    }
    drop(lock);
    return None;
}

async fn set_receiving_task_by_id(task: &ReceivingTask) -> anyhow::Result<()> {
    let mut lock = RECEIVING_TASKS.lock().await;
    let list = lock.deref_mut();
    let mut idx = None;
    for i in 0..list.len() {
        if list[i].task_id == task.task_id {
            idx = Some(i);
            break;
        }
    }
    if let Some(idx) = idx {
        list[idx] = task.clone();
        let sync = lock.deref().clone();
        drop(lock);
        let _ = sync_tasks_to_dart(sync).await;
        Ok(())
    } else {
        drop(lock);
        Err(anyhow::anyhow!("task not found"))
    }
}

pub(crate) async fn receiving_job() {
    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(15)).await;
        let mut lock = RECEIVE_LIMIT_TIME_WIDTH.lock().await;
        *lock = match load_int_default_property("receive_limit_time_width", 60).await {
            Ok(value) => value,
            Err(err) => {
                println!("load receive_limit_time_width failed: {}", err);
                return;
            }
        };
        drop(lock);
        let mut lock = RECEIVE_LIMIT_TIME_FILE.lock().await;
        *lock = match load_int_default_property("receive_limit_time_file", 3).await {
            Ok(value) => value,
            Err(err) => {
                println!("load receive_limit_time_file failed: {}", err);
                return;
            }
        };
        drop(lock);
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
        )
            .await
        {
            list_files
        } else {
            continue;
        };
        let exists_task_file_ids_string = exists_task_file_ids().await;
        let exists_task_file_ids = exists_task_file_ids_string
            .iter()
            .map(|x| x.as_str())
            .collect::<Vec<&str>>();
        let password = if let Ok(password) =
            base64::prelude::BASE64_URL_SAFE.decode(space_info.true_pass_base64.as_str())
        {
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
            let file_name =
                if let Ok(file_name) = decrypt_file_name(x.name.as_str(), password.as_slice()) {
                    file_name
                } else {
                    continue;
                };
            let (name, path, _tmp_path) = if let Ok(data) =
                take_file_name(download_info.download_to.as_str(), file_name.as_str()).await
            {
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
                file_removed: 0,
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
            let task = first_init_receiving_tasks().await;
            if let Some(mut task) = task {
                if need_continue_receive().await {
                    continue;
                }
                task.task_state = ReceivingTaskState::Receiving;
                if let Err(err) = set_receiving_task_by_id(&task).await {
                    println!("设置任务状态失败 : {}", err);
                    break;
                }
                if let Err(e) = download_item(&task, password.as_slice()).await {
                    println!("下载出错 : {} : {}", task.file_path, e);
                    task.task_state = ReceivingTaskState::Failed;
                    task.error_msg = e.to_string();
                    if let Err(err) = set_receiving_task_by_id(&task).await {
                        println!("设置任务状态失败 : {}", err);
                        break;
                    }
                } else {
                    println!("下载成功 : {}", task.file_path);
                    task.task_state = ReceivingTaskState::Success;
                    if let Err(err) = set_receiving_task_by_id(&task).await {
                        println!("设置任务状态失败 : {}", err);
                        break;
                    }
                    let _ = notify_received(task).await;
                }
                download_count_up().await;
            } else {
                break;
            }
        }
    }
}

pub(crate) async fn need_continue_receive() -> bool {
    let width_guard = RECEIVE_LIMIT_TIME_WIDTH.lock().await;
    let width = *width_guard;
    drop(width_guard);
    let file_guard = RECEIVE_LIMIT_TIME_FILE.lock().await;
    let file = *file_guard;
    drop(file_guard);
    let now = chrono::Utc::now().timestamp();
    let mut current_guard = RECEIVE_LIMIT_TIME_WIDTH_START.lock().await;
    let mut count_guard = RECEIVE_LIMIT_TIME_FILE_COUNT.lock().await;
    if *current_guard < now - width {
        *current_guard = now;
        *count_guard = 0;
        drop(count_guard);
        drop(current_guard);
        false
    } else if *count_guard < file {
        drop(count_guard);
        drop(current_guard);
        false
    } else {
        let sleep_time = max(width - (now - *current_guard), 1);
        drop(count_guard);
        drop(current_guard);
        tokio::time::sleep(tokio::time::Duration::from_secs(sleep_time as u64)).await;
        true
    }
}

async fn download_count_up() {
    let mut count = RECEIVE_LIMIT_TIME_FILE_COUNT.lock().await;
    *count += 1;
    drop(count);
}

async fn take_file_name(
    download_to: &str,
    file_name: &str,
) -> anyhow::Result<(String, String, String)> {
    let raw_name_path = join_paths(vec![download_to, file_name]);
    let raw_name_path_tmp = raw_name_path.clone() + ".adroptmp";
    if tokio::fs::try_exists(raw_name_path.as_str()).await?
        || tokio::fs::try_exists(raw_name_path_tmp.as_str()).await?
    {
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
            if !tokio::fs::try_exists(new_raw_name_path.as_str()).await?
                && !tokio::fs::try_exists(new_raw_name_path_tmp.as_str()).await?
            {
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
    let cloud_file = client
        .adrive_open_file_get()
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

async fn download_one_file(
    cloud_file: &AdriveOpenFile,
    file_path: &str,
    password: &[u8],
) -> anyhow::Result<()> {
    println!("download file: {}", file_path);
    download_file(cloud_file, file_path, password).await?;
    remove_cloud_file(cloud_file).await?;
    Ok(())
}

async fn download_one_folder(
    cloud_file: &AdriveOpenFile,
    file_path: &str,
    password: &[u8],
) -> anyhow::Result<()> {
    println!("download folder: {}", file_path);
    download_folder(cloud_file, file_path, password).await?;
    remove_cloud_file(cloud_file).await?;
    Ok(())
}

async fn download_file(
    cloud_file: &AdriveOpenFile,
    file_path: &str,
    password: &[u8],
) -> anyhow::Result<()> {
    println!("download file: {}", file_path);
    let client = get_alipan_client();
    let url = get_download_url(client, cloud_file.drive_id.as_str(), cloud_file.file_id.as_str()).await?;
    down_to_file_with_password(url, file_path, password).await?;
    Ok(())
}

async fn get_download_url(client: &AdriveClient, drive_id: &str, file_id: &str) -> anyhow::Result<String> {
    loop {
        let response = client
            .adrive_open_file_get_download_url()
            .await
            .drive_id(drive_id)
            .file_id(file_id)
            .request()
            .await;
        match response {
            Ok(response) => {
                return Ok(response.url);
            }
            Err(err) => {
                match err.inner {
                    ErrorInfo::ServerError(err) => {
                        if err.code.eq("TooManyRequests") {
                            tokio::time::sleep(tokio::time::Duration::from_secs(10)).await;
                            continue;
                        }
                    }
                    err => {
                        return Err(anyhow::anyhow!("获取下载链接失败: {}", err));
                    }
                }
            }
        }
    }
}

#[async_recursion]
async fn download_folder(
    cloud_file: &AdriveOpenFile,
    file_path: &str,
    password: &[u8],
) -> anyhow::Result<()> {
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
    client
        .adrive_open_file_recyclebin_trash()
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
