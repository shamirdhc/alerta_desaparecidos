// Implementación para navegadores web utilizando dart:js_interop

import 'dart:js_interop';

@JS('window.isPWAInstalled')
external JSBoolean _isPWAInstalled();

@JS('window.canPromptPWAInstall')
external JSBoolean _canPromptPWAInstall();

@JS('window.isIOSDevice')
external JSBoolean _isIOSDevice();

@JS('window.triggerPWAInstallPrompt')
external JSPromise<JSBoolean> _triggerPWAInstallPrompt();

bool platformIsPWAInstalled() {
  try {
    return _isPWAInstalled().toDart;
  } catch (_) {
    return false;
  }
}

bool platformCanPromptPWAInstall() {
  try {
    return _canPromptPWAInstall().toDart;
  } catch (_) {
    return false;
  }
}

bool platformIsIOSDevice() {
  try {
    return _isIOSDevice().toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> platformTriggerPWAInstallPrompt() async {
  try {
    final promise = _triggerPWAInstallPrompt();
    final jsBool = await promise.toDart;
    return jsBool.toDart;
  } catch (_) {
    return false;
  }
}
