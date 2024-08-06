use crate::data_obj::SelectionFile;

pub fn selection_file(name: String, path: String) -> SelectionFile {
    SelectionFile {
        name,
        path,
    }
}