import 'package:adrop/components/content_builder.dart';
import 'package:flutter/material.dart';
import '../components/alipan_folder_chooser.dart';
import '../components/folder_info.dart';
import '../src/rust/api/space.dart';

class SpaceChooseScreen extends StatefulWidget {
  const SpaceChooseScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SpaceChooseScreenState();
}

class _SpaceChooseScreenState extends State<SpaceChooseScreen> {
  late Future<String> _defaultDriveFuture = _loadDefaultDerive();
  late Key _driveKey = UniqueKey();
  String _folderId = "root";

  Future<String> _loadDefaultDerive() async {
    var di = await oauthDeriveInfo();
    return di.defaultDriveId;
  }

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
      body: ContentBuilder(
        key: _driveKey,
        future: _defaultDriveFuture,
        onRefresh: () async {
          setState(() {
            _defaultDriveFuture = _loadDefaultDerive();
            _driveKey = UniqueKey();
          });
        },
        successBuilder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          return AlipanFolderChooser(
            key: const Key("AlipanFolderChooser"),
            deriveId: snapshot.requireData,
            onFolderChange: _onFolderChange,
            onFolderCheck: _onFolderCheck,
          );
        },
      ),
    );
  }

  Widget buildChooser(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Space Set'),
      ),
    );
  }

  void _onFolderChange(List<FileItem> items) {
    setState(() {
      _folderId = lastFolderFileId(items);
    });
  }

  void _onFolderCheck(List<FileItem> items) {
    setState(() {
      _folderId = lastFolderFileId(items);
    });
  }
}
