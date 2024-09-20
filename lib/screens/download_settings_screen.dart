import 'dart:io';

import 'package:adrop/components/common.dart';
import 'package:adrop/cross.dart';
import 'package:adrop/src/rust/api/download.dart';
import 'package:adrop/src/rust/data_obj/enums.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_screen/app_screen.dart';

class DownloadSettingsScreen extends StatefulWidget {
  const DownloadSettingsScreen({super.key});

  @override
  State<DownloadSettingsScreen> createState() =>
      _createDownloadSettingsScreenState();
}

State<DownloadSettingsScreen> _createDownloadSettingsScreenState() {
  if (Platform.isIOS) {
    return _IosDownloadSettingsScreenState();
  }
  return _DownloadSettingsScreenState();
}

class _IosDownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  _init() async {
    final dd = await cross.iosDocumentDirectory();
    await saveDownloadInfo(
      downloadConfig: DownloadConfig(
        downloadTo: dd,
        afterDownload: AfterDownload.moveToTrash,
        taskExpireEsc: 60 * 60 * 24 * 30,
      ),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const AppScreen(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载设置'),
        elevation: 1,
      ),
      body: ListView(
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("下载路径"),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _controller,
                    readOnly: true,
                  ),
                ),
              ),
              MaterialButton(
                onPressed: () async {
                  var choose = await FilePicker.platform.getDirectoryPath(
                    lockParentWindow: false,
                    dialogTitle: "选择下载路径",
                    initialDirectory: await defaultDownloadPath(),
                  );
                  if (choose != null) {
                    _controller.text = choose;
                  }
                },
                child: const Text("选择路径"),
              )
            ],
          ),
          MaterialButton(
            onPressed: () async {
              try {
                await saveDownloadInfo(
                  downloadConfig: DownloadConfig(
                    downloadTo: _controller.text,
                    afterDownload: AfterDownload.moveToTrash,
                    taskExpireEsc: 60 * 60 * 24 * 30,
                  ),
                );
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const AppScreen(),
                  ),
                );
              } catch (e) {
                defaultToast(context, e.toString());
              }
            },
            child: const Text("确认"),
          ),
        ],
      ),
    );
  }
}
