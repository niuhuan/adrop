import 'dart:io';

import 'package:adrop/src/rust/api/download.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DownloadToSetting extends StatefulWidget {
  const DownloadToSetting({super.key});

  @override
  State<DownloadToSetting> createState() => _DownloadToSettingState();
}

class _DownloadToSettingState extends State<DownloadToSetting> {
  String _path = "";

  late final Future<DownloadConfig?> _future;

  @override
  void initState() {
    if (!Platform.isIOS) {
      _future = downloadInfo().then((value) {
        _path = value?.downloadTo ?? "";
        setState(() {});
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return Container();
    }
    return ListTile(
      title: const Text('下载路径'),
      subtitle: Text(_path),
      onTap: () async {
        var choose = await FilePicker.platform.getDirectoryPath(
          lockParentWindow: false,
          dialogTitle: "选择下载路径",
          initialDirectory: await defaultDownloadPath(),
        );
        if (choose != null) {
          await setDownloadConfigOnlyPath(path: choose);
          setState(() {});
        }
      },
    );
  }
}
