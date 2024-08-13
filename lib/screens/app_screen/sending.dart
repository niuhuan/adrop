
import 'package:flutter/material.dart';

import '../../components/common.dart';
import '../../configs/configs.dart';
import '../../src/rust/api/sending.dart';
import '../../src/rust/data_obj.dart';
import '../../src/rust/data_obj/enums.dart';
import 'common.dart';

class Sending extends StatefulWidget {
  final SendingController controller;

  const Sending({required this.controller, super.key});

  @override
  State<Sending> createState() => _SendingState();
}

class _SendingState extends State<Sending> {
  final _tasks = <SendingTask>[];
  final stream = registerSendingListener();

  @override
  void initState() {
    widget.controller._state = this;
    stream.listen((tasks) {
      setState(() {
        _tasks.clear();
        _tasks.addAll(tasks);
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    if (widget.controller._state == this) {
      widget.controller._state = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('aDrop'),
        elevation: 1,
        actions: [
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
                  clearSendingTasks(clearTypes: [
                    SendingTaskClearType.clearSuccess,
                  ]);
                },
                child: const Text("清理发送成功的任务"),
              ),
              MenuItemButton(
                onPressed: () {
                  clearSendingTasks(clearTypes: [
                    SendingTaskClearType.retryFailed,
                  ]);
                },
                child: const Text("重试发送失败的任务"),
              ),
              MenuItemButton(
                onPressed: () {
                  clearSendingTasks(clearTypes: [
                    SendingTaskClearType.cancelFailed,
                  ]);
                },
                child: const Text("取消发送失败的任务"),
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
        final task = _tasks[index];
        final state = "${task.taskState}";
        final label = _sendingLabelOfState(state);
        final color = colorOfState(state);
        final size = sizeFormat(task.currentFileUploadSize);
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
                color: color,
                width: 2,
              ),
            ),
          ),
          child: ListTile(
            title: Text(
              "${task.fileName}${_mutilFile(task)}",
            ),
            subtitle: Text.rich(TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    color: color,
                  ),
                ),
                const TextSpan(
                  text: "  ",
                ),
                WidgetSpan(
                  child: Icon(
                    deviceIcon(
                      task.device.deviceType,
                    ),
                    size: 16,
                  ),
                  alignment: PlaceholderAlignment.middle,
                ),
                const TextSpan(
                  text: " ",
                ),
                TextSpan(
                  text: task.device.name,
                ),
                const TextSpan(
                  text: "  ",
                ),
                TextSpan(
                  text: size,
                ),
              ],
            )),
            leading: iconOfSendTask(task),
          ),
        );
      },
    );
  }

  _sendFiles(Device device, List<SelectionFile> files) async {
    await addSendingTasks(
      device: device,
      selectionFiles: files,
      sendingTaskType:
      zipOnSend.value ? SendingTaskType.packZip : SendingTaskType.single,
    );
    defaultToast(context, "已添加到发送队列");
  }

  String _mutilFile(SendingTask task) {
    if (task.packSelectionFiles.isNotEmpty) {
      return " (${task.packSelectionFiles.length}个文件(夹))";
    }
    return "";
  }
}

class SendingController {
  _SendingState? _state;

  void send(Device device, List<SelectionFile> files) {
    _state?._sendFiles(device, files);
  }
}

String _sendingLabelOfState(String state) {
  if (state.endsWith(".init")) {
    return "队列中";
  }
  if (state.endsWith(".sending")) {
    return "上传中";
  }
  if (state.endsWith(".success")) {
    return "上传成功";
  }
  if (state.endsWith(".error") ||
      state.endsWith(".fail") ||
      state.endsWith(".failed")) {
    return "上传失败";
  }
  if (state.endsWith(".canceled")) {
    return "已取消";
  }
  if (state.endsWith(".canceling")) {
    return "取消中";
  }
  return "未知";
}
