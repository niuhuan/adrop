use crate::define::init_root;
use flutter_rust_bridge::for_generated::anyhow;

pub async fn init_path(local_path: String) -> anyhow::Result<()> {
    init_root(local_path.as_str()).await
}

// #[tokio::test]
// async fn test_init_path() {
//     let local_path = "/Users/niuhuan/Library/Application Support/opensource/adrop".to_string();
//     let result = init_path(local_path).await;
//     assert!(result.is_ok());
//     tokio::time::sleep(tokio::time::Duration::from_secs(100)).await;
// }
