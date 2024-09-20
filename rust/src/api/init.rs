use crate::define::init_root;
use flutter_rust_bridge::for_generated::anyhow;

pub async fn init_path(local_path: String) -> anyhow::Result<()> {
    #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
    crate::single::single().await;
    init_root(local_path.as_str()).await
}
