import 'dart:io';

import 'package:adrop/components/common.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

bool autoStartup = false;

Future<void> initAutoStartup() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  launchAtStartup.setup(
    appName: packageInfo.appName,
    appPath: Platform.resolvedExecutable,
    packageName: 'opensource.adrop',
  );
  autoStartup = await launchAtStartup.isEnabled();
}

Future<void> setAutoStartup(bool enable, BuildContext context) async {
  if (enable) {
    await launchAtStartup.enable();
    defaultToast(context, "已设置开机自启");
  } else {
    await launchAtStartup.disable();
    defaultToast(context, "已取消开机自启");
  }
  autoStartup = enable;
}

Widget autoStartupIcon() {
  if (Platform.isIOS || Platform.isAndroid) {
    return Container();
  }
  return StatefulBuilder(
    builder: (BuildContext context, void Function(void Function()) setState) {
      return IconButton(
        onPressed: () async {
          await setAutoStartup(!autoStartup, context);
          setState(() {});
        },
        icon: Icon(
          autoStartup ? Icons.power : Icons.power_off,
        ),
      );
    },
  );
}
