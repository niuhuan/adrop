import 'dart:io';

import 'package:flutter/material.dart';
import '../configs/configs.dart';
import '../src/rust/api/user.dart';

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
          reloginListTile(context),
        ],
      ),
    );
  }
}

reloginListTile(BuildContext context) {
  return ListTile(
    title: const Text('重新登录'),
    onTap: () {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('重新登录'),
            content: const Text('是否确定重新登录?'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  relogin(context);
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    },
  );
}

relogin(BuildContext context) async {
  await clearLoginInfo();
  exit(0);
}
