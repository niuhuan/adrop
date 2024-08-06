use crate::data_obj::enums::FileItemType;
use crate::data_obj::SelectionFile;

pub async fn match_selection_file(name: String, path: String) -> anyhow::Result<SelectionFile> {
    Ok(SelectionFile {
        file_item_type: {
            let metadata = tokio::fs::metadata(path.as_str()).await?;
            if metadata.is_dir() {
                FileItemType::Folder
            } else if metadata.is_file() {
                FileItemType::File
            } else {
                return Err(anyhow::anyhow!("Unknown file type"));
            }
        },
        name,
        path,
    })
}