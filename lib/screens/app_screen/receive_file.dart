import 'dart:ffi';
import 'dart:io';
import 'package:adrop/components/common.dart';
import 'package:adrop/cross.dart';
import 'package:adrop/src/rust/api/system.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../configs/configs.dart';
import '../../configs/screen_keep_on.dart';
import '../../src/rust/api/receiving.dart';
import '../../src/rust/data_obj.dart';
import '../../src/rust/data_obj/enums.dart';
import '../receiving_settings_screen.dart';
import 'common.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';

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
          await receivingTaskSetRemoved(
            taskId: task.taskId,
            reason: 1,
          );
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.taskState == ReceivingTaskState.success &&
                    (Platform.isIOS || Platform.isAndroid)) ...[
                  IconButton(
                    onPressed: () async {
                      if (task.fileRemoved > 0) {
                        if (task.fileRemoved == 1) {
                          defaultToast(context, "文件已存入相册，请打开相册查看");
                        } else {
                          defaultToast(context, "文件已删除");
                        }
                        return;
                      }
                      if (Platform.isAndroid) {
                        final mes = await Permission.manageExternalStorage
                            .request()
                            .isGranted;
                        if (!mes) {
                          defaultToast(context, "请授予存储权限");
                          return;
                        }
                      }
                      final result = await OpenFile.open(task.filePath);
                    },
                    icon: const Icon(Icons.play_arrow),
                  ),
                ],
                if (task.taskState == ReceivingTaskState.success &&
                    (Platform.isWindows ||
                        Platform.isWindows ||
                        Platform.isLinux)) ...[
                  IconButton(
                    onPressed: () async {
                      if (task.fileRemoved > 0) {
                        if (task.fileRemoved == 1) {
                          defaultToast(context, "文件已存入相册，请打开相册查看");
                        } else {
                          defaultToast(context, "文件已删除");
                        }
                        return;
                      }
                      showFileInExplorer(path: task.filePath);
                    },
                    icon: const Icon(Icons.folder),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (task.fileRemoved > 0) {
                        if (task.fileRemoved == 1) {
                          defaultToast(context, "文件已存入相册，请打开相册查看");
                        } else {
                          defaultToast(context, "文件已删除");
                        }
                        return;
                      }
                      openFile(path: task.filePath);
                    },
                    icon: const Icon(Icons.play_arrow),
                  ),
                ],
              ],
            ),
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
    return "下载成功";
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

String? getMimeType(String extension) {
  if (Platform.isAndroid) {
    Map<String, String> map = {};
    for (List<String> item in mimeAndroid) {
      map[item[0]] = item[1];
    }
    if (map.containsKey(extension)) {
      return map[extension];
    }
    return map[""];
  }
  if (Platform.isIOS) {
    Map<String, String> map = {};
    for (List<String> item in mimeIos) {
      map[item[0]] = item[1];
    }
    if (map.containsKey(extension)) {
      return map[extension];
    }
  }
  return null;
}

const mimeAndroid = [
  [".3gp", "video/3gpp"],
  [".torrent", "application/x-bittorrent"],
  [".kml", "application/vnd.google-earth.kml+xml"],
  [".gpx", "application/gpx+xml"],
  [".csv", "application/vnd.ms-excel"],
  [".apk", "application/vnd.android.package-archive"],
  [".asf", "video/x-ms-asf"],
  [".avi", "video/x-msvideo"],
  [".bin", "application/octet-stream"],
  [".bmp", "image/bmp"],
  [".c", "text/plain"],
  [".class", "application/octet-stream"],
  [".conf", "text/plain"],
  [".cpp", "text/plain"],
  [".doc", "application/msword"],
  [
    ".docx",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  ],
  [".xls", "application/vnd.ms-excel"],
  [
    ".xlsx",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  ],
  [".exe", "application/octet-stream"],
  [".gif", "image/gif"],
  [".gtar", "application/x-gtar"],
  [".gz", "application/x-gzip"],
  [".h", "text/plain"],
  [".htm", "text/html"],
  [".html", "text/html"],
  [".jar", "application/java-archive"],
  [".java", "text/plain"],
  [".jpeg", "image/jpeg"],
  [".jpg", "image/jpeg"],
  [".js", "application/x-javascript"],
  [".log", "text/plain"],
  [".m3u", "audio/x-mpegurl"],
  [".m4a", "audio/mp4a-latm"],
  [".m4b", "audio/mp4a-latm"],
  [".m4p", "audio/mp4a-latm"],
  [".m4u", "video/vnd.mpegurl"],
  [".m4v", "video/x-m4v"],
  [".mov", "video/quicktime"],
  [".mp2", "audio/x-mpeg"],
  [".mp3", "audio/x-mpeg"],
  [".mp4", "video/mp4"],
  [".mpc", "application/vnd.mpohun.certificate"],
  [".mpe", "video/mpeg"],
  [".mpeg", "video/mpeg"],
  [".mpg", "video/mpeg"],
  [".mpg4", "video/mp4"],
  [".mpga", "audio/mpeg"],
  [".msg", "application/vnd.ms-outlook"],
  [".ogg", "audio/ogg"],
  [".pdf", "application/pdf"],
  [".png", "image/png"],
  [".pps", "application/vnd.ms-powerpoint"],
  [".ppt", "application/vnd.ms-powerpoint"],
  [
    ".pptx",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
  ],
  [".prop", "text/plain"],
  [".rc", "text/plain"],
  [".rmvb", "audio/x-pn-realaudio"],
  [".rtf", "application/rtf"],
  [".sh", "text/plain"],
  [".tar", "application/x-tar"],
  [".tgz", "application/x-compressed"],
  [".txt", "text/plain"],
  [".wav", "audio/x-wav"],
  [".wma", "audio/x-ms-wma"],
  [".wmv", "audio/x-ms-wmv"],
  [".wps", "application/vnd.ms-works"],
  [".xml", "text/plain"],
  [".z", "application/x-compress"],
  [".zip", "application/x-zip-compressed"],
  ["", "*/*"]
];

const mimeIos = [
  [".rtf", "public.rtf"],
  [".txt", "public.plain-text"],
  [".html", "public.html"],
  [".htm", "public.html"],
  [".xml", "public.xml"],
  [".tar", "public.tar-archive"],
  [".gz", "org.gnu.gnu-zip-archive"],
  [".gzip", "org.gnu.gnu-zip-archive"],
  [".tgz", "org.gnu.gnu-zip-tar-archive"],
  [".jpg", "public.jpeg"],
  [".jpeg", "public.jpeg"],
  [".png", "public.png"],
  [".avi", "public.avi"],
  [".mpg", "public.mpeg"],
  [".mpeg", "public.mpeg"],
  [".mp4", "public.mpeg-4"],
  [".3gpp", "public.3gpp"],
  [".3gp", "public.3gpp"],
  [".mp3", "public.mp3"],
  [".zip", "com.pkware.zip-archive"],
  [".gif", "com.compuserve.gif"],
  [".bmp", "com.microsoft.bmp"],
  [".ico", "com.microsoft.ico"],
  [".doc", "com.microsoft.word.doc"],
  [".xls", "com.microsoft.excel.xls"],
  [".ppt", "com.microsoft.powerpoint.ppt"],
  [".wav", "com.microsoft.waveform-audio"],
  [".wm", "com.microsoft.windows-media-wm"],
  [".wmv", "com.microsoft.windows-media-wmv"],
  [".pdf", "com.adobe.pdf"]
];
