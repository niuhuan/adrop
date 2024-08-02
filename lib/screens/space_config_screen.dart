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
    return const Scaffold(
      body: Center(
        child: Text('SpaceConfigScreen'),
      ),
    );
  }
}
