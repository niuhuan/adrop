import 'dart:io';

import 'package:adrop/screens/init_screen.dart';
import 'package:flutter/material.dart';
import 'package:adrop/src/rust/frb_generated.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

import 'components/launch_at_startup.dart';

class W with WindowListener {
  const W();

  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
    if (Platform.isMacOS) {
      await windowManager.setSkipTaskbar(true);
    }
  }
}

class T with TrayListener {
  const T();

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      await windowManager.show();
      if (Platform.isMacOS) {
        await windowManager.setSkipTaskbar(false);
      }
    } else if (menuItem.key == 'exit_app') {
      exit(0);
    }
  }
}

const w = W();
const t = T();

setWindowManager() async {
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  windowManager.addListener(w);
}

setTrayManager() async {
  await trayManager.setIcon(
    Platform.isWindows ? 'lib/assets/app_icon.ico' : 'lib/assets/app_icon.png',
  );
  Menu menu = Menu(
    items: [
      MenuItem(
        key: 'show_window',
        label: '显示窗口',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'exit_app',
        label: '退出应用',
      ),
    ],
  );
  await trayManager.setContextMenu(menu);
  trayManager.addListener(t);
}

Future<void> main() async {
  await RustLib.init();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    WidgetsFlutterBinding.ensureInitialized();
    await setWindowManager();
    await setTrayManager();
    await initAutoStartup();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: InitScreen(),
    );
  }
}
