import 'dart:io';

import 'package:flutter/material.dart';

import '../configs/download_to.dart';
import '../configs/launch_at_startup.dart';
import '../configs/configs.dart';

class ReceivingSettingsScreen extends StatefulWidget {
  const ReceivingSettingsScreen({super.key});

  @override
  State<StatefulWidget> createState() => _ReceivingSettingsScreenState();
}

class _ReceivingSettingsScreenState extends State<ReceivingSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('接收文件设置'),
      ),
      body: ListView(
        children: <Widget>[
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            launchAtStartupSwitchListTile(),
          if (Platform.isIOS || Platform.isAndroid)
            saveToGallerySwitchListTile(),
          if (Platform.isIOS || Platform.isAndroid)
            deleteAfterSaveToGallerySwitchListTile(),
          if (Platform.isIOS || Platform.isAndroid)
            keepScreenUpOnReceivingSwitchListTile(),
          const DownloadToSetting(),
          Text.rich(TextSpan(children: [
            TextSpan(
              text: "限流",
            ),
            TextSpan(
              text: ":",
            ),
            receiveLimitTimeWidthEditSpan(setState,context),
            TextSpan(
              text: "秒内",
            ),
            TextSpan(
              text: "最多接收",
            ),
            receiveLimitTimeFileEditSpan(setState,context),
            TextSpan(
              text: "个文件"
                  ""
                  "",
            ),
          ])),
        ],
      ),
    );
  }
}
