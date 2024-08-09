// This file is automatically generated, so please do not edit it.
// Generated by `flutter_rust_bridge`@ 2.1.0.

// ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import

import '../frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

enum AfterDownload {
  moveToTrash,
  delete,
  ;
}

enum FileItemType {
  file,
  folder,
  ;
}

enum LoginState {
  unset,
  set_,
  ;
}

enum ReceivingTaskClearType {
  unset,
  clearSuccess,
  cancelFailedAndDeleteCloud,
  retryFailed,
  ;
}

enum ReceivingTaskState {
  init,
  receiving,
  success,
  failed,
  canceling,
  canceled,
  ;
}

enum SendingTaskClearType {
  unset,
  clearSuccess,
  cancelFailed,
  retryFailed,
  ;
}

enum SendingTaskErrorType {
  unset,
  unknown,
  ;
}

enum SendingTaskState {
  init,
  sending,
  success,
  failed,
  canceling,
  canceled,
  ;
}
