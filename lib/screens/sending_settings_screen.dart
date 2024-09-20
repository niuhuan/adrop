import 'dart:io';

import 'package:flutter/material.dart';
import '../configs/configs.dart';

class SendingSettingsScreen extends StatefulWidget {
  const SendingSettingsScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SendingSettingsScreenState();
}

class _SendingSettingsScreenState extends State<SendingSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发送文件设置'),
      ),
      body: ListView(
        children: <Widget>[
          zipOnSendSwitchListTile(),
          zipOnSendRenameSwitchListTile(),
          if (Platform.isIOS || Platform.isAndroid)
            keepScreenUpOnSendingSwitchListTile(),
        ],
      ),
    );
  }
}
