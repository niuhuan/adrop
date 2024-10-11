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
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: 8,
            ),
            child: Text.rich(TextSpan(children: [
              const WidgetSpan(
                child: Icon(
                  Icons.speed,
                  size: 24,
                ),
              ),
              const TextSpan(
                text: " 限流",
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              const TextSpan(
                text: "  ",
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              receiveLimitTimeWidthEditSpan(setState, context),
              const TextSpan(
                text: " 秒内, ",
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              const TextSpan(
                text: "最多接收 ",
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              receiveLimitTimeFileEditSpan(setState, context),
              const TextSpan(
                text: " 个文件",
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ])),
          ),
        ],
      ),
    );
  }
}
