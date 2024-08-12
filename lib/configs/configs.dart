import 'package:flutter/material.dart';

import '../src/rust/api/property.dart' as rustProperty;

abstract class Config<T> {
  T _value;

  Config._(this._value);

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

  BoolConfig._(this._name, this._defaultValue) : super._(false);

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
final saveToGallery = BoolConfig._('save_to_gallery', false);
final deleteAfterSaveToGallery =
    BoolConfig._('delete_after_save_to_gallery', true);

initConfigs() async {
  await zipOnSend._init();
  await saveToGallery._init();
  await deleteAfterSaveToGallery._init();
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
