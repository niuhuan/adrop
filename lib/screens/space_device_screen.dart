import 'dart:io';

import 'package:adrop/components/content_builder.dart';
import 'package:adrop/components/device_type.dart';
import 'package:adrop/screens/download_settings_screen.dart';
import 'package:adrop/src/rust/api/space.dart';
import 'package:adrop/src/rust/data_obj.dart';
import 'package:flutter/material.dart';
import '../components/common.dart';

class SpaceDeviceScreen extends StatefulWidget {
  final String driveId;
  final String folderId;
  final String password;

  const SpaceDeviceScreen({
    required this.driveId,
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
        _tips("仅限于重新安装时，或之前的设备已不再使用"),
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

  Widget _tips(String tips) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(tips, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _chooseOld() {
    return DeviceChooser(
      driveId: widget.driveId,
      folderId: widget.folderId,
      password: widget.password,
      onChoose: (device) async {
        // confirm
        bool? ok = await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("确认选择设备"),
              content: Text("设备名称: ${device.name}"),
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
        if (ok != true) {
          return;
        }
        try {
          await chooseOldDevice(
            driveId: widget.driveId,
            parentFolderFileId: widget.folderId,
            truePassBase64: widget.password,
            thisDeviceFolderFileId: device.folderFileId,
          );
          Navigator.of(context)
              .pushReplacement(MaterialPageRoute(builder: (context) {
            return const DownloadSettingsScreen();
          }));
        } catch (e) {
          defaultToast(context, "选择失败\n$e");
        }
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
              driveId: widget.driveId,
              parentFolderFileId: widget.folderId,
              truePassBase64: widget.password,
              deviceName: _inputName,
              deviceType: _deviceTypeInt(),
            );
            Navigator.of(context)
                .pushReplacement(MaterialPageRoute(builder: (context) {
              return const DownloadSettingsScreen();
            }));
          } catch (e) {
            defaultToast(context, "创建失败\n$e");
          }
        },
        child: const Text("创建"),
      ),
    ]);
  }

  int _deviceTypeInt() {
    if (Platform.isMacOS) {
      return DeviceType.macbook;
    }
    if (Platform.isWindows) {
      return DeviceType.windows;
    }
    if (Platform.isLinux) {
      return DeviceType.linux;
    }
    if (Platform.isIOS) {
      return DeviceType.iphone;
    }
    if (Platform.isAndroid) {
      return DeviceType.android;
    }
    return DeviceType.unknown;
  }
}

class DeviceChooser extends StatefulWidget {
  final String driveId;
  final String folderId;
  final String password;
  final Function(Device) onChoose;

  const DeviceChooser({
    required this.driveId,
    required this.folderId,
    required this.password,
    required this.onChoose,
    super.key,
  });

  @override
  State<DeviceChooser> createState() => _DeviceChooserState();
}

class _DeviceChooserState extends State<DeviceChooser> {
  late Future<List<Device>> _future;
  late Key _key;

  Future _onRefresh() async {
    setState(() {
      _future = listDevices(
        driveId: widget.driveId,
        parentFolderFileId: widget.folderId,
        truePassBase64: widget.password,
        thisDeviceFolderFileId: "",
      );
      _key = UniqueKey();
    });
  }

  @override
  void initState() {
    _onRefresh();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentBuilder<List<Device>>(
      key: _key,
      future: _future,
      onRefresh: _onRefresh,
      successBuilder: (context, s) {
        var data = s.requireData;
        if (data.isEmpty) {
          return const Center(child: Text("没有设备"));
        }
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) {
            var item = data[index];
            return ListTile(
              onTap: () {
                widget.onChoose(item);
              },
              title: Text(item.name),
            );
          },
        );
      },
    );
  }
}
