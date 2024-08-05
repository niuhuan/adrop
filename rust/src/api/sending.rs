use crate::data_obj::SendingTask;
use crate::frb_generated::StreamSink;
use flutter_rust_bridge::for_generated::futures::SinkExt;
use lazy_static::lazy_static;
use tokio::sync::Mutex;

lazy_static! {
    static ref SENDING_TASKS: Mutex<Vec<SendingTask>> = Mutex::new(vec![]);
    static ref SENDING_CALL_BACKS: Mutex<Option<StreamSink<Vec<SendingTask>>>> = Mutex::new(None);
}

pub async fn register_sending_listener(
    listener: StreamSink<Vec<SendingTask>>,
) -> anyhow::Result<()> {
    let mut scb = SENDING_CALL_BACKS.lock().await;
    *scb = Some(listener);
    drop(scb);
    Ok(())
}

pub async fn unregister_sending_listener() -> anyhow::Result<()> {
    let mut scb = SENDING_CALL_BACKS.lock().await;
    *scb = None;
    drop(scb);
    Ok(())
}

pub async fn list_sending_tasks() -> anyhow::Result<Vec<crate::data_obj::SendingTask>> {
    Ok(SENDING_TASKS.lock().await.clone())
}

pub async fn add_sending_tasks(tasks: Vec<crate::data_obj::SendingTask>) -> anyhow::Result<()> {
    let mut lock = SENDING_TASKS.lock().await;
    for task in tasks {
        lock.push(task);
    }
    let tasks = lock.clone();
    drop(lock);
    log_log(sync_tasks_to_dart(tasks).await);
    Ok(())
}

async fn sync_tasks_to_dart(tasks: Vec<crate::data_obj::SendingTask>) -> anyhow::Result<()> {
    let scb = SENDING_CALL_BACKS.lock().await;
    if let Some(scb) = &*scb {
        scb.add(SENDING_TASKS.lock().await.clone())
            .map_err(|e| anyhow::anyhow!(e))?;
    }
    drop(scb);
    Ok(())
}

fn log_log<T>(r: anyhow::Result<T>) {
    if let Err(e) = r {
        println!("{:?}", e);
    }
}
