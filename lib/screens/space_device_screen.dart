import 'package:adrop/src/rust/api/space.dart';
import 'package:flutter/material.dart';

import '../components/common.dart';
import 'app_screen.dart';

class SpaceDeviceScreen extends StatefulWidget {
  final String deriveId;
  final String folderId;
  final String password;

  const SpaceDeviceScreen({
    required this.deriveId,
    required this.folderId,
    required this.password,
    super.key,
  });

  @override
  State<SpaceDeviceScreen> createState() => _SpaceDeviceScreenState();
}

class _SpaceDeviceScreenState extends State<SpaceDeviceScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('当前设备?'),
        elevation: 1,
      ),
      body: Column(children: [
        _title("从已知设备中选择"),
        Expanded(child: _chooseOld()),
        const Divider(),
        _title("是一个新设备"),
        Expanded(child: _createNew()),
      ]),
    );
  }

  Widget _title(String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(title, style: const TextStyle(fontSize: 20)),
    );
  }

  Widget _chooseOld() {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        return ListTile(
          title: const Text("设备名称"),
          subtitle: const Text("设备描述"),
          onTap: () {},
        );
      },
    );
  }

  var _inputName = "";

  Widget _createNew() {
    return Column(children: [
      Container(
        margin: const EdgeInsets.all(20),
        child: TextField(
          decoration: const InputDecoration(hintText: "设备名称"),
          onChanged: (v) {
            _inputName = v;
          },
        ),
      ),
      ElevatedButton(
        onPressed: () async {
          // not_blank
          if (_inputName.isEmpty) {
            defaultToast(context, "设备名称不能为空");
            return;
          }
          // confirm
          bool? confirm = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("确认创建新设备"),
                content: Text("设备名称: $_inputName"),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text("取消"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text("确认"),
                  ),
                ],
              );
            },
          );
          if (confirm != true) {
            return;
          }
          try {
            await createNewDevice(
              driveId: widget.deriveId,
              parentFolderFileId: widget.folderId,
              truePassBase64: widget.password,
              deviceName: _inputName,
              deviceType: 0,
            );
            Navigator.of(context)
                .pushReplacement(MaterialPageRoute(builder: (context) {
              return const AppScreen();
            }));
          } catch (e, s) {
            defaultToast(context, "创建失败\n$e");
          }
        },
        child: const Text("创建"),
      ),
    ]);
  }
}
