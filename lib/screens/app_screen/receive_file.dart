import 'dart:ffi';
import 'dart:io';

import 'package:adrop/cross.dart';
import 'package:flutter/material.dart';

import '../../configs/configs.dart';
import '../../configs/screen_keep_on.dart';
import '../../src/rust/api/receiving.dart';
import '../../src/rust/data_obj.dart';
import '../../src/rust/data_obj/enums.dart';
import '../receiving_settings_screen.dart';
import 'common.dart';

class ReceiveFile extends StatefulWidget {
  const ReceiveFile({super.key});

  @override
  State<ReceiveFile> createState() => _ReceiveFileState();
}

class _ReceiveFileState extends State<ReceiveFile> {
  final _tasks = <ReceivingTask>[];
  final _receivingStream = registerReceivingTask();
  final _receivedStream = registerReceived();

  @override
  void initState() {
    _receivingStream.listen(_tasksSet);
    _receivedStream.listen(_onReceived);
    super.initState();
  }

  @override
  void dispose() {
    unregisterReceivingTask();
    unregisterReceived();
    super.dispose();
  }

  _tasksSet(List<ReceivingTask> tasks) async {
    setState(() {
      _tasks.clear();
      _tasks.addAll(tasks);
    });
    if (keepScreenUpOnReceiving.value) {
      var keep = _tasks
          .map((i) => "${i.taskState}".toLowerCase().contains("receiving"))
          .reduce((a, b) => a || b);
      setKeepScreenUpOnReceiving(keep);
    }
  }

  _onReceived(ReceivingTask task) async {
    if (task.fileItemType == FileItemType.file) {
      final lower = task.filePath.toLowerCase();
      if (lower.endsWith(".jpg") ||
          lower.endsWith(".png") ||
          lower.endsWith(".jpeg") ||
          lower.endsWith(".bpm")) {
        await cross.saveImageToGallery(task.filePath);
        if (deleteAfterSaveToGallery.value) {
          await File(task.filePath).delete();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('aDrop'),
        centerTitle: false,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) {
                  return const ReceivingSettingsScreen();
                }),
              );
            },
            icon: const Icon(Icons.settings),
          ),
          MenuAnchor(
            builder: (
              BuildContext context,
              MenuController controller,
              Widget? child,
            ) {
              return IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
            menuChildren: [
              MenuItemButton(
                onPressed: () {
                  clearReceivingTasks(clearTypes: [
                    ReceivingTaskClearType.clearSuccess,
                  ]);
                },
                child: const Text("清理接收成功的任务"),
              ),
              MenuItemButton(
                onPressed: () {
                  clearReceivingTasks(clearTypes: [
                    ReceivingTaskClearType.retryFailed,
                  ]);
                },
                child: const Text("重试接收失败的任务"),
              ),
              MenuItemButton(
                onPressed: () {
                  clearReceivingTasks(clearTypes: [
                    ReceivingTaskClearType.cancelFailedAndDeleteCloud,
                  ]);
                },
                child: const Text("取消接收失败的文件"),
              ),
            ],
          ),
        ],
      ),
      body: _tasksList(),
    );
  }

  Widget _tasksList() {
    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (BuildContext context, int index) {
        var task = _tasks[index];
        return Container(
          margin: const EdgeInsets.only(
            left: 3,
            right: 5,
            top: 1,
            bottom: 1,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: colorOfState("${task.taskState}"),
                width: 2,
              ),
            ),
          ),
          child: ListTile(
            title: Text(task.fileName),
            subtitle: Text(_receivingLabelOfState(task.taskState.toString())),
            leading: iconOfFileType(task.fileItemType),
          ),
        );
      },
    );
  }
}

String _receivingLabelOfState(String state) {
  if (state.endsWith(".init")) {
    return "队列中";
  }
  if (state.endsWith(".receiving")) {
    return "下载中";
  }
  if (state.endsWith(".success")) {
    return "下载传成功";
  }
  if (state.endsWith(".error") ||
      state.endsWith(".fail") ||
      state.endsWith(".failed")) {
    return "下载失败";
  }
  if (state.endsWith(".canceled")) {
    return "已取消";
  }
  if (state.endsWith(".canceling")) {
    return "取消中";
  }
  return "未知";
}
