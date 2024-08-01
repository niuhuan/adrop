import 'package:flutter/material.dart';

class AlipanFolderChooser extends StatefulWidget {
  const AlipanFolderChooser({super.key, required this.deriveId});

  final String deriveId;

  @override
  State<StatefulWidget> createState() => _AlipanFolderChooserState();
}

class _AlipanFolderChooserState extends State<AlipanFolderChooser> {
  List<Node> _current = [];

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
    return Column(
      children: [],
    );
  }
}

class Node {
  String fileName = "";
  String fileId = "";
}
