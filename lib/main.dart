import 'dart:io';
import 'package:adrop/src/rust/api/init.dart';
import 'package:adrop/src/rust/api/single_instance_stream.dart';
import 'package:flutter/material.dart';
import 'package:adrop/screens/init_screen.dart';
import 'package:adrop/src/rust/frb_generated.dart';
import 'package:window_manager/window_manager.dart';
import 'configs/desktop_layout.dart';
import 'configs/launch_at_startup.dart';
import 'cross.dart';

Future<void> main() async {
  await RustLib.init();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await initPath(localPath: await cross.root());
    WidgetsFlutterBinding.ensureInitialized();
    await setWindowManager();
    await setTrayManager();
    await initAutoStartup();
    registerSiListener().listen((event) async {
      await windowManager.show();
      if (Platform.isMacOS) {
        await windowManager.setSkipTaskbar(false);
      }
    });
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
