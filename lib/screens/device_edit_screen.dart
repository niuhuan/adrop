import 'package:adrop/components/common.dart';
import 'package:adrop/components/device_type.dart';
import 'package:flutter/material.dart';

import '../src/rust/api/space.dart';
import '../src/rust/data_obj.dart';
import 'app_screen/common.dart';

class DeviceEditScreen extends StatefulWidget {
  final Device device;

  const DeviceEditScreen({super.key, required this.device});

  @override
  State<DeviceEditScreen> createState() => _DeviceEditScreenState();
}

class _DeviceEditScreenState extends State<DeviceEditScreen> {
  late final TextEditingController _textController =
      TextEditingController(text: widget.device.name);
  late int _deviceType = widget.device.deviceType;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑设备'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              try {
                await renameDevice(
                  fileId: widget.device.folderFileId,
                  newDeviceName: _textController.text.trim(),
                  newDeviceType: _deviceType,
                );
                defaultToast(context, "编辑设备成功");
                Navigator.of(context).pop(true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("编辑设备失败: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Divider(),
          ListTile(
            title: const Text("原设备名"),
            subtitle: Text(widget.device.name),
          ),
          ListTile(
            title: const Text("原设备类型"),
            trailing: Icon(deviceIcon(widget.device.deviceType)),
          ),
          const Divider(),
          ListTile(
            title: const Text("新设备名"),
            subtitle: TextField(
              controller: _textController,
            ),
          ),
          ListTile(
            title: const Text("新设备类型"),
            trailing: DropdownButton<int>(
              value: _deviceType,
              items: const [
                DropdownMenuItem(
                  value: DeviceType.unknown,
                  child: Row(
                    children: [
                      Icon(Icons.help),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: DeviceType.macbook,
                  child: Row(
                    children: [
                      Icon(Icons.laptop_mac),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: DeviceType.windows,
                  child: Row(
                    children: [
                      Icon(Icons.laptop_windows),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: DeviceType.linux,
                  child: Row(
                    children: [
                      Icon(Icons.laptop_windows),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: DeviceType.iphone,
                  child: Row(
                    children: [
                      Icon(Icons.phone_iphone),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: DeviceType.ipad,
                  child: Row(
                    children: [
                      Icon(Icons.tablet_mac),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: DeviceType.android,
                  child: Row(
                    children: [
                      Icon(Icons.phone_android),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _deviceType = value!;
                });
              },
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
