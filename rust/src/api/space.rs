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


#[derive(Debug, Clone, Serialize, Deserialize, Eq, PartialEq, Default)]
pub struct AdriveUserGetDriveInfo {
    pub user_id: String,
    pub name: String,
    pub avatar: String,
    pub default_drive_id: String,
    pub resource_drive_id: Option<String>,
    pub backup_drive_id: Option<String>,
}

fn map<T: serde::Serialize, R: for<'a> serde::Deserialize<'a>>(
    t: T,
) -> anyhow::Result<R> {
    let string = serde_json::to_string(&t)?;
    let r: R = serde_json::from_str(&string)?;
    Ok(r)
}