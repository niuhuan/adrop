use crate::api::space::create_folder;
use crate::custom_crypto::{encrypt_file_name, encryptor_from_key};
use crate::data_obj::enums::SendingTaskState;
use crate::data_obj::SendingTask;
use crate::define::{get_alipan_client, ram_space_info};
use crate::frb_generated::StreamSink;
use alipan::{AdriveOpenFilePartInfoCreate, AdriveOpenFileType, CheckNameMode};
use anyhow::Context;
use async_recursion::async_recursion;
use base64::Engine;
use flutter_rust_bridge::for_generated::futures::SinkExt;
use lazy_static::lazy_static;
use std::ops::DerefMut;
use std::sync::Arc;
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

pub async fn add_sending_tasks(tasks: Vec<crate::data_obj::SendingTask>) -> anyhow::Result<()> {
    let mut lock = SENDING_TASKS.lock().await;
    for task in tasks {
        lock.push(task);
    }
    let tasks = lock.clone();
    drop(lock);
    log_log(sync_tasks_to_dart(tasks).await);
    Ok(())
}

async fn sync_tasks_to_dart(tasks: Vec<crate::data_obj::SendingTask>) -> anyhow::Result<()> {
    let scb = SENDING_CALL_BACKS.lock().await;
    if let Some(scb) = &*scb {
        scb.add(SENDING_TASKS.lock().await.clone())
            .map_err(|e| anyhow::anyhow!(e))?;
    }
    drop(scb);
    Ok(())
}

fn log_log<T>(r: anyhow::Result<T>) {
    if let Err(e) = r {
        println!("{:?}", e);
    }
}

pub(crate) async fn sending_job() {
    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
        loop {
            let mut lock = SENDING_TASKS.lock().await;
            if lock.is_empty() {
                drop(lock);
                break;
            }
            let mut need_sent = None;
            for x in lock.deref_mut() {
                if x.task_state == SendingTaskState::Init {
                    x.task_state = SendingTaskState::Sending;
                    need_sent = Some(x.clone());
                    break;
                }
            }
            let _ = sync_tasks_to_dart(lock.clone()).await;
            drop(lock);
            if let Some(mut need_sent) = need_sent {
                if let Err(e) = send_file(&need_sent).await {
                    let mut lock = SENDING_TASKS.lock().await;
                    for x in lock.deref_mut() {
                        if x.task_id == need_sent.task_id {
                            x.task_state = SendingTaskState::Failed;
                            x.error_msg = e.to_string();
                            break;
                        }
                    }
                    let _ = sync_tasks_to_dart(lock.clone()).await;
                    drop(lock);
                } else {
                    let mut lock = SENDING_TASKS.lock().await;
                    for x in lock.deref_mut() {
                        if x.task_id == need_sent.task_id {
                            x.task_state = SendingTaskState::Success;
                            break;
                        }
                    }
                    let _ = sync_tasks_to_dart(lock.clone()).await;
                    drop(lock);
                }
            } else {
                break;
            }
        }
    }
}

async fn send_file(task: &SendingTask) -> anyhow::Result<()> {
    let file_state = tokio::fs::metadata(task.file_path.as_str()).await;
    let meta = match file_state {
        Ok(meta) => meta,
        Err(e) => return Err(anyhow::anyhow!(e)),
    };
    if meta.is_dir() {
        upload_folder(
            task.file_name.as_str(),
            task.file_path.as_str(),
            task.device.folder_file_id.as_str(),
        )
        .await?;
    } else if meta.is_file() {
        upload_file(
            task.file_name.as_str(),
            task.file_path.as_str(),
            task.device.folder_file_id.as_str(),
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
    let mut entries = tokio::fs::read_dir(folder_path).await?;
    while let Some(entry) = entries.next_entry().await? {
        let meta = entry.metadata().await?;
        if meta.is_dir() {
            upload_folder(
                entry.file_name().to_str().unwrap(),
                entry.path().to_str().unwrap(),
                folder_result.file_id.as_str(),
            )
            .await?;
        } else if meta.is_file() {
            upload_file(
                entry.file_name().to_str().unwrap(),
                entry.path().to_str().unwrap(),
                folder_result.file_id.as_str(),
            )
            .await?;
        }
    }
    let _ = client
        .adrive_open_file_update()
        .await
        .drive_id(space_info.drive_id.as_str())
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
    if result.rapid_upload {
        return Ok(());
    }
    if result.exist {
        return Err(anyhow::anyhow!("文件已存在"));
    }
    let url = result.part_info_list[0].upload_url.clone();
    put_file_with_password(file_path, password.as_slice(), url.as_str()).await?;
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
    let mut buffer = [0u8; 1 << 20];
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

async fn put_file_with_password(file_path: &str, password: &[u8], url: &str) -> anyhow::Result<()> {
    let (sender, body) = PutResource::channel_resource();
    let request = reqwest::Client::new().put(url).body(body).send();
    let cp = sender.clone();
    let read_file_back = async move {
        let result = put_steam_with_password(cp, file_path, password).await;
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
) -> anyhow::Result<()> {
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

use reqwest::Body;
use sha1::Digest;
use tokio::io::AsyncReadExt;
use tokio::sync::mpsc::Sender;

pub struct PutResource {
    pub agent: Arc<reqwest::Client>,
    pub url: String,
    pub resource: Body,
}

impl PutResource {
    pub async fn put(self) -> anyhow::Result<()> {
        let _text = self
            .agent
            .request(reqwest::Method::PUT, self.url.as_str())
            .body(self.resource)
            .send()
            .await?
            .error_for_status()?
            .text()
            .await?;
        Ok(())
    }
}

impl PutResource {
    pub async fn file_resource(path: &str) -> anyhow::Result<Body> {
        let file = tokio::fs::read(path).await?;
        Ok(Body::from(file))
    }

    pub fn channel_resource() -> (Sender<anyhow::Result<Vec<u8>>>, Body) {
        let (sender, receiver) = tokio::sync::mpsc::channel::<anyhow::Result<Vec<u8>>>(16);
        let body = Body::wrap_stream(tokio_stream::wrappers::ReceiverStream::new(receiver));
        (sender, body)
    }

    pub fn bytes_body(bytes: Vec<u8>) -> Body {
        Body::from(bytes)
    }
}
