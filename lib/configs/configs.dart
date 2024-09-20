import 'package:adrop/configs/screen_keep_on.dart';
import 'package:flutter/material.dart';

import '../src/rust/api/property.dart' as rustProperty;

abstract class Config<T> {
  T _value;

  Function? callback;

  Config._(this._value, {this.callback});

  String propertyName();

  T parse(String value);

  String serialize(T value);

  get value => _value;

  Future<void> setValue(T value) async {
    await rustProperty.setProperty(
      key: propertyName(),
      value: serialize(value),
    );
    _value = value;
    callback?.call();
  }

  _init() async {
    _value = parse(
      await rustProperty.getProperty(key: propertyName()),
    );
  }
}

class BoolConfig extends Config<bool> {
  final String _name;
  final bool _defaultValue;

  BoolConfig._(this._name, this._defaultValue, {super.callback})
      : super._(false);

  @override
  String propertyName() => _name;

  @override
  bool parse(String value) {
    if (value == '') {
      return _defaultValue;
    }
    return value == 'true';
  }

  @override
  String serialize(bool value) {
    return value.toString();
  }
}

final zipOnSend = BoolConfig._('zip_on_send', false);
final zipOnSendRename = BoolConfig._('zip_on_send_rename', false);
final saveToGallery = BoolConfig._('save_to_gallery', false);
final deleteAfterSaveToGallery =
    BoolConfig._('delete_after_save_to_gallery', true);

final keepScreenUpOnSending = BoolConfig._(
  'keep_screen_up_on_sending',
  true,
  callback: () {
    setKeepScreenUpOnSending(false);
  },
);
final keepScreenUpOnReceiving = BoolConfig._(
  'keep_screen_up_on_receiving',
  true,
  callback: () {
    setKeepScreenUpOnReceiving(false);
  },
);

initConfigs() async {
  await zipOnSend._init();
  await zipOnSendRename._init();
  await saveToGallery._init();
  await deleteAfterSaveToGallery._init();
  await keepScreenUpOnSending._init();
  await keepScreenUpOnReceiving._init();
}

Widget _propertySwitchListTile(
  Config<bool> config,
  String title,
  IconData iconTrue,
  IconData iconFalse, {
  Widget? subtitle,
}) {
  return StatefulBuilder(
    builder: (BuildContext context, void Function(void Function()) setState) {
      return SwitchListTile(
        title: Text(title),
        subtitle: subtitle,
        value: config.value,
        onChanged: (bool value) async {
          await config.setValue(value);
          setState(() {});
        },
        secondary: Icon(
          config.value ? iconTrue : iconFalse,
        ),
      );
    },
  );
}

Widget zipOnSendSwitchListTile() {
  return _propertySwitchListTile(
    zipOnSend,
    '发送文件前压缩',
    Icons.folder_zip,
    Icons.folder_zip_outlined,
  );
}

Widget zipOnSendRenameSwitchListTile() {
  return _propertySwitchListTile(
    zipOnSendRename,
    '压缩文件时进行命名',
    Icons.abc,
    Icons.abc_outlined,
  );
}

Widget saveToGallerySwitchListTile() {
  return _propertySwitchListTile(
    saveToGallery,
    '下载成功后将媒体保存到相册',
    Icons.add_photo_alternate_rounded,
    Icons.add_photo_alternate_outlined,
    subtitle: const Text("目前仅支持图片, 且会重新编码为PNG"),
  );
}

Widget deleteAfterSaveToGallerySwitchListTile() {
  return _propertySwitchListTile(
    deleteAfterSaveToGallery,
    '保存到相册后删除原文件',
    Icons.delete_rounded,
    Icons.delete_outline,
  );
}

Widget keepScreenUpOnSendingSwitchListTile() {
  return _propertySwitchListTile(
    keepScreenUpOnSending,
    '发送文件时保持屏幕常亮',
    Icons.screen_lock_portrait_rounded,
    Icons.screen_lock_portrait_outlined,
  );
}

Widget keepScreenUpOnReceivingSwitchListTile() {
  return _propertySwitchListTile(
    keepScreenUpOnReceiving,
    '接收文件时保持屏幕常亮',
    Icons.screen_lock_portrait_rounded,
    Icons.screen_lock_portrait_outlined,
  );
}
