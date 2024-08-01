import 'package:adrop/components/content_builder.dart';
import 'package:flutter/material.dart';
import '../components/alipan_folder_chooser.dart';
import '../src/rust/api/space.dart';

class SpaceChooseScreen extends StatefulWidget {
  const SpaceChooseScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SpaceChooseScreenState();
}

class _SpaceChooseScreenState extends State<SpaceChooseScreen> {
  late Future<String> _defaultDeriveFuture = _loadDefaultDerive();
  late Key _derviceKey = UniqueKey();

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
        key: _derviceKey,
        future: _defaultDeriveFuture,
        onRefresh: () async {
          setState(() {
            _defaultDeriveFuture = _loadDefaultDerive();
            _derviceKey = UniqueKey();
          });
        },
        successBuilder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          return AlipanFolderChooser(
            key: const Key("AlipanFolderChooser"),
            deriveId: snapshot.requireData,
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
}
