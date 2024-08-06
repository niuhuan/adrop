import 'dart:io';

import 'package:adrop/screens/init_screen.dart';
import 'package:flutter/material.dart';
import 'package:adrop/src/rust/frb_generated.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

class W with WindowListener {

  const W();

  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
  }
}

class T with TrayListener {

  const T();

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
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
    Platform.isWindows
        ? 'lib/assets/app_icon.ico'
        : 'lib/assets/app_icon.png',
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
