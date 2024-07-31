import 'package:adrop/components/a_drop_icon.dart';
import 'package:adrop/cross.dart';
import 'package:adrop/src/rust/api/init.dart';
import 'package:flutter/material.dart';

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  _InitScreenState createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        return Center(
          child: SizedBox(
            width: constraints.maxWidth / 2,
            height: constraints.maxHeight / 2,
            child: const Center(
              child: ADropIcon(),
            ),
          ),
        );
      }),
    );
  }

  Future<dynamic> _init() async {
    var root = await cross.root();
    initPath(localPath: root);
  }
}
