pub mod api;
mod frb_generated;
mod database;
mod utils;
pub mod define;
mod data_obj;
mod custom_crypto;
mod common;
mod single_instance;
#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
mod single;
