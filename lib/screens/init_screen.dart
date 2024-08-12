import 'dart:io';

import 'package:adrop/components/a_drop_icon.dart';
import 'package:adrop/cross.dart';
import 'package:adrop/screens/app_screen/app_screen.dart';
import 'package:adrop/screens/download_settings_screen.dart';
import 'package:adrop/screens/space_choose_screen.dart';
import 'package:adrop/src/rust/api/init.dart';
import 'package:adrop/src/rust/api/user.dart';
import 'package:adrop/src/rust/data_obj/enums.dart';
import 'package:adrop/src/rust/api/space.dart';
import 'package:flutter/material.dart';
import '../configs/configs.dart';
import '../src/rust/api/download.dart';
import 'login_screen.dart';

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        return Center(
          child: SizedBox(
            width: constraints.maxWidth / 2,
            height: constraints.maxHeight / 2,
            child: const Center(
              child: ADropIcon(),
            ),
          ),
        );
      }),
    );
  }

  Future<dynamic> _init() async {
    var navigator = Navigator.of(context);
    var root = await cross.root();
    await initPath(localPath: root);
    await initConfigs();
    var li = await loginInfo();
    switch (li.state) {
      case LoginState.set_:
        var sp = await spaceInfo();
        if (sp == null) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => const SpaceChooseScreen(),
            ),
          );
        } else {
          if (null == await downloadInfo()) {
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (context) => const DownloadSettingsScreen(),
              ),
            );
          } else {
            if (Platform.isIOS) {
              // simulate the iOS document directory maybe change
              final dd = await cross.iosDocumentDirectory();
              await setDownloadConfigOnlyPath(path: dd);
            }
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (context) => const AppScreen(),
              ),
            );
          }
        }
      case LoginState.unset:
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
    }
  }
}
