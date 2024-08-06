fn main() {
    println!("Hello, world!");
}


#[tokio::test]
async fn test_init_path() {
    use ::rust_lib_adrop::api::init::init_path;
    let home = std::env::var("HOME").unwrap();
    let local_path = home + "/Library/Application Support/opensource/adrop";
    let result = init_path(local_path).await;
    assert!(result.is_ok());
    tokio::time::sleep(tokio::time::Duration::from_secs(100)).await;
}

