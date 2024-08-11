
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

#[tokio::test]
async fn test_match_selection_file() {
    use alipan::ErrorInfo;
    use ::rust_lib_adrop::api::init::init_path;
    use ::rust_lib_adrop::define::get_alipan_client;
    let home = std::env::var("HOME").unwrap();
    let local_path = home + "/Library/Application Support/opensource/adrop";
    init_path(local_path).await.unwrap();
    let client = get_alipan_client();
    let delete_rsp = client.adrive_open_file_delete()
        .await
        .drive_id("abc")
        .file_id("123")
        .request()
        .await;
    if let Err(err) = delete_rsp {
        match err.inner {
            ErrorInfo::ServerError(err) => {
                if "404".eq(err.code.as_str()) {
                    // file not found
                };
            }
            _ => {}
        }
    }
    assert!(delete_rsp.is_ok());
}
