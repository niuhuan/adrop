import 'dart:io';

import 'package:flutter/material.dart';

import '../components/launch_at_startup.dart';
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
          if (Platform.isIOS)
            saveToGallerySwitchListTile(),
          if (Platform.isIOS)
            deleteAfterSaveToGallerySwitchListTile(),
        ],
      ),
    );
  }
}
