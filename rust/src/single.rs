use std::convert::Infallible;
use std::process::exit;
use std::sync::Once;
use serde_json::json;
use crate::single_instance::SingleInstance;
use warp::Filter;
use crate::api::single_instance_stream::sync_display_to_dart;

const SINGLE_NAME: &'static str = "ADROP_SINGLE_INSTANCE";
static mut SINGLE_INSTANCE_VAL: Option<SingleInstance> = None;
static SINGLE_INSTANCE_VAL_LOCK: Once = Once::new();

pub(crate) async fn single() {
    match SingleInstance::new(SINGLE_NAME) {
        Ok(instance) => {
            if !instance.is_single() {
                println!("SINGLE_INSTANCE_: Another instance is running, please close it first.");
                let _ = send_display_signal().await;
                exit(0);
            } else {
                println!("SINGLE_INSTANCE_: This is the first instance.");
                unsafe {
                    SINGLE_INSTANCE_VAL_LOCK.call_once(|| {
                        SINGLE_INSTANCE_VAL = Some(instance);
                    })
                }
                let _ = spawn_single_signal().await;
            }
        }
        Err(err) => {
            println!("SINGLE_INSTANCE_: Error: {}", err);
        }
    }
}

const PORT: u16 = 23768;

async fn send_display_signal() -> anyhow::Result<()> {
    reqwest::get(format!("http://127.0.0.1:{}/display", PORT))
        .await?
        .error_for_status()?
        .text().await?;
    Ok(())
}

async fn spawn_single_signal() {
    tokio::spawn(async {
        let _ = warp::serve(warp::path("display").and_then(display)).run(([127, 0, 0, 1], PORT)).await;
    });
}

async fn display() -> Result<impl warp::Reply, Infallible> {
    let _ = sync_display_to_dart().await;
    Ok(warp::reply::json(&json!({
        "status": "OK",
    })))
}