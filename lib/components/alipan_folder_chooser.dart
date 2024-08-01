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
    var ffi = folderFileId();
    return Column(
      children: [
        Expanded(
          key: Key("AFC:$ffi"),
          child: ItemList(
            folderFileId: ffi,
          ),
        ),
      ],
    );
  }

  String folderFileId() {
    if (_current.isEmpty) {
      return "root";
    }
    return _current.last.fileId;
  }
}

class ItemList extends StatefulWidget {
  const ItemList({super.key, required this.folderFileId});

  final String folderFileId;

  @override
  State<StatefulWidget> createState() => _ItemListState();
}

class _ItemListState extends State<ItemList> {
  late Future<List<Node>> _itemsFuture = _loadItems();

  Future<List<Node>> _loadItems() async {
    return [];
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
    return FutureBuilder<List<Node>>(
      future: _itemsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Node>> snapshot) {
        if (snapshot.hasError) {
          return Text("Error: ${snapshot.error}");
        }
        if (snapshot.hasData) {
          return ListView.builder(
            itemCount: snapshot.requireData.length,
            itemBuilder: (BuildContext context, int index) {
              return ListTile(
                title: Text(snapshot.requireData[index].fileName),
                onTap: () {
                  setState(() {
                    // TODO
                  });
                },
              );
            },
          );
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}

class Node {
  String fileName = "";
  String fileId = "";
}
