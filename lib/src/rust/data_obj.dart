// This file is automatically generated, so please do not edit it.
// Generated by `flutter_rust_bridge`@ 2.1.0.

// ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import

import 'data_obj/enums.dart';
import 'frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

class Device {
  final String name;
  final String folderFileId;
  final int deviceType;

  const Device({
    required this.name,
    required this.folderFileId,
    required this.deviceType,
  });

  @override
  int get hashCode =>
      name.hashCode ^ folderFileId.hashCode ^ deviceType.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          folderFileId == other.folderFileId &&
          deviceType == other.deviceType;
}

class LoginInfo {
  final LoginState state;

  const LoginInfo({
    required this.state,
  });

  @override
  int get hashCode => state.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginInfo &&
          runtimeType == other.runtimeType &&
          state == other.state;
}

class ReceivingTask {
  final String taskId;
  final String driveId;
  final String fileId;
  final String fileName;
  final String filePath;
  final ReceivingTaskState taskState;
  final String errorMsg;

  const ReceivingTask({
    required this.taskId,
    required this.driveId,
    required this.fileId,
    required this.fileName,
    required this.filePath,
    required this.taskState,
    required this.errorMsg,
  });

  @override
  int get hashCode =>
      taskId.hashCode ^
      driveId.hashCode ^
      fileId.hashCode ^
      fileName.hashCode ^
      filePath.hashCode ^
      taskState.hashCode ^
      errorMsg.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceivingTask &&
          runtimeType == other.runtimeType &&
          taskId == other.taskId &&
          driveId == other.driveId &&
          fileId == other.fileId &&
          fileName == other.fileName &&
          filePath == other.filePath &&
          taskState == other.taskState &&
          errorMsg == other.errorMsg;
}

class SendingTask {
  final String taskId;
  final Device device;
  final String fileName;
  final String filePath;
  final SendingTaskState taskState;
  final String errorMsg;

  const SendingTask({
    required this.taskId,
    required this.device,
    required this.fileName,
    required this.filePath,
    required this.taskState,
    required this.errorMsg,
  });

  @override
  int get hashCode =>
      taskId.hashCode ^
      device.hashCode ^
      fileName.hashCode ^
      filePath.hashCode ^
      taskState.hashCode ^
      errorMsg.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SendingTask &&
          runtimeType == other.runtimeType &&
          taskId == other.taskId &&
          device == other.device &&
          fileName == other.fileName &&
          filePath == other.filePath &&
          taskState == other.taskState &&
          errorMsg == other.errorMsg;
}

class SpaceInfo {
  final String driveId;
  final String devicesRootFolderFileId;
  final String thisDeviceFolderFileId;
  final String truePassBase64;

  const SpaceInfo({
    required this.driveId,
    required this.devicesRootFolderFileId,
    required this.thisDeviceFolderFileId,
    required this.truePassBase64,
  });

  @override
  int get hashCode =>
      driveId.hashCode ^
      devicesRootFolderFileId.hashCode ^
      thisDeviceFolderFileId.hashCode ^
      truePassBase64.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpaceInfo &&
          runtimeType == other.runtimeType &&
          driveId == other.driveId &&
          devicesRootFolderFileId == other.devicesRootFolderFileId &&
          thisDeviceFolderFileId == other.thisDeviceFolderFileId &&
          truePassBase64 == other.truePassBase64;
}
