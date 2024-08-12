
import 'package:flutter/material.dart';

import '../../src/rust/data_obj.dart';
import '../../src/rust/data_obj/enums.dart';

Color colorOfState(String state) {
  if (state.endsWith(".success")) {
    return Colors.green;
  }
  if (state.endsWith(".error") ||
      state.endsWith(".fail") ||
      state.endsWith(".failed") ||
      state.endsWith(".canceled")) {
    return Colors.red;
  }
  if (state.endsWith(".canceling")) {
    return Colors.yellow;
  }
  return Colors.blue;
}

Widget iconOfSendTask(SendingTask task) {
  if (task.sendingTaskType == SendingTaskType.packZip) {
    return const Icon(Icons.folder_zip);
  }
  return iconOfFileType(task.fileItemType);
}

Icon iconOfFileType(FileItemType type) {
  switch (type) {
    case FileItemType.file:
      return const Icon(Icons.insert_drive_file);
    case FileItemType.folder:
      return const Icon(Icons.folder);
    default:
      return const Icon(Icons.help);
  }
}
