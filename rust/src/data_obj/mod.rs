pub mod enums;

use crate::data_obj::enums::{LoginState, SendingTaskState};
use alipan::AccessToken;
use serde_derive::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Config {
    pub app: AppConfig,
    pub access_token: AccessToken,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AppConfig {
    pub client_id: String,
    pub client_secret: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct LoginInfo {
    pub state: LoginState,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SpaceInfo {
    pub drive_id: String,
    pub devices_root_folder_file_id: String,
    pub this_device_folder_file_id: String,
    pub true_pass_base64: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Device {
    pub name: String,
    pub folder_file_id: String,
    pub device_type: i32,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SendingTask {
    pub task_id: String,
    pub device: Device,
    pub file_name: String,
    pub file_path: String,
    pub task_state: SendingTaskState,
    pub error_msg: String,
}
