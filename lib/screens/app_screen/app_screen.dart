import 'dart:async';
import 'package:adrop/screens/app_screen/receive_file.dart';
import 'package:adrop/screens/app_screen/send_file.dart';
import 'package:adrop/screens/app_screen/sending.dart';
import 'package:adrop/src/rust/data_obj.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> with WindowListener {
  final SendingController _sendingController = SendingController();
  var _currentIndex = 1;

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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          Sending(
            controller: _sendingController,
          ),
          SendFile(
            sendFiles: _sendFiles,
          ),
          const ReceiveFile(),
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
            icon: Icon(Icons.upload),
            label: '发送中',
          ),
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

  Future<bool> _sendFiles(Device device, List<SelectionFile> files) async {
    final response = await _sendingController.send(device, files);
    if (response) {
      setState(() {
        _currentIndex = 0;
      });
    }
    return response;
  }
}
