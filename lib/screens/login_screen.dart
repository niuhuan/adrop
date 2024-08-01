import 'dart:developer';
import 'dart:io';
import 'package:adrop/screens/space_choose_screen.dart';
import 'package:adrop/src/rust/api/user.dart';
import 'package:adrop/src/rust/api/user_setting.dart';
import 'package:adrop/src/rust/api/system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../src/rust/data_obj/enums.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => createLoginScreenState();
}

State<LoginScreen> createLoginScreenState() {
  if (Platform.isAndroid || Platform.isIOS) {
    return _MobileLoginScreenState();
  }
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    return _DesktopLoginScreenState();
  }
  throw UnsupportedError('Unsupported platform');
}

class _MobileLoginScreenState extends State<LoginScreen> {
  bool _serviceStarted = false;
  late InAppWebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _serviceStarted
          ? InAppWebView(
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
                safeBrowsingEnabled: true,
                isFraudulentWebsiteWarningEnabled: true,
              ),
              onWebViewCreated: onWebViewCreated,
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  void onWebViewCreated(InAppWebViewController controller) {
    _webViewController = controller;
    _webViewController.addJavaScriptHandler(
      handlerName: "finish",
      callback: _finish,
    );
  }

  void _finish(List<dynamic> args) async {
    var navigator = Navigator.of(context);
    await stopLoginService();
    navigator.pushReplacement(
      MaterialPageRoute(builder: (context) => const SpaceChooseScreen()),
    );
  }

  init() async {
    await startLoginService();
    setState(() {
      _serviceStarted = true;
    });
  }
}

class _DesktopLoginScreenState extends State<LoginScreen> {
  bool _serviceStarted = false;
  bool disposed = false;

  @override
  void initState() {
    super.initState();
    init();
    startTimer();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _serviceStarted
          ? _openByBrowser()
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  Widget _openByBrowser() {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          openByBrowser(url: "http://localhost:23767/html/index.html");
        },
        child: const Text('打开浏览器进行认证'),
      ),
    );
  }

  Future<dynamic> init() async {
    await startLoginService();
    setState(() {
      _serviceStarted = true;
    });
  }

  startTimer() {
    if (!disposed) {
      Future.delayed(const Duration(seconds: 1), () async {
        if (!disposed) {
          await checkLogin();
          startTimer();
        }
      });
    }
  }

  Future<void> checkLogin() async {
    var info = await loginInfo();
    log("login state: ${info.state}");
    if (info.state == LoginState.set_) {
      disposed = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SpaceChooseScreen()),
      );
    }
  }
}
