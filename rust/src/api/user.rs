use flutter_rust_bridge::for_generated::anyhow;
use crate::data_obj::enums::LoginState;
use crate::data_obj::{Config, LoginInfo};
use crate::database::properties::property::{load_property, save_property};

pub async fn login_info() -> anyhow::Result<LoginInfo> {
    let account_config = load_property("account_config").await?;
    if account_config.is_empty() {
        return Ok(unset());
    }
    let _account_config: Config = if let Ok(account_config) = serde_json::from_str(&account_config) {
        account_config
    } else {
        clear().await?;
        return Ok(unset());
    };
    Ok(set())
}

fn unset() -> LoginInfo {
    LoginInfo{
        state: LoginState::Unset,
    }
}

fn set() -> LoginInfo {
    LoginInfo{
        state: LoginState::Set,
    }
}

async fn clear() -> anyhow::Result<()> {
    save_property("account_config".to_owned(), "".to_owned()).await?;
    Ok(())
}


