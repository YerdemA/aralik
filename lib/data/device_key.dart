import 'package:flutter/services.dart';

/// This device's key for the leaderboard: a SHA-256 (hex) of Android's
/// per-app device id (`Settings.Secure.ANDROID_ID`), made in
/// MainActivity.kt. It stays the same when the app is reinstalled or its
/// data is cleared, so the server can keep one account per device; the id
/// itself never leaves the phone. Null when it is not available.
Future<String?> deviceKey() async {
  try {
    final key = await _channel.invokeMethod<String>('deviceKey');
    return key != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(key) ? key : null;
  } on Object {
    return null;
  }
}

const _channel = MethodChannel('com.yerdema.kabaca/device');
