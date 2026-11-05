import 'package:flutter/services.dart';

/// Opens Kabaca's page in the Play Store app (or in the browser without
/// it). A small channel to MainActivity.kt, so no package is needed.
/// Returns false when nothing could open it.
Future<bool> openStorePage() async {
  try {
    return await _channel.invokeMethod<bool>('openStore') ?? false;
  } on Object {
    return false;
  }
}

const _channel = MethodChannel('com.yerdema.kabaca/store');
