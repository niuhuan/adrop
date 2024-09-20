use std::process::exit;
use std::sync::Once;
use crate::single_instance::SingleInstance;

const SINGLE_NAME: &'static str = "ADROP_SINGLE_INSTANCE";
static mut SINGLE_INSTANCE_VAL: Option<SingleInstance> = None;
static SINGLE_INSTANCE_VAL_LOCK: Once = Once::new();

pub(crate) async fn single() {
    match SingleInstance::new(SINGLE_NAME) {
        Ok(instance) => {
            if !instance.is_single() {
                println!("SINGLE_INSTANCE_: Another instance is running, please close it first.");
                exit(0);
            } else {
                println!("SINGLE_INSTANCE_: This is the first instance.");
                unsafe {
                    SINGLE_INSTANCE_VAL_LOCK.call_once(|| {
                        SINGLE_INSTANCE_VAL = Some(instance);
                    })
                }
            }
        }
        Err(err) => {
            println!("SINGLE_INSTANCE_: Error: {}", err);
        }
    }
}