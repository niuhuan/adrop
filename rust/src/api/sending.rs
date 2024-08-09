use crate::common::PutResource;
use crate::custom_crypto::{encrypt_file_name, encryptor_from_key};
use crate::data_obj::enums::{
    FileItemType, SendingTaskClearType, SendingTaskErrorType, SendingTaskState,
};
use crate::data_obj::{Device, SelectionFile, SendingTask};
use crate::define::{get_alipan_client, ram_space_info};
use crate::frb_generated::StreamSink;
use alipan::{
    AdriveOpenFileCreate, AdriveOpenFilePartInfoCreate, AdriveOpenFileType, CheckNameMode,
};
use anyhow::Context;
use async_recursion::async_recursion;
use async_trait::async_trait;
use base64::Engine;
use lazy_static::lazy_static;
use sha1::Digest;
use std::ops::{Deref, DerefMut};
use std::sync::Arc;
use tokio::io::AsyncReadExt;
use tokio::sync::Mutex;

lazy_static! {
    static ref SENDING_TASKS: Mutex<Vec<SendingTask>> = Mutex::new(vec![]);
    static ref SENDING_CALL_BACKS: Mutex<Option<StreamSink<Vec<SendingTask>>>> = Mutex::new(None);
}

pub async fn register_sending_listener(
    listener: StreamSink<Vec<SendingTask>>,
) -> anyhow::Result<()> {
    let mut scb = SENDING_CALL_BACKS.lock().await;
    *scb = Some(listener);
    drop(scb);
    Ok(())
}

pub async fn unregister_sending_listener() -> anyhow::Result<()> {
    let mut scb = SENDING_CALL_BACKS.lock().await;
    *scb = None;
    drop(scb);
    Ok(())
}

pub async fn list_sending_tasks() -> anyhow::Result<Vec<crate::data_obj::SendingTask>> {
    Ok(SENDING_TASKS.lock().await.clone())
}

pub async fn add_sending_tasks(
    device: Device,
    selection_files: Vec<SelectionFile>,
) -> anyhow::Result<()> {
    let tasks = selection_files
        .into_iter()
        .map(|value| SendingTask {
            task_id: uuid::Uuid::new_v4().to_string(),
            device: device.clone(),
            file_name: value.name,
            file_path: value.path,
            file_item_type: value.file_item_type,
            task_state: SendingTaskState::Init,
            error_msg: "".to_string(),
            cloud_file_id: "".to_string(),
            error_type: SendingTaskErrorType::Unset,
            current_file_upload_size: 0,
        })
        .collect::<Vec<SendingTask>>();
    let mut lock = SENDING_TASKS.lock().await;
    for task in tasks {
        lock.push(task);
    }
    let tasks = lock.clone();
    drop(lock);
    let _ = sync_tasks_to_dart(tasks).await;
    Ok(())
}

pub async fn clear_sending_tasks(clear_types: Vec<SendingTaskClearType>) -> anyhow::Result<()> {
    let mut lock = SENDING_TASKS.lock().await;
    for clear_type in clear_types {
        match clear_type {
            SendingTaskClearType::Unset => {}
            SendingTaskClearType::ClearSuccess => {
                lock.retain(|x| x.task_state != SendingTaskState::Success);
            }
            SendingTaskClearType::CancelFailed => {
                let (remove_task_ids, fail_task_list) =
                    can_reset_sending_task_list(lock.deref()).await?;
                lock.retain(|x| !remove_task_ids.contains(&x.task_id));
                // todo 提示用户 fail_task_list
            }
            SendingTaskClearType::RetryFailed => {
                let (reset_task_ids, fail_task_list) =
                    can_reset_sending_task_list(lock.deref()).await?;
                for x in lock.deref_mut() {
                    if reset_task_ids.contains(&x.task_id) {
                        x.task_state = SendingTaskState::Init;
                        x.error_msg = "".to_string();
                        x.cloud_file_id = "".to_string();
                        x.current_file_upload_size = 0;
                    }
                }
                // todo 提示用户 fail_task_list
            }
        }
    }
    let tasks = lock.clone();
    drop(lock);
    let _ = sync_tasks_to_dart(tasks).await;
    Ok(())
}

async fn can_reset_sending_task_list(
    task_list: &Vec<SendingTask>,
) -> anyhow::Result<(Vec<String>, Vec<String>)> {
    let client = get_alipan_client();
    let space_info = ram_space_info().await?;
    let mut reset_task_ids = vec![];
    let mut reset_fail_task_ids = vec![];
    for task in task_list {
        if task.task_state == SendingTaskState::Failed {
            match task.file_item_type {
                FileItemType::File => {
                    reset_task_ids.push(task.task_id.clone());
                    let _ = tokio::fs::remove_file(task.file_path.as_str()).await;
                }
                FileItemType::Folder => {
                    if !task.cloud_file_id.is_empty() {
                        if let Err(err) = client
                            .adrive_open_file_recyclebin_trash()
                            .await
                            .drive_id(space_info.drive_id.as_str())
                            .file_id(task.cloud_file_id.as_str())
                            .request()
                            .await
                        {
                            match err.inner {
                                alipan::ErrorInfo::ServerError(server_error) => {
                                    if server_error.code == "404" {
                                        reset_task_ids.push(task.task_id.clone());
                                        let _ = tokio::fs::remove_dir_all(task.file_path.as_str())
                                            .await;
                                    } else {
                                        reset_fail_task_ids.push(task.task_id.clone());
                                    }
                                }
                                _ => {
                                    reset_fail_task_ids.push(task.task_id.clone());
                                }
                            }
                        } else {
                            reset_task_ids.push(task.task_id.clone());
                            let _ = tokio::fs::remove_dir_all(task.file_path.as_str()).await;
                        }
                    } else {
                        reset_task_ids.push(task.task_id.clone());
                        let _ = tokio::fs::remove_dir_all(task.file_path.as_str()).await;
                    }
                }
            }
        }
    }
    Ok((reset_task_ids, reset_fail_task_ids))
}

async fn sync_tasks_to_dart(tasks: Vec<SendingTask>) -> anyhow::Result<()> {
    let scb = SENDING_CALL_BACKS.lock().await;
    if let Some(scb) = scb.deref() {
        scb.add(tasks).map_err(|e| anyhow::anyhow!(e))?;
    }
    drop(scb);
    Ok(())
}

async fn first_init_sending_task() -> Option<SendingTask> {
    let mut lock = SENDING_TASKS.lock().await;
    if lock.is_empty() {
        drop(lock);
        return None;
    }
    for x in lock.deref_mut() {
        if x.task_state == SendingTaskState::Init {
            x.task_state = SendingTaskState::Sending;
            let need_sent = Some(x.clone());
            drop(lock);
            return need_sent;
        }
    }
    drop(lock);
    return None;
}

async fn set_sending_task_by_id(task: &SendingTask) -> anyhow::Result<()> {
    let mut lock = SENDING_TASKS.lock().await;
    // for i
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
    } else {
        return Err(anyhow::anyhow!("task not found"));
    }
    let tasks = lock.deref().clone();
    drop(lock);
    let _ = sync_tasks_to_dart(tasks).await;
    Ok(())
}

#[derive(Debug)]
struct SendingController(Arc<Mutex<SendingTask>>);

impl Clone for SendingController {
    fn clone(&self) -> Self {
        Self(Arc::clone(&self.0))
    }
}

impl SendingController {
    async fn set_data<F>(&self, f: F)
    where
        F: FnOnce(&mut SendingTask),
    {
        let mut lock = self.0.lock().await;
        f(lock.deref_mut());
        drop(lock);
    }

    async fn get_data<F, T>(&self, f: F) -> T
    where
        F: FnOnce(&SendingTask) -> T,
    {
        let lock = self.0.lock().await;
        let result = f(lock.deref());
        drop(lock);
        result
    }

    async fn sync(&self) -> anyhow::Result<()> {
        let send_task = self.0.lock().await.clone();
        set_sending_task_by_id(&send_task).await?;
        drop(send_task);
        Ok(())
    }
}

#[async_trait]
trait FileCreateCallBack: Sync + Send {
    async fn call(&self, open_file: &AdriveOpenFileCreate) -> anyhow::Result<()>;
}

struct SetTaskFileId(SendingController);

#[async_trait]
impl FileCreateCallBack for SetTaskFileId {
    async fn call(&self, open_file: &AdriveOpenFileCreate) -> anyhow::Result<()> {
        self.0
            .set_data(|send_task: &mut SendingTask| {
                send_task.cloud_file_id = open_file.file_id.clone();
            })
            .await;
        let _ = self.0.sync().await;
        Ok(())
    }
}

#[async_trait]
trait FileLengthCallback: Sync + Send {
    async fn call(&self, processed: usize) -> anyhow::Result<()>;
}

#[async_trait]
impl FileLengthCallback for SetTaskFileId {
    async fn call(&self, processed: usize) -> anyhow::Result<()> {
        self.0
            .set_data(|send_task: &mut SendingTask| {
                send_task.current_file_upload_size = processed as i64;
            })
            .await;
        println!("processed: {}", processed);
        self.0.sync().await?;
        Ok(())
    }
}

pub(crate) async fn sending_job() {
    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
        if let Ok(space_info) = ram_space_info().await {
            if space_info.drive_id.is_empty() {
                continue;
            }
        } else {
            println!("space info is failed");
            break;
        }
        loop {
            let need_processing = first_init_sending_task().await;
            if let Some(need_processing) = need_processing {
                let task_controller = SendingController(Arc::new(Mutex::new(need_processing)));
                task_controller
                    .set_data(|send_task: &mut SendingTask| {
                        send_task.task_state = SendingTaskState::Sending;
                    })
                    .await;
                if let Err(err) = task_controller.sync().await {
                    println!("set sending task failed: {:?}", err);
                    break;
                }
                println!("start send : {:?}", task_controller);
                if let Err(e) = send_file(task_controller.clone()).await {
                    println!("send file failed: {:?} : {:?}", task_controller, e);
                    task_controller
                        .set_data(|send_task: &mut SendingTask| {
                            send_task.task_state = SendingTaskState::Failed;
                            send_task.error_msg = e.to_string();
                        })
                        .await;
                } else {
                    println!("send file success: {:?}", task_controller);
                    task_controller
                        .set_data(|send_task: &mut SendingTask| {
                            send_task.task_state = SendingTaskState::Success;
                        })
                        .await;
                }
                if let Err(err) = task_controller.sync().await {
                    println!("set sending task failed: {:?}", err);
                    break;
                }
            } else {
                break;
            }
        }
    }
}

async fn send_file(controller: SendingController) -> anyhow::Result<()> {
    let (file_name, file_path, device) = controller
        .get_data(|send_task| {
            (
                send_task.file_name.clone(),
                send_task.file_path.clone(),
                send_task.device.clone(),
            )
        })
        .await;
    let file_state = tokio::fs::metadata(file_path.as_str()).await;
    let meta = match file_state {
        Ok(meta) => meta,
        Err(e) => return Err(anyhow::anyhow!(e)),
    };
    if meta.is_dir() {
        upload_folder(
            file_name.as_str(),
            file_path.as_str(),
            device.folder_file_id.as_str(),
            Some(Box::new(SetTaskFileId(controller))),
        )
        .await?;
    } else if meta.is_file() {
        upload_file(
            file_name.as_str(),
            file_path.as_str(),
            device.folder_file_id.as_str(),
            Some(Box::new(SetTaskFileId(controller))),
        )
        .await?;
    }
    Ok(())
}

#[async_recursion]
async fn upload_folder(
    folder_name: &str,
    folder_path: &str,
    parent_folder_id: &str,
    option: Option<Box<dyn FileCreateCallBack>>,
) -> anyhow::Result<()> {
    let space_info = ram_space_info().await?;
    let password = base64::prelude::BASE64_URL_SAFE.decode(space_info.true_pass_base64.as_str())?;
    let alipan_file_name = encrypt_file_name(folder_name, password.as_slice())?;
    let alipan_file_name_tmp = format!("{}.tmp", alipan_file_name);
    //
    let client = get_alipan_client();
    let folder_result = client
        .adrive_open_file_create()
        .await
        .drive_id(space_info.drive_id.as_str())
        .parent_file_id(parent_folder_id)
        .name(alipan_file_name_tmp.as_str())
        .r#type(AdriveOpenFileType::Folder)
        .check_name_mode(CheckNameMode::Refuse)
        .request()
        .await?;
    if let Some(callback) = option {
        callback.call(&folder_result).await?;
    }
    let mut entries = tokio::fs::read_dir(folder_path).await?;
    while let Some(entry) = entries.next_entry().await? {
        let meta = entry.metadata().await?;
        if meta.is_dir() {
            upload_folder(
                entry.file_name().to_str().unwrap(),
                entry.path().to_str().unwrap(),
                folder_result.file_id.as_str(),
                None,
            )
            .await?;
        } else if meta.is_file() {
            upload_file(
                entry.file_name().to_str().unwrap(),
                entry.path().to_str().unwrap(),
                folder_result.file_id.as_str(),
                None,
            )
            .await?;
        }
    }
    let _ = client
        .adrive_open_file_update()
        .await
        .drive_id(space_info.drive_id.as_str())
        .file_id(folder_result.file_id.as_str())
        .name(alipan_file_name.as_str())
        .check_name_mode(CheckNameMode::Refuse)
        .starred(false)
        .request()
        .await?;
    Ok(())
}

async fn upload_file(
    file_name: &str,
    file_path: &str,
    parent_folder_id: &str,
    option: Option<Box<dyn FileLengthCallback>>,
) -> anyhow::Result<()> {
    let space_info = ram_space_info().await?;
    let password = base64::prelude::BASE64_URL_SAFE.decode(space_info.true_pass_base64.as_str())?;
    let alipan_file_name = encrypt_file_name(file_name, password.as_slice())?;
    let client = get_alipan_client();
    let (sha1, size) = password_sha1(file_path, password.as_slice()).await?;
    let parts = vec![AdriveOpenFilePartInfoCreate { part_number: 1 }];
    let result = client
        .adrive_open_file_create()
        .await
        .check_name_mode(CheckNameMode::Refuse)
        .drive_id(space_info.drive_id.as_str())
        .parent_file_id(parent_folder_id)
        .name(alipan_file_name)
        .r#type(AdriveOpenFileType::File)
        .size(size as i64)
        .content_hash_name("sha1")
        .content_hash(sha1)
        .part_info_list(parts)
        .request()
        .await?;
    println!("upload file result: {:?}", result);
    if result.rapid_upload {
        return Ok(());
    }
    if result.exist {
        return Err(anyhow::anyhow!("文件已存在"));
    }
    let url = result.part_info_list[0].upload_url.clone();
    put_file_with_password(file_path, password.as_slice(), url.as_str(), option).await?;
    client
        .adrive_open_file_complete()
        .await
        .drive_id(result.drive_id.as_str())
        .file_id(result.file_id.as_str())
        .upload_id(
            result
                .upload_id
                .with_context(|| "upload_id is empty")?
                .as_str(),
        )
        .request()
        .await?;
    Ok(())
}

async fn password_sha1(file_path: &str, password: &[u8]) -> anyhow::Result<(String, u64)> {
    let file = tokio::fs::File::open(file_path)
        .await
        .with_context(|| format!("读取文件失败: {}", file_path))?;
    let mut hasher = sha1::Sha1::new();
    let mut encryptor = encryptor_from_key(password)?;
    let mut reader = tokio::io::BufReader::new(file);
    let mut buffer_data = vec![0u8; 1 << 20];
    let buffer = buffer_data.as_mut_slice();
    let mut size = 0;
    let mut position = 0;
    loop {
        let n = reader.read(&mut buffer[position..]).await?;
        position += n;
        if n == 0 {
            let b = encryptor
                .encrypt_last(&buffer[..position])
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            hasher.update(b.as_slice());
            size += b.len();
            break;
        }
        if position == buffer.len() {
            position = 0;
            let b = encryptor
                .encrypt_next(&buffer[..n])
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            hasher.update(b.as_slice());
            size += b.len();
        }
    }
    let result = hasher.finalize();
    Ok((hex::encode(result), size as u64))
}

async fn put_file_with_password(
    file_path: &str,
    password: &[u8],
    url: &str,
    option: Option<Box<dyn FileLengthCallback>>,
) -> anyhow::Result<()> {
    let (sender, body) = PutResource::channel_resource();
    let request = reqwest::Client::new().put(url).body(body).send();
    let cp = sender.clone();
    let read_file_back = async move {
        let result = put_steam_with_password(cp, file_path, password, option).await;
        if let Err(e) = result {
            let _ = sender.send(Err(e)).await;
        }
    };
    let (send, _read) = tokio::join!(request, read_file_back);
    send?.error_for_status()?;
    Ok(())
}

async fn put_steam_with_password(
    sender: tokio::sync::mpsc::Sender<anyhow::Result<Vec<u8>>>,
    path: &str,
    password: &[u8],
    option: Option<Box<dyn FileLengthCallback>>,
) -> anyhow::Result<()> {
    let mut processed = 0;
    let mut buffer = vec![0u8; 1 << 20];
    let file = tokio::fs::File::open(path).await?;
    let mut reader = tokio::io::BufReader::new(file);
    let mut encryptor = encryptor_from_key(password)?;
    let mut position = 0;
    loop {
        let n = reader.read(&mut buffer[position..]).await?;
        position += n;
        if n == 0 {
            let enc = encryptor.encrypt_last(&buffer[..position]);
            match enc {
                Ok(vec) => {
                    sender.send(Ok(vec)).await?;
                    processed += position;
                    if let Some(call) = &option {
                        call.call(processed).await?;
                    }
                }
                Err(err) => {
                    sender.send(Err(anyhow::anyhow!("{}", err))).await?;
                    return Err(anyhow::anyhow!("{}", err));
                }
            }
            break;
        }
        if position == buffer.len() {
            position = 0;
            match encryptor.encrypt_next(&buffer[..]) {
                Ok(vec) => {
                    sender.send(Ok(vec)).await?;
                    processed += buffer.len();
                    if let Some(call) = &option {
                        call.call(processed).await?;
                    }
                }
                Err(err) => {
                    sender.send(Err(anyhow::anyhow!("{}", err))).await?;
                    return Err(anyhow::anyhow!("{}", err));
                }
            }
        }
    }
    Ok(())
}
