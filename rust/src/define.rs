use std::sync::Arc;
use alipan::{AccessToken, OAuthClient, OAuthClientAccessTokenManager, OAuthClientAccessTokenStore};
use async_trait::async_trait;
use flutter_rust_bridge::for_generated::anyhow;
use flutter_rust_bridge::for_generated::anyhow::anyhow;
use lazy_static::lazy_static;
use once_cell::sync::OnceCell;
use tokio::sync::Mutex;
use crate::data_obj::Config;
use crate::database::properties::property::{load_property, save_property};
use crate::utils::{create_dir_if_not_exists, join_paths};

lazy_static! {
    static ref INIT_ED: Mutex<bool> = Mutex::new(false);
}

static ROOT: OnceCell<String> = OnceCell::new();
static DATABASE_DIR: OnceCell<String> = OnceCell::new();
static ALIPAN_CLIENT: OnceCell<alipan::AdriveClient> = OnceCell::new();

pub(crate) async fn init_root(path: &str) -> anyhow::Result<()> {
    let mut lock = INIT_ED.lock().await;
    if *lock {
        return Ok(());
    }
    *lock = true;
    drop(lock);
    println!("Init application with root : {}", path);
    ROOT.set(path.to_owned()).unwrap();
    DATABASE_DIR
        .set(join_paths(vec![path, "database"]))
        .unwrap();
    create_dir_if_not_exists(ROOT.get().unwrap());
    create_dir_if_not_exists(DATABASE_DIR.get().unwrap());
    crate::database::init_database().await?;
    set_alipan_client().await?;
    Ok(())
}

async fn set_alipan_client() -> anyhow::Result<()> {
    let client = alipan::AdriveClient::default();
    ALIPAN_CLIENT.set(client).unwrap();
    let _ = do_set_client_after().await;
    Ok(())
}

async fn do_set_client_after() -> anyhow::Result<()> {
    let client = get_alipan_client();
    let account_config = load_property("account_config").await?;
    if account_config.is_empty() {
        return Ok(());
    }
    let account_config: Config = serde_json::from_str(&account_config)?;
    let mut client_id = client.client_id.lock().await;
    *client_id = Arc::new(account_config.app.client_id.clone());
    drop(client_id);
    //
    let app_config = account_config.app;
    let mut access_token_loader = client.access_token_loader.lock().await;
    *access_token_loader = Arc::new(Box::new(OAuthClientAccessTokenManager {
        oauth_client: Arc::new(
            OAuthClient::default()
                .set_client_id(app_config.client_id.clone())
                .await
                .set_client_secret(app_config.client_secret.clone())
                .await,
        ),
        access_token_store: Arc::new(Box::new(DatabaseAccessTokenStore {})),
    }));
    drop(access_token_loader);
    Ok(())
}

#[derive(Debug)]
pub struct DatabaseAccessTokenStore;


#[async_trait]
impl OAuthClientAccessTokenStore for DatabaseAccessTokenStore {
    async fn get_access_token(&self) -> anyhow::Result<Option<AccessToken>> {
        let account_config = load_property("account_config").await?;
        if account_config.is_empty() {
            return Ok(None);
        }
        let account_config: Config = serde_json::from_str(&account_config)?;
        Ok(Some(account_config.access_token))
    }

    async fn set_access_token(&self, access_token: AccessToken) -> anyhow::Result<()> {
        let account_config = load_property("account_config").await?;
        if account_config.is_empty() {
            return Err(anyhow!("account_config is empty"));
        }
        let mut account_config: Config = serde_json::from_str(&account_config)?;
        account_config.access_token = access_token;
        let account_config = serde_json::to_string(&account_config)?;
        save_property("account_config".to_owned(), account_config).await?;
        Ok(())
    }
}

#[allow(dead_code)]
pub(crate) fn get_root() -> &'static String {
    ROOT.get().unwrap()
}

pub(crate) fn get_database_dir() -> &'static String {
    DATABASE_DIR.get().unwrap()
}

pub(crate) fn get_alipan_client() -> &'static alipan::AdriveClient {
    ALIPAN_CLIENT.get().unwrap()
}
