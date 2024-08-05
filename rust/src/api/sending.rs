use lazy_static::lazy_static;
use tokio::sync::Mutex;

lazy_static! {
    static ref SENDING_TASKS: Mutex<Vec<crate::data_obj::SendingTask>> = Mutex::new(vec![]);
}

pub async fn list_sending_tasks() -> anyhow::Result<Vec<crate::data_obj::SendingTask>> {
    Ok(SENDING_TASKS.lock().await.clone())
}

pub async fn add_sending_tasks(tasks: Vec<crate::data_obj::SendingTask>) -> anyhow::Result<()> {
    let mut lock = SENDING_TASKS.lock().await;
    for task in tasks {
        lock.push(task);
    }
    Ok(())
}
