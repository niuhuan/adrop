use flutter_rust_bridge::for_generated::anyhow;
use lazy_static::lazy_static;
use once_cell::sync::OnceCell;
use tokio::sync::Mutex;
use crate::utils::{create_dir_if_not_exists, join_paths};

lazy_static! {
    static ref INIT_ED: Mutex<bool> = Mutex::new(false);
}

static ROOT: OnceCell<String> = OnceCell::new();
static DATABASE_DIR: OnceCell<String> = OnceCell::new();

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
    Ok(())
}

#[allow(dead_code)]
pub(crate) fn get_root() -> &'static String {
    ROOT.get().unwrap()
}

pub(crate) fn get_database_dir() -> &'static String {
    DATABASE_DIR.get().unwrap()
}

