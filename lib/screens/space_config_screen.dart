import 'package:adrop/components/common.dart';
import 'package:adrop/components/content_error.dart';
import 'package:adrop/screens/choose_device_screen.dart';
import 'package:adrop/src/rust/api/space.dart';
import 'package:flutter/material.dart';

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
    return Scaffold(
      body: _body(),
    );
  }

  Widget _body() {
    switch (statue) {
      case stateInit:
        return const Center(
          child: CircularProgressIndicator(),
        );
      case initSuccess:
        return _successBody();
      case initFail:
        return ContentError(
          error: _error,
          stackTrace: _stackTrace,
          onRefresh: onRefresh,
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
    return Column(
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
              await setNewPassword(
                driveId: widget.deriveId,
                parentFolderFileId: widget.folderId,
                password: _inputPassword,
              );
              defaultToast(context, "设置密码成功");
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => ChooseDeviceScreen(
                    deriveId: widget.deriveId,
                    folderId: widget.folderId,
                    password: _inputPassword,
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
    );
  }

  Widget _checkOldPassword() {
    return Column(
      children: [
        Container(height: 30),
        const Text('输入当前传输文件夹的密码'),
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
              await checkOldPassword(
                passwordEnc: _passwordEnc!,
                password: _inputPassword,
              );
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => ChooseDeviceScreen(
                    deriveId: widget.deriveId,
                    folderId: widget.folderId,
                    password: _inputPassword,
                  ),
                ),
              );
            } catch (e, s) {
              defaultToast(context, "密码错误\n$e");
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
