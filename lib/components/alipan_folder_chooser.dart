import 'package:adrop/components/content_builder.dart';
import 'package:adrop/components/folder_info.dart';
import 'package:adrop/src/rust/api/space.dart';
import 'package:flutter/material.dart';

class AlipanFolderChooser extends StatefulWidget {
  const AlipanFolderChooser({
    super.key,
    required this.deriveId,
    required this.onFolderChange,
    required this.onFolderCheck,
  });

  final String deriveId;
  final void Function(List<FileItem> items) onFolderChange;
  final void Function(List<FileItem> items) onFolderCheck;

  @override
  State<StatefulWidget> createState() => _AlipanFolderChooserState();
}

class _AlipanFolderChooserState extends State<AlipanFolderChooser> {
  List<FileItem> _current = [];

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
    var ffi = lastFolderFileId(_current);
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: Row(
            children: [
              Container(
                width: 18,
              ),
              GestureDetector(
                onTap: () {
                  if (_current.isNotEmpty) {
                    setState(() {
                      _current.removeLast();
                    });
                    widget.onFolderChange(_current);
                  }
                },
                child: const Icon(Icons.reply),
              ),
              Container(
                width: 10,
              ),
              GestureDetector(
                onTap: () {
                },
                child: const Icon(Icons.create_new_folder),
              ),
              Container(
                width: 25,
              ),
              const Text("路径 : "),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 50,
                  ),
                  scrollDirection: Axis.horizontal,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _current.clear();
                          });
                          widget.onFolderChange(_current);
                        },
                        child: const Text(
                          "根文件夹",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < _current.length; i++) ...[
                      const Center(child: Text("  >  ")),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _current.removeRange(i + 1, _current.length);
                            });
                            widget.onFolderChange(_current);
                          },
                          child: Text(
                            _current[i].fileName,
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              Container(
                width: 25,
              ),
              GestureDetector(
                onTap: () {
                  widget.onFolderCheck(_current);
                },
                child: const Icon(Icons.check),
              ),
              Container(
                width: 18,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          key: Key("AFC:$ffi"),
          child: ItemList(
            driveId: widget.deriveId,
            folderFileId: ffi,
            onChooseFolder: (item) {
              setState(() {
                _current.add(item);
              });
              widget.onFolderChange(_current);
            },
          ),
        ),
      ],
    );
  }
}

class ItemList extends StatefulWidget {
  const ItemList({
    super.key,
    required this.folderFileId,
    required this.driveId,
    required this.onChooseFolder,
  });

  final String driveId;
  final String folderFileId;
  final void Function(FileItem item) onChooseFolder;

  @override
  State<StatefulWidget> createState() => _ItemListState();
}

class _ItemListState extends State<ItemList> {
  late Future<List<FileItem>> _itemsFuture = listFolder(
    deviceId: widget.driveId,
    parentFolderFileId: widget.folderFileId,
  );
  late Key _key = UniqueKey();

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
    return ContentBuilder(
      key: _key,
      future: _itemsFuture,
      onRefresh: () async {
        setState(() {
          _itemsFuture = listFolder(
            deviceId: widget.driveId,
            parentFolderFileId: widget.folderFileId,
          );
          _key = UniqueKey();
        });
      },
      successBuilder: (BuildContext context,
          AsyncSnapshot<List<FileItem>> snapshot,) {
        return ListView.builder(
          itemCount: snapshot.requireData.length,
          itemBuilder: (BuildContext context, int index) {
            var item = snapshot.requireData[index];
            return ListTile(
              leading: const Icon(Icons.folder),
              title: Text(item.fileName),
              onTap: () {
                widget.onChooseFolder(item);
              },
            );
          },
        );
      },
    );
  }
}
