import 'package:flutter/services.dart';

/// Saves a PNG to the phone's gallery (Pictures/Kabaca) through a small
/// channel to MainActivity.kt; no package. False when it could not: before
/// Android 10 (it would need a storage permission) and on iOS, where the
/// share sheet's "Save Image" does it instead.
Future<bool> saveImageToGallery(Uint8List png, String name) async {
  try {
    return await _channel.invokeMethod<bool>('saveImage', {
          'bytes': png,
          'name': name,
        }) ??
        false;
  } on Object {
    return false;
  }
}

const _channel = MethodChannel('com.yerdema.kabaca/gallery');
