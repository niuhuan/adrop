use crate::data_obj::enums::AfterDownload;
use crate::data_obj::SpaceInfo;
use crate::database::properties::property::{load_property, save_property};
use serde_derive::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct DownloadConfig {
    pub download_to: String,
    pub after_download: AfterDownload,
    pub task_expire_esc: i64,
}

pub async fn download_info() -> anyhow::Result<Option<DownloadConfig>> {
    let download_config = load_property("download_config").await?;
    if download_config.is_empty() {
        return Ok(None);
    }
    if let Ok(download_config) = serde_json::from_str(&download_config) {
        Ok(Some(download_config))
    } else {
        clear().await?;
        Ok(None)
    }
}

pub async fn save_download_info(download_config: DownloadConfig) -> anyhow::Result<()> {
    save_property(
        "download_config".to_owned(),
        serde_json::to_string(&download_config)?,
    )
    .await?;
    Ok(())
}

async fn clear() -> anyhow::Result<()> {
    save_property("download_config".to_owned(), "".to_owned()).await?;
    Ok(())
}

pub async fn default_download_path() -> anyhow::Result<String> {
    if let Some(dr) = dirs::download_dir() {
        return Ok(dr.to_str().unwrap().to_owned());
    }
    Ok("/".to_owned())
}
