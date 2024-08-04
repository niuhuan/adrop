use crate::custom_crypto::{decrypt_base64, decrypt_file_name, encrypt_buff_to_base64};
use crate::data_obj::{Config, Device, SpaceInfo};
use crate::database::properties::property::{load_property, save_property};
use crate::define::get_alipan_client;
use alipan::response::AdriveOpenFile;
use alipan::{AdriveOpenFilePartInfoCreate, AdriveOpenFileType, CheckNameMode};
use base64::Engine;
use reqwest::Body;
use sea_orm::ColIdx;
use serde_derive::{Deserialize, Serialize};

pub async fn space_info() -> anyhow::Result<Option<SpaceInfo>> {
    let space_config = load_property("space_config").await?;
    if space_config.is_empty() {
        return Ok(None);
    }
    if let Ok(space_config) = serde_json::from_str(&space_config) {
        Ok(Some(space_config))
    } else {
        clear().await?;
        Ok(None)
    }
}

async fn clear() -> anyhow::Result<()> {
    Ok(())
}

pub async fn oauth_derive_info() -> anyhow::Result<AdriveUserGetDriveInfo> {
    let data = get_alipan_client()
        .adrive_user_get_drive_info()
        .await
        .request()
        .await?;
    map(data)
}

pub async fn list_folder(
    drive_id: String,
    parent_folder_file_id: String,
) -> anyhow::Result<Vec<FileItem>> {
    let client = get_alipan_client();

    let mut folders = vec![];
    let mut rsp = client
        .adrive_open_file_list()
        .await
        .drive_id(&drive_id)
        .parent_file_id(&parent_folder_file_id)
        .r#type(AdriveOpenFileType::Folder)
        .request()
        .await?;
    put_items(&mut folders, rsp.items);
    while rsp.next_marker.is_some() && !rsp.next_marker.as_deref().unwrap().is_empty() {
        rsp = client
            .adrive_open_file_list()
            .await
            .drive_id(&drive_id)
            .parent_file_id(&parent_folder_file_id)
            .r#type(AdriveOpenFileType::Folder)
            .marker(rsp.next_marker.as_deref().unwrap())
            .request()
            .await?;
        put_items(&mut folders, rsp.items);
    }

    Ok(folders)
}

fn put_items(folders: &mut Vec<FileItem>, items: Vec<AdriveOpenFile>) {
    for item in items {
        folders.push(FileItem {
            file_id: item.file_id,
            file_name: item.name,
        });
    }
}

pub async fn create_folder(
    drive_id: String,
    parent_folder_file_id: String,
    folder_name: String,
) -> anyhow::Result<()> {
    let client = get_alipan_client();
    let result = client
        .adrive_open_file_create()
        .await
        .drive_id(drive_id.as_str())
        .parent_file_id(parent_folder_file_id.as_str())
        .name(folder_name.as_str())
        .r#type(AdriveOpenFileType::Folder)
        .check_name_mode(CheckNameMode::Refuse)
        .request()
        .await?;
    if result.exist {
        return Err(anyhow::anyhow!("Folder already exists"));
    }
    Ok(())
}

pub async fn has_set_password(
    drive_id: String,
    parent_folder_file_id: String,
) -> anyhow::Result<Option<String>> {
    let client = get_alipan_client();
    //
    let mut files = vec![];
    let mut rsp = client
        .adrive_open_file_list()
        .await
        .drive_id(&drive_id)
        .parent_file_id(&parent_folder_file_id)
        .r#type(AdriveOpenFileType::File)
        .request()
        .await?;
    put_items(&mut files, rsp.items);
    while rsp.next_marker.is_some() && !rsp.next_marker.as_deref().unwrap().is_empty() {
        rsp = client
            .adrive_open_file_list()
            .await
            .drive_id(&drive_id)
            .parent_file_id(&parent_folder_file_id)
            .r#type(AdriveOpenFileType::File)
            .marker(rsp.next_marker.as_deref().unwrap())
            .request()
            .await?;
        put_items(&mut files, rsp.items);
    }
    let last = files
        .iter()
        .filter(|item| item.file_name == "password.txt")
        .last();
    if let Some(last) = last {
        let url = client
            .adrive_open_file_get_download_url()
            .await
            .drive_id(drive_id.as_str())
            .file_id(last.file_id.as_str())
            .request()
            .await?;
        let lock = client.agent.lock().await;
        let agent = lock.clone();
        drop(lock);
        let password_enc = agent
            .get(url.url.as_str())
            .send()
            .await?
            .error_for_status()?
            .text()
            .await?;
        Ok(Some(password_enc))
    } else {
        Ok(None)
    }
}

pub async fn set_new_password(
    drive_id: String,
    parent_folder_file_id: String,
    password: String,
) -> anyhow::Result<String> {
    let key = random_string(64);
    let passbook = encrypt_buff_to_base64(key.as_slice(), password.as_bytes())?;
    let client = get_alipan_client();
    let parts = vec![AdriveOpenFilePartInfoCreate { part_number: 1 }];
    let file = client
        .adrive_open_file_create()
        .await
        .check_name_mode(CheckNameMode::Refuse)
        .drive_id(drive_id.clone())
        .parent_file_id(parent_folder_file_id.clone())
        .r#type(AdriveOpenFileType::File)
        .name("password.txt")
        .size(passbook.len() as i64)
        .part_info_list(parts)
        .request()
        .await?;
    reqwest::Client::new()
        .put(file.part_info_list[0].upload_url.as_str())
        .body(Body::from(passbook))
        .send()
        .await?
        .error_for_status()?
        .text()
        .await?;
    client
        .adrive_open_file_complete()
        .await
        .drive_id(file.drive_id.clone())
        .file_id(file.file_id.clone())
        .upload_id(file.upload_id.clone())
        .request()
        .await?;
    Ok(base64::prelude::BASE64_URL_SAFE.encode(key.as_slice()))
}

pub async fn check_old_password(password_enc: String, password: String) -> anyhow::Result<String> {
    let buff = decrypt_base64(password_enc.as_str(), password.as_bytes())?;
    Ok(base64::prelude::BASE64_URL_SAFE.encode(buff.as_slice()))
}

pub async fn list_devices_by_config() -> anyhow::Result<Vec<Device>> {
    let space_info = space_info().await?;
    if let Some(space_info) = space_info {
        list_devices(
            space_info.drive_id,
            space_info.devices_root_folder_file_id,
            space_info.true_pass_base64,
        )
        .await
    } else {
        Ok(vec![])
    }
}

pub async fn list_devices(
    drive_id: String,
    parent_folder_file_id: String,
    true_pass_base64: String,
) -> anyhow::Result<Vec<Device>> {
    let true_pass = base64::prelude::BASE64_URL_SAFE.decode(true_pass_base64.as_bytes())?;
    let mut files = vec![];
    let client = get_alipan_client();
    let mut rsp = client
        .adrive_open_file_list()
        .await
        .drive_id(drive_id.as_str())
        .parent_file_id(parent_folder_file_id.as_str())
        .r#type(AdriveOpenFileType::Folder)
        .request()
        .await?;
    for x in rsp.items.into_iter() {
        files.push(x);
    }
    while rsp.next_marker.is_some() && !rsp.next_marker.as_deref().unwrap().is_empty() {
        rsp = client
            .adrive_open_file_list()
            .await
            .drive_id(&drive_id)
            .parent_file_id(&parent_folder_file_id)
            .r#type(AdriveOpenFileType::Folder)
            .marker(rsp.next_marker.as_deref().unwrap())
            .request()
            .await?;
        for x in rsp.items.into_iter() {
            files.push(x);
        }
    }
    let device_pattern = regex::Regex::new(r"^(.+)\.(\d+)\.device$").unwrap();
    let mut devices = vec![];
    for file in files {
        if !device_pattern.is_match(file.name.as_str()) {
            println!("skip file by not match: {}", file.name);
            continue;
        }
        let cap = device_pattern.captures(file.name.as_str()).unwrap();
        let enc_device_name = cap.get(1).unwrap().as_str();
        let device_type = cap.get(2).unwrap().as_str().parse::<i32>().unwrap();
        if let Ok(device_name) = decrypt_file_name(enc_device_name, true_pass.as_slice()) {
            devices.push(Device {
                name: device_name,
                folder_file_id: file.file_id,
                device_type,
            });
        } else {
            println!("skip file by decrypt error: {}", enc_device_name);
        }
    }
    Ok(devices)
}

pub async fn create_new_device(
    drive_id: String,
    parent_folder_file_id: String,
    true_pass_base64: String,
    device_name: String,
    device_type: i32, // device_icon
) -> anyhow::Result<()> {
    let true_pass = base64::prelude::BASE64_URL_SAFE.decode(true_pass_base64.as_bytes())?;
    let enc_device_name = encrypt_buff_to_base64(device_name.as_bytes(), true_pass.as_slice())?;
    let client = get_alipan_client();
    let file = client
        .adrive_open_file_create()
        .await
        .check_name_mode(CheckNameMode::Refuse)
        .drive_id(drive_id.clone())
        .parent_file_id(parent_folder_file_id.clone())
        .r#type(AdriveOpenFileType::Folder)
        .name(format!("{}.{}.device", enc_device_name, device_type).as_str())
        .request()
        .await?;
    if file.exist {
        return Err(anyhow::anyhow!("Device already exists"));
    }
    let info = SpaceInfo {
        drive_id,
        devices_root_folder_file_id: parent_folder_file_id,
        this_device_folder_file_id: file.file_id,
        true_pass_base64,
    };
    save_property("space_config".to_owned(), serde_json::to_string(&info)?).await?;
    Ok(())
}

pub async fn choose_old_device(
    drive_id: String,
    parent_folder_file_id: String,
    true_pass_base64: String,
    this_device_folder_file_id: String,
) -> anyhow::Result<()> {
    let info = SpaceInfo {
        drive_id,
        devices_root_folder_file_id: parent_folder_file_id,
        this_device_folder_file_id,
        true_pass_base64,
    };
    save_property("space_config".to_owned(), serde_json::to_string(&info)?).await?;
    Ok(())
}

fn random_string(len: usize) -> Vec<u8> {
    use rand::distributions::Alphanumeric;
    use rand::{thread_rng, Rng};
    let buff = thread_rng()
        .sample_iter(&Alphanumeric)
        .take(len)
        .collect::<Vec<u8>>();
    buff
}

#[derive(Debug, Clone, Serialize, Deserialize, Eq, PartialEq, Default)]
pub struct AdriveUserGetDriveInfo {
    pub user_id: String,
    pub name: String,
    pub avatar: String,
    pub default_drive_id: String,
    pub resource_drive_id: Option<String>,
    pub backup_drive_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Eq, PartialEq, Default)]
pub struct FileItem {
    pub file_id: String,
    pub file_name: String,
}

fn map<T: serde::Serialize, R: for<'a> serde::Deserialize<'a>>(t: T) -> anyhow::Result<R> {
    let string = serde_json::to_string(&t)?;
    let r: R = serde_json::from_str(&string)?;
    Ok(r)
}
