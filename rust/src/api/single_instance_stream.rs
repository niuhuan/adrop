use std::ops::Deref;
use lazy_static::lazy_static;
use crate::frb_generated::StreamSink;
use tokio::sync::Mutex;

lazy_static! {
    static ref SI_CALL_BACKS: Mutex<Option<StreamSink<()>>> = Mutex::new(None);
}

pub async fn register_si_listener(
    listener: StreamSink<()>,
) -> anyhow::Result<()> {
    let mut scb = SI_CALL_BACKS.lock().await;
    *scb = Some(listener);
    drop(scb);
    Ok(())
}

pub async fn unregister_si_listener() -> anyhow::Result<()> {
    let mut scb = SI_CALL_BACKS.lock().await;
    *scb = None;
    drop(scb);
    Ok(())
}

pub(crate) async fn sync_display_to_dart() -> anyhow::Result<()> {
    let scb = SI_CALL_BACKS.lock().await;
    if let Some(scb) = scb.deref() {
        scb.add(()).map_err(|e| anyhow::anyhow!(e))?;
    }
    drop(scb);
    Ok(())
}