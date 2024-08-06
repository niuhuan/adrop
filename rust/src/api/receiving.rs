use alipan::response::AdriveOpenFile;
use lazy_static::lazy_static;
use tokio::sync::Mutex;
use crate::data_obj::ReceivingTask;
use crate::define::{get_alipan_client, ram_space_info};
use crate::frb_generated::StreamSink;

lazy_static! {
    static ref RECEIVING_TASKS: Mutex::<Vec<ReceivingTask>> = Mutex::new(Vec::new());
    static ref RECEIVING_CALL_BACKS: Mutex<Option<StreamSink<Vec<ReceivingTask>>>> = Mutex::new(None);
}

pub async fn register_receiving_task(listener: StreamSink<Vec<ReceivingTask>>) -> anyhow::Result<()> {
    let rcb = RECEIVING_CALL_BACKS.lock().await;
    *rcb = Some(listener);
    drop(rcb);
    Ok(())
}

pub async fn unregister_receiving_task() -> anyhow::Result<()> {
    let rcb = RECEIVING_CALL_BACKS.lock().await;
    *rcb = None;
    drop(rcb);
    Ok(())
}

pub async fn list_receiving_tasks() -> anyhow::Result<Vec<ReceivingTask>> {
    Ok(RECEIVING_TASKS.lock().await.clone())
}

async fn sync_tasks_to_dart() -> anyhow::Result<()> {
    let rcb = RECEIVING_CALL_BACKS.lock().await;
    if let Some(ref cb) = *rcb {
        cb.add(RECEIVING_TASKS.lock().await.clone()).await?;
    }
    Ok(())
}

pub(crate) async fn receiving_job() {
    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(15)).await;
        let space_info = if let Ok(space_info) = ram_space_info().await {
            if space_info.drive_id.is_empty() {
                continue;
            }
            space_info
        } else {
            println!("space info is failed");
            break;
        };
        let cloud_files = if let Ok(list_files) = list_files(
            space_info.drive_id.as_str(),
            space_info.this_device_folder_file_id.as_str(),
        ).await {
            list_files
        } else {
            continue;
        };
    }
}


async fn list_files(drive_id: &str, folder_id: &str) -> anyhow::Result<Vec<AdriveOpenFile>> {
    let client = get_alipan_client();
    let mut open_file_list: Vec<AdriveOpenFile> = vec![];
    let mut list = client
        .adrive_open_file_list()
        .await
        .drive_id(drive_id.clone())
        .parent_file_id(folder_id.clone())
        .request()
        .await?;
    for x in list.items {
        open_file_list.push(x);
    }
    while list.next_marker.is_some() {
        list = client
            .adrive_open_file_list()
            .await
            .drive_id(drive_id.clone())
            .parent_file_id(folder_id.clone())
            .marker(list.next_marker.unwrap())
            .request()
            .await?;
        for x in list.items {
            open_file_list.push(x);
        }
    }
    Ok(open_file_list)
}

