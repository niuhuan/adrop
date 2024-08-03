import 'package:flutter/material.dart';

class ChooseDeviceScreen extends StatefulWidget {
  final String deriveId;
  final String folderId;
  final String password;

  const ChooseDeviceScreen({
    required this.deriveId,
    required this.folderId,
    required this.password,
    super.key,
  });

  @override
  State<ChooseDeviceScreen> createState() => _ChooseDeviceScreenState();
}

class _ChooseDeviceScreenState extends State<ChooseDeviceScreen> {
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
      appBar: AppBar(title: const Text('Choose Device')),
    );
  }
}
