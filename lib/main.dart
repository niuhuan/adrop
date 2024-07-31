import 'package:adrop/screens/init_screen.dart';
import 'package:flutter/material.dart';
import 'package:adrop/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
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
