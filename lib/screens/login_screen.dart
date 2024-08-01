import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => createLoginScreenState();
}

State<LoginScreen> createLoginScreenState() {
  if (Platform.isMacOS || Platform.isAndroid || Platform.isIOS) {
    return _InnerWebviewLoginScreenState();
  }
  if (Platform.isWindows || Platform.isLinux) {
    return _DesktopLoginScreenState();
  }
  throw UnsupportedError('Unsupported platform');
}

class _InnerWebviewLoginScreenState extends State<LoginScreen> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebView(),
    );
  }
}

class _DesktopLoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Text('Login Screen'),
          ],
        ),
      ),
    );
  }
}
