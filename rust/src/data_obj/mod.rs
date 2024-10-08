pub mod enums;

use crate::data_obj::enums::{
    FileItemType, LoginState, ReceivingTaskState, SendingTaskErrorType, SendingTaskState,
    SendingTaskType,
};
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
    pub this_device: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SendingTask {
    pub task_id: String,
    pub device: Device,
    pub file_name: String,
    pub file_path: String,
    pub file_item_type: FileItemType,
    pub task_state: SendingTaskState,
    pub error_type: SendingTaskErrorType,
    pub error_msg: String,
    pub cloud_file_id: String, // 如果是文件夹，在创建云端文件夹之后将会变成非空字符串
    pub current_file_upload_size: i64,
    pub sending_task_type: SendingTaskType,
    pub pack_selection_files: Vec<SelectionFile>,
    pub tmp_file_name: String,
    pub tmp_file_path: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ReceivingTask {
    pub task_id: String,
    pub drive_id: String,
    pub file_id: String,
    pub file_name: String,
    pub file_path: String,
    pub file_item_type: FileItemType,
    pub task_state: ReceivingTaskState,
    pub error_msg: String,
    pub file_removed: i64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SelectionFile {
    pub name: String,
    pub path: String,
    pub file_item_type: FileItemType,
}
