use alipan::AdriveOpenFileType;
use alipan::response::AdriveOpenFile;
use serde_derive::{Deserialize, Serialize};
use crate::data_obj::{Config, SpaceInfo};
use crate::database::properties::property::load_property;
use crate::define::get_alipan_client;

pub async fn space_info() -> anyhow::Result<Option<SpaceInfo>> {
    let space_config = load_property("space_config").await?;
    if space_config.is_empty() {
        return Ok(None);
    }
    let _space_config: Config = if let Ok(space_config) = serde_json::from_str(&space_config) {
        space_config
    } else {
        clear().await?;
        return Ok(None);
    };
    Ok(None)
}

async fn clear() -> anyhow::Result<()> {
    Ok(())
}

pub async fn oauth_derive_info() -> anyhow::Result<AdriveUserGetDriveInfo> {
    let data = get_alipan_client().adrive_user_get_drive_info()
        .await.request().await?;
    map(data)
}

pub async fn list_folder(device_id: String, parent_folder_file_id: String) -> anyhow::Result<Vec<FileItem>> {
    let client = get_alipan_client();

    let mut folders = vec![];
    let mut rsp = client.adrive_open_file_list()
        .await
        .drive_id(&device_id)
        .parent_file_id(&parent_folder_file_id)
        .r#type(AdriveOpenFileType::Folder)
        .request()
        .await?;
    put_folders(&mut folders, rsp.items);
    while rsp.next_marker.is_some() && !rsp.next_marker.as_deref().unwrap().is_empty() {
        rsp = client.adrive_open_file_list()
            .await
            .drive_id(&device_id)
            .parent_file_id(&parent_folder_file_id)
            .r#type(AdriveOpenFileType::Folder)
            .marker(rsp.next_marker.as_deref().unwrap())
            .request()
            .await?;
        put_folders(&mut folders, rsp.items);
    }

    Ok(folders)
}

fn put_folders(folders: &mut Vec<FileItem>, items: Vec<AdriveOpenFile>) {
    for item in items {
        folders.push(FileItem {
            file_id: item.file_id,
            file_name: item.name,
        });
    }
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

fn map<T: serde::Serialize, R: for<'a> serde::Deserialize<'a>>(
    t: T,
) -> anyhow::Result<R> {
    let string = serde_json::to_string(&t)?;
    let r: R = serde_json::from_str(&string)?;
    Ok(r)
}