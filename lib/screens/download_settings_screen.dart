import 'dart:io';

import 'package:adrop/components/common.dart';
import 'package:adrop/src/rust/api/download.dart';
import 'package:adrop/src/rust/data_obj/enums.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';

import 'app_screen.dart';

class DownloadSettingsScreen extends StatefulWidget {
  const DownloadSettingsScreen({super.key});

  @override
  State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState();
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
                  var choose = await FilesystemPicker.openDialog(
                    context: context,
                    fsType: FilesystemType.folder,
                    fileTileSelectMode: FileTileSelectMode.wholeTile,
                    rootDirectory: Directory("/"),
                    directory: Directory(await defaultDownloadPath()),
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
              } catch (e, s) {
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
