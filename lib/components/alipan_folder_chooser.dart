import 'package:adrop/components/common.dart';
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
  final ItemListController _itemListController = ItemListController();
  final List<FileItem> _current = [];

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
                  showCreateFolderDialog();
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
            controller: _itemListController,
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

  showCreateFolderDialog() async {
    var path = "根文件夹/${_current.map((e) => e.fileName).join("/")}";
    var textController = TextEditingController(text: "");
    bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("在云盘中新建文夹"),
          content: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("当前路径: $path"),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  hintText: "文件夹名称",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text("确定"),
            ),
          ],
        );
      },
    );
    var text = textController.text;
    textController.dispose();
    if (confirm == true && text.isNotEmpty) {
      try {
        await createFolder(
          driveId: widget.deriveId,
          parentFolderFileId: lastFolderFileId(_current),
          folderName: text,
        );
        _itemListController.refresh();
        defaultToast(context, "成功");
      } catch (e, s) {
        print("$e\n$s");
        defaultToast(context, "$e");
      }
    }
  }
}

class ItemList extends StatefulWidget {
  const ItemList({
    super.key,
    required this.controller,
    required this.folderFileId,
    required this.driveId,
    required this.onChooseFolder,
  });

  final ItemListController controller;
  final String driveId;
  final String folderFileId;
  final void Function(FileItem item) onChooseFolder;

  @override
  State<StatefulWidget> createState() => _ItemListState();
}

class _ItemListState extends State<ItemList> {
  late Future<List<FileItem>> _itemsFuture = listFolder(
    driveId: widget.driveId,
    parentFolderFileId: widget.folderFileId,
  );
  late Key _key = UniqueKey();

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.controller._state == this) {
      widget.controller._state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentBuilder(
      key: _key,
      future: _itemsFuture,
      onRefresh: _refresh,
      successBuilder: (
        BuildContext context,
        AsyncSnapshot<List<FileItem>> snapshot,
      ) {
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

  Future<dynamic> _refresh() async {
    setState(() {
      _itemsFuture = listFolder(
        driveId: widget.driveId,
        parentFolderFileId: widget.folderFileId,
      );
      _key = UniqueKey();
    });
  }
}

class ItemListController {
  _ItemListState? _state;

  void refresh() {
    _state?._refresh();
  }
}
