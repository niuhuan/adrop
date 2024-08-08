import 'package:adrop/components/common.dart';
import 'package:adrop/components/content_error.dart';
import 'package:adrop/screens/space_device_screen.dart';
import 'package:adrop/src/rust/api/space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

class SpaceConfigScreen extends StatefulWidget {
  final String deriveId;
  final String folderId;

  const SpaceConfigScreen({
    required this.deriveId,
    required this.folderId,
    super.key,
  });

  @override
  State<SpaceConfigScreen> createState() => _SpaceConfigScreenState();
}

class _SpaceConfigScreenState extends State<SpaceConfigScreen> {
  static const int stateInit = 0;
  static const int initSuccess = 1;
  static const int initFail = 2;

  int statue = stateInit;

  String? _passwordEnc;

  Object? _error;
  StackTrace? _stackTrace;

  var _inputPassword = "";

  Future<void> onRefresh() async {
    setState(() {
      statue = stateInit;
    });
    try {
      _passwordEnc = await hasSetPassword(
        driveId: widget.deriveId,
        parentFolderFileId: widget.folderId,
      );
      setState(() {
        statue = initSuccess;
      });
    } catch (e, s) {
      setState(() {
        statue = initFail;
        _error = e;
        _stackTrace = s;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    onRefresh();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (statue) {
      case stateInit:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case initSuccess:
        return _successBody();
      case initFail:
        return Scaffold(
          body: ContentError(
            error: _error,
            stackTrace: _stackTrace,
            onRefresh: onRefresh,
          ),
        );
      default:
        return const Center(
          child: Text('未知错误'),
        );
    }
  }

  Widget _successBody() {
    return _passwordEnc == null ? _setNewPassword() : _checkOldPassword();
  }

  Widget _setNewPassword() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置传输文件夹的密码'),
      ),
      body: Column(
        children: [
          Container(height: 30),
          const Text('当前路径不存在密码文件, 需要传输文件应设置新密码, 请输入'),
          Container(height: 30),
          Container(
            margin: const EdgeInsets.only(
              left: 20,
              right: 20,
            ),
            child: TextField(
              onChanged: (value) {
                _inputPassword = value;
              },
            ),
          ),
          Container(height: 30),
          ElevatedButton(
            onPressed: () async {
              try {
                var truePass = await setNewPassword(
                  driveId: widget.deriveId,
                  parentFolderFileId: widget.folderId,
                  password: _inputPassword,
                );
                defaultToast(context, "设置密码成功");
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => SpaceDeviceScreen(
                      driveId: widget.deriveId,
                      folderId: widget.folderId,
                      password: truePass,
                    ),
                  ),
                );
              } catch (e, s) {
                defaultToast(context, "设置密码失败\n$e");
              }
            },
            child: const Text('确定设置新密码'),
          ),
        ],
      ),
    );
  }

  Widget _checkOldPassword() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('传输文件夹的密码'),
      ),
      body: Column(
        children: [
          Container(height: 30),
          Container(
            margin: const EdgeInsets.only(
              left: 20,
              right: 20,
            ),
            child: TextField(
              onChanged: (value) {
                _inputPassword = value;
              },
            ),
          ),
          Container(height: 30),
          ElevatedButton(
            onPressed: () async {
              try {
                var truePass = await checkOldPassword(
                  passwordEnc: _passwordEnc!,
                  password: _inputPassword,
                );
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => SpaceDeviceScreen(
                      driveId: widget.deriveId,
                      folderId: widget.folderId,
                      password: truePass,
                    ),
                  ),
                );
              } catch (e, s) {
                if (e is AnyhowException) {
                  AnyhowException ex = e;
                  defaultToast(context, ex.message);
                } else {
                  defaultToast(context, "密码错误\n$e");
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
