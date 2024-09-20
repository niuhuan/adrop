import 'dart:io';

import 'package:adrop/cross.dart';

bool _screenKeepOn = false;

Future _setKeepScreenOn(bool keepScreenOn) async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    return;
  }
  if (_screenKeepOn == keepScreenOn) {
    return;
  }
  _screenKeepOn = keepScreenOn;
  return cross.setKeepScreenOn(keepScreenOn);
}

bool _keepScreenUpOnSending = false;
bool _keepScreenUpOnReceiving = false;

Future setKeepScreenUpOnSending(bool keepScreenUpOnSending) async {
  if (_keepScreenUpOnSending == keepScreenUpOnSending) {
    return;
  }
  _keepScreenUpOnSending = keepScreenUpOnSending;
  await _setKeepScreenOn(_keepScreenUpOnSending || _keepScreenUpOnReceiving);
}

Future setKeepScreenUpOnReceiving(bool keepScreenUpOnReceiving) async {
  if (_keepScreenUpOnReceiving == keepScreenUpOnReceiving) {
    return;
  }
  _keepScreenUpOnReceiving = keepScreenUpOnReceiving;
  await _setKeepScreenOn(_keepScreenUpOnSending || _keepScreenUpOnReceiving);
}
