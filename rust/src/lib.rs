pub mod api;
mod frb_generated;
mod database;
mod utils;
pub mod define;
mod data_obj;
mod custom_crypto;
mod common;
#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
mod single_instance;
// windows linux macos , not android, not ios
#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
mod single;
