import 'package:flutter/services.dart';

/// Opens Kabaca's page in the store: the Play Store app (or the browser
/// without it) on Android, the App Store on iOS, which needs the app's
/// [appStoreId]. A small channel to MainActivity.kt / AppDelegate.swift,
/// so no package is needed. Returns false when nothing could open it.
Future<bool> openStorePage({String? appStoreId}) async {
  try {
    return await _channel.invokeMethod<bool>('openStore', {
          'appStoreId': appStoreId,
        }) ??
        false;
  } on Object {
    return false;
  }
}

const _channel = MethodChannel('com.yerdema.kabaca/store');
