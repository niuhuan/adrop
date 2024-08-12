
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import '../../components/device_type.dart';
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

String sizeFormat(PlatformInt64 sizeBigInt) {
  const b = 1;
  const kib = b << 10;
  const mib = kib << 10;
  const gib = mib << 10;
  final size = sizeBigInt.toInt();
  if (size < kib) {
    return "$size B";
  }
  if (size < mib) {
    return "${(size / kib).toStringAsFixed(2)} KiB";
  }
  if (size < gib) {
    return "${(size / mib).toStringAsFixed(2)} MiB";
  }
  return "${(size / gib).toStringAsFixed(2)} GiB";
}


IconData deviceIcon(int type) {
  switch (type) {
    case DeviceType.unknown:
      return Icons.help;
    case DeviceType.macbook:
      return Icons.laptop_mac;
    case DeviceType.windows:
      return Icons.laptop_windows;
    case DeviceType.linux:
      return Icons.laptop_windows;
    case DeviceType.iphone:
      return Icons.phone_iphone;
    case DeviceType.ipad:
      return Icons.tablet_mac;
    case DeviceType.android:
      return Icons.phone_android;
    default:
      return Icons.help;
  }
}
