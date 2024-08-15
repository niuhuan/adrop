import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:adrop/src/rust/api/property.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

class W with WindowListener {
  const W();

  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
    if (Platform.isMacOS) {
      await windowManager.setSkipTaskbar(true);
    }
  }

  @override
  void onWindowResize() async {
    final bounds = await windowManager.getBounds();
    final wb = jsonEncode({
      'width': bounds.width,
      'height': bounds.height,
      'top': bounds.top,
      'left': bounds.left,
    });
    setProperty(key: "window_bounds", value: wb);
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
  await initSize();
  windowManager.addListener(w);
}

initSize() async {
  final wb = await getProperty(key: "window_bounds");
  if (wb.isNotEmpty) {
    final bounds = jsonDecode(wb);
    final width = double.parse("${bounds['width']}");
    final height = double.parse("${bounds['height']}");
    WindowOptions windowOptions = WindowOptions(
      size: Size(width, height),
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
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
