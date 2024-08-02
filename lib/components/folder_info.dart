import '../src/rust/api/space.dart';

String lastFolderFileId(List<FileItem> items) {
  if (items.isEmpty) {
    return "root";
  }
  return items.last.fileId;
}
