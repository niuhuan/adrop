import 'dart:async';
import 'dart:io';

import 'package:adrop/components/content_builder.dart';
import 'package:adrop/src/rust/api/space.dart';
import 'package:adrop/src/rust/data_obj.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  var _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('aDrop'),
        elevation: 1,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          SendFile(),
          ReceiveFile(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.send),
            label: '发送',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_received),
            label: '接收',
          ),
        ],
      ),
    );
  }
}

class SendFile extends StatefulWidget {
  const SendFile({super.key});

  @override
  State<SendFile> createState() => _SendFileState();
}

class _SendFileState extends State<SendFile> {
  late Future<List<Device>> _devicesFuture;
  late Key _key;
  final List<XFile> _list = [];

  Future _refresh() async {
    setState(() {
      _devicesFuture = listDevicesByConfig();
      _key = UniqueKey();
    });
  }

  @override
  void initState() {
    _refresh();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _dropFile(_selectedFiles()),
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
        setState(() {
          _list.addAll(files);
        });
      },
      child: widget,
    );
  }

  Widget _selectedFiles() {
    return Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          MaterialButton(
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
          ),
          Container(
            width: 20,
          ),
          MaterialButton(
            onPressed: _showFilesDialog,
            child: Row(
              children: [
                const Icon(Icons.file_copy_rounded),
                Text(" 将发送 ${_list.length} 个文件(夹), 点击预览"),
              ],
            ),
          ),
          const Expanded(
            child: Text(
              "将文件拖动到此处",
              textAlign: TextAlign.center,
            ),
          ),
          MaterialButton(
            onPressed: () {},
            child: const Row(
              children: [
                Icon(Icons.add),
                Text("添加"),
              ],
            ),
          ),
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
        return ListView.builder(
          itemCount: devices.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == devices.length) {
              return Container(
                padding: const EdgeInsets.all(10),
                child: Text("共 ${devices.length} 台设备"),
              );
            }
            var device = devices[index];
            return ListTile(
              onTap: () {},
              title: Text(device.name),
              leading: const Icon(Icons.computer),
            );
          },
        );
      },
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
                    leading: const Icon(Icons.file_copy),
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
}

class ReceiveFile extends StatefulWidget {
  const ReceiveFile({super.key});

  @override
  State<ReceiveFile> createState() => _ReceiveFileState();
}

class _ReceiveFileState extends State<ReceiveFile> {
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
    return const Center(
      child: Text('Receive File'),
    );
  }
}
