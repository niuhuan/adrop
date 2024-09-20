import 'dart:async';
import 'dart:io';

import 'package:adrop/screens/sending_settings_screen.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../components/common.dart';
import '../../components/content_builder.dart';
import '../../src/rust/api/nope.dart';
import '../../src/rust/api/space.dart';
import '../../src/rust/data_obj.dart';
import '../device_edit_screen.dart';
import 'common.dart';

class SendFile extends StatefulWidget {
  final FutureOr<dynamic> Function(Device device, List<SelectionFile> files)
      sendFiles;

  const SendFile({required this.sendFiles, super.key});

  @override
  State<SendFile> createState() => _SendFileState();
}

class _SendFileState extends State<SendFile> {
  final handler = ShareHandlerPlatform.instance;
  late Future<List<Device>> _devicesFuture;
  late Key _key;
  final List<SelectionFile> _list = [];

  Future _initMedia() async {
    if (Platform.isAndroid || Platform.isIOS) {
      handler.sharedMediaStream.listen(processMedia);
      processMedia(await handler.getInitialSharedMedia());
    }
  }

  Future _disposeMedia() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // remove listen
    }
  }

  Future processMedia(SharedMedia? media) async {
    if (media != null) {
      if (media.attachments != null) {
        var attachments = media.attachments!;
        var addFiles = <SelectionFile>[];
        for (var value in attachments) {
          if (value != null) {
            try {
              print(value.path);
              var sp = value.path.split("/");
              var addFile = await matchSelectionFile(
                name: sp[sp.length - 1],
                path: value.path,
              );
              addFiles.add(addFile);
            } catch (e) {
              print(e);
              defaultToast(context, '文件解析失败 $e');
            }
          }
        }
        if (addFiles.isNotEmpty) {
          setState(() {
            _list.addAll(addFiles);
          });
          defaultToast(context, '已添加 ${addFiles.length} 个文件');
        }
      }
    }
  }

  Future _refresh() async {
    setState(() {
      _devicesFuture = listDevicesByConfig();
      _key = UniqueKey();
    });
  }

  @override
  void initState() {
    _refresh();
    _initMedia();
    super.initState();
  }

  @override
  void dispose() {
    _disposeMedia();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('aDrop'),
        centerTitle: false,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: () async {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (BuildContext context) =>
                    const SendingSettingsScreen(),
              ));
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          _selectedFiles(),
          Expanded(
            child: _devices(),
          )
        ],
      ),
    );
  }

  Widget _dropFile(Widget widget) {
    return DropTarget(
      onDragDone: (details) async {
        var files = details.files;
        var addFiles = <SelectionFile>[];
        for (var value in files) {
          try {
            var addFile = await matchSelectionFile(
              name: value.name,
              path: value.path,
            );
            addFiles.add(addFile);
          } catch (e) {
            print(e);
            defaultToast(context, '文件解析失败 $e');
          }
        }
        setState(() {
          _list.addAll(addFiles);
        });
      },
      child: widget,
    );
  }

  Widget _selectedFiles() {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return _dropFile(_selectedFilesDesktop());
    }
    if (Platform.isIOS || Platform.isAndroid) {
      return _selectedFilesMobile();
    }
    return const Center(
      child: Text("未适配的平台"),
    );
  }

  Widget _selectedFilesDesktop() {
    final windowWidth = MediaQuery.of(context).size.width;
    if (windowWidth < 650) {
      return Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.withOpacity(.1),
            width: 2.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _clearFileListButton(),
                Expanded(child: Container()),
                _fileListPreviewButton(),
              ],
            ),
            Container(
              padding: const EdgeInsets.only(
                left: 10,
                right: 10,
                top: 5,
                bottom: 5,
              ),
              child: Divider(
                height: 1,
                color: Colors.grey.withOpacity(.1),
              ),
            ),
            Row(
              children: [
                _dropTips(),
                Expanded(child: Container()),
                _addFilesButton(),
              ],
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.withOpacity(.05),
          width: 2.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          _clearFileListButton(),
          Container(
            width: 20,
          ),
          _fileListPreviewButton(),
          Expanded(
            child: _dropTips(),
          ),
          _addFilesButton(),
        ],
      ),
    );
  }

  Widget _selectedFilesMobile() {
    return Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _clearFileListButton(),
              Expanded(child: Container()),
              _fileListPreviewButton(),
            ],
          ),
          const Divider(),
          Row(
            children: [
              _addMediaButton(),
              Expanded(child: Container()),
              _addFilesButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clearFileListButton() {
    return MaterialButton(
      onPressed: () async {
        setState(() {
          _list.clear();
        });
      },
      child: const Row(
        children: [
          Icon(
            Icons.clear,
          ),
          Text("清除"),
        ],
      ),
    );
  }

  Widget _fileListPreviewButton() {
    var text = "将发送 ${_list.length} 个文件(夹)";
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      text += ", (点击预览)";
    }
    return MaterialButton(
      onPressed: _showFilesDialog,
      child: Row(
        children: [
          const Icon(Icons.file_copy_rounded),
          Text(
            text,
          ),
        ],
      ),
    );
  }

  Widget _dropTips() {
    return const Text(
      "将文件拖动到此处",
      textAlign: TextAlign.center,
    );
  }

  Widget _addFilesButton() {
    var text = "添加";
    if (Platform.isIOS || Platform.isAndroid) {
      text = "添加文件";
    }
    return MaterialButton(
      onPressed: () async {
        var choose = await FilePicker.platform.pickFiles(
          allowMultiple: true,
        );
        if (choose != null) {
          var addFiles = <SelectionFile>[];
          for (var value in choose.files) {
            if (value.path != null) {
              try {
                var addFile = await matchSelectionFile(
                  name: value.name,
                  path: value.path!,
                );
                addFiles.add(addFile);
              } catch (e) {
                print(e);
                defaultToast(context, '文件解析失败 $e');
              }
            }
          }
          setState(() {
            _list.addAll(addFiles);
          });
        }
      },
      child: Row(
        children: [
          const Icon(Icons.add),
          Text(text),
        ],
      ),
    );
  }

  Widget _addMediaButton() {
    return MaterialButton(
      onPressed: () async {
        final List<AssetEntity>? result = await AssetPicker.pickAssets(
          context,
          pickerConfig: const AssetPickerConfig(
            maxAssets: 999,
          ),
        );
        if (result == null) {
          return;
        }
        var addFiles = <SelectionFile>[];
        for (var ae in result) {
          final file = await ae.originFile;
          if (file == null) {
            continue;
          }
          final path = file.path;
          final name = await ae.titleAsync;
          var addFile = await matchSelectionFile(
            name: name,
            path: path,
          );
          addFiles.add(addFile);
        }
        setState(() {
          _list.addAll(addFiles);
        });
      },
      child: const Row(
        children: [
          Icon(Icons.movie),
          Text("添加媒体"),
        ],
      ),
    );
  }

  Widget _devices() {
    return ContentBuilder(
      key: _key,
      future: _devicesFuture,
      onRefresh: _refresh,
      successBuilder: (
        BuildContext context,
        AsyncSnapshot<List<Device>> snapshot,
      ) {
        var devices = snapshot.data!;
        final tips = Container(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Text("共 ${devices.length} 台设备"),
              Expanded(child: Container()),
              _refreshDevicesButton(),
            ],
          ),
        );
        final list = _deviceList(devices);
        return Column(
          children: [
            tips,
            Expanded(
              child: list,
            ),
          ],
        );
      },
    );
  }

  Widget _deviceList(List<Device> devices) {
    final windowWidth = MediaQuery.of(context).size.width;
    if (windowWidth < 510) {
      return ListView.builder(
        itemCount: devices.length,
        itemBuilder: (BuildContext context, int index) {
          var device = devices[index];
          return _dropToDevice(
            device,
            _deviceTile(device),
          );
        },
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        width: double.maxFinite,
        child: Wrap(
          runSpacing: 10,
          spacing: 10,
          alignment: WrapAlignment.start,
          children: [
            for (var device in devices)
              _dropToDevice(
                device,
                _deviceButton(device),
              ),
          ],
        ),
      ),
    );
  }

  Widget _deviceTile(Device device) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: ListTile(
        onTap: () async {
          _sendFiles(device);
        },
        onLongPress: () async {
          _deviceMenu(context, device);
        },
        title: Text(device.name + (device.thisDevice ? " (本机)" : "")),
        leading: Icon(
          deviceIcon(device.deviceType),
          size: 40,
        ),
      ),
    );
  }

  Widget _deviceButton(Device device) {
    return MaterialButton(
      onPressed: () {
        _sendFiles(device);
      },
      onLongPress: () async {
        _deviceMenu(context, device);
      },
      child: Container(
        margin: const EdgeInsets.only(
          top: 10,
          left: 10,
          right: 10,
          bottom: 10,
        ),
        padding: const EdgeInsets.only(
          top: 10,
          left: 20,
          right: 20,
          bottom: 10,
        ),
        child: Column(
          children: [
            Icon(
              deviceIcon(device.deviceType),
              size: 80,
            ),
            const SizedBox(width: 10, height: 10),
            Text(device.name),
          ],
        ),
      ),
    );
  }

  Widget _dropToDevice(Device device, Widget child) {
    if (Platform.isIOS || Platform.isAndroid) {
      return child;
    }
    return DropTarget(
      onDragDone: (details) async {
        var files = details.files;
        var addFiles = <SelectionFile>[];
        for (var value in files) {
          try {
            var addFile = await matchSelectionFile(
              name: value.name,
              path: value.path,
            );
            addFiles.add(addFile);
          } catch (e) {
            print(e);
            defaultToast(context, '文件解析失败 $e');
          }
        }
        await widget.sendFiles(device, addFiles);
      },
      child: child,
    );
  }

  Widget _refreshDevicesButton() {
    return MaterialButton(
      onPressed: _refresh,
      child: const Row(
        children: [
          Icon(Icons.sync),
          Text("刷新设备列表"),
        ],
      ),
    );
  }

  void _showFilesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("已选择的文件"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: [
                ..._list.map((file) {
                  return ListTile(
                    title: Text(file.name),
                    leading: iconOfFileType(file.fileItemType),
                  );
                }),
              ],
            ),
          ),
          actions: [
            MaterialButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("确定"),
            ),
          ],
        );
      },
    );
  }

  Future _sendFiles(Device device) async {
    if (_list.isEmpty) {
      defaultToast(context, '请选择要发送的文件');
      return;
    }
    await widget.sendFiles(device, _list);
    setState(() {
      _list.clear();
    });
  }

  Future _deviceMenu(BuildContext context, Device device) async {
    final result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text("设备操作"),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop(0);
              },
              child: const Text("编辑设备"),
            ),
          ],
        );
      },
    );
    if (result == null) {
      return;
    }
    if (result == 0) {
      final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (BuildContext context) => DeviceEditScreen(device: device),
      ));
      if (result != null) {
        _refresh();
      }
    }
  }
}
