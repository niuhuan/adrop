import 'package:adrop/configs/screen_keep_on.dart';
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
    stream.listen(_tasksSet);
    super.initState();
  }

  @override
  void dispose() {
    if (widget.controller._state == this) {
      widget.controller._state = null;
    }
    super.dispose();
  }

  _tasksSet(List<SendingTask> tasks) async {
    setState(() {
      _tasks.clear();
      _tasks.addAll(tasks);
    });
    if (keepScreenUpOnSending.value && _tasks.isNotEmpty) {
      var keep = false;
      for (final task in _tasks) {
        if ("${task.taskState}".toLowerCase().contains(".sending")) {
          keep = true;
          break;
        }
      }
      setKeepScreenUpOnSending(keep);
    } else {
      setKeepScreenUpOnSending(false);
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
              "${task.fileName}${_moreFile(task)}",
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

  Future<bool> _sendFiles(Device device, List<SelectionFile> files) async {
    if (files.isEmpty) {
      defaultToast(context, "选择要发送的文件");
      return false;
    }
    if (files.length <= 1) {
      await addSendingTasks(
        device: device,
        selectionFiles: files,
        sendingTaskType: SendingTaskType.single,
        packName: "",
      );
      defaultToast(context, "已添加到发送队列");
      return true;
    }
    SendingTaskType? taskType;
    String? packName;
    if (zipOnSend.value) {
      taskType = SendingTaskType.packZip;
      if (zipOnSendRename.value) {
        packName = await showInputDialog(
          context: context,
          title: "输入压缩包名称",
          hint: "压缩包名称",
          init: "压缩包",
        );
        if (packName == null) {
          return false;
        }
        packName = packName.trim();
        if (packName.isEmpty) {
          return false;
        }
      }
    }
    // zipOnSendRename
    await addSendingTasks(
      device: device,
      selectionFiles: files,
      sendingTaskType:
          zipOnSend.value ? SendingTaskType.packZip : SendingTaskType.single,
      packName: packName ?? "",
    );
    defaultToast(context, "已添加到发送队列");
    return true;
  }

  String _moreFile(SendingTask task) {
    if (task.packSelectionFiles.isNotEmpty) {
      return "${task.tmpFileName} (${task.packSelectionFiles.length}个文件(夹))";
    }
    return "";
  }
}

class SendingController {
  _SendingState? _state;

  Future<bool> send(Device device, List<SelectionFile> files) async {
    return await _state?._sendFiles(device, files) ?? false;
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

Future<String?> showInputDialog({
  required BuildContext context,
  required String title,
  required String hint,
  required String init,
}) async {
  final controller = TextEditingController(text: init);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: init.length,
  );
  final focusNode = FocusNode();
  focusNode.requestFocus();
  final result = await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
          ),
          focusNode: focusNode,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(controller.text);
            },
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  focusNode.dispose();
  controller.dispose();
  return result;
}
