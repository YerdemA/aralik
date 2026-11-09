// Renders the app icon to PNG files. Not part of the app or the test suite.
//
//   flutter test tools/icon/render_icon_test.dart
//
// Writes the Android launcher icons (legacy, round, adaptive layers and the
// Android 13 monochrome layer) into android/app/src/main/res/, a 512 px
// Play Store icon into docs/store/icon-512.png and the iOS icon (one
// 1024 px PNG without an alpha channel, which the App Store refuses; iOS
// rounds the corners itself) into ios/Runner/Assets.xcassets/AppIcon.appiconset/.
//
// Design: the Kabaca mascot (lib/widgets/philosopher.dart), a thinking
// philosopher with a "?" thought bubble, on the app's navy.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:aralik/widgets/philosopher.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// Legacy launcher icon size (48 dp) and adaptive layer size (108 dp) per density.
const _densities = {
  'mdpi': (48, 108),
  'hdpi': (72, 162),
  'xhdpi': (96, 216),
  'xxhdpi': (144, 324),
  'xxxhdpi': (192, 432),
};

const _navyTop = Color(0xFF34477D);
const _navyBottom = Color(0xFF22305A);

/// The design uses a unit square for the visible icon: Android shows at
/// least the central 72 of the 108 dp adaptive canvas (1024 px grid).
void _toDesignUnits(Canvas canvas) {
  canvas.translate(512, 512);
  canvas.scale(1024 * 72 / 108);
  canvas.translate(-0.5, -0.5);
}

void paintBackground(Canvas canvas) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1024, 1024),
    Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, 1024), [
        _navyTop,
        _navyBottom,
      ]),
  );
}

/// The mascot from lib/widgets/philosopher.dart, shared with the share card.
void paintForeground(Canvas canvas, {bool monochrome = false}) {
  canvas.saveLayer(const Rect.fromLTWH(0, 0, 1024, 1024), Paint());
  canvas.save();
  _toDesignUnits(canvas);
  Philosopher(monochrome: monochrome).paintScene(canvas);
  canvas.restore();
  canvas.restore();
}

enum _Layer {
  background,
  foreground,
  monochrome,
  monoPreview,
  full,
  round,
  store,
}

Future<void> _render(
  _Layer layer,
  int size,
  String path, {
  bool opaque = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(size / 1024);

  switch (layer) {
    case _Layer.background:
      paintBackground(canvas);
    case _Layer.foreground:
      paintForeground(canvas);
    case _Layer.monochrome:
      paintForeground(canvas, monochrome: true);
    case _Layer.monoPreview:
      // How Android 13 themed icons tint the monochrome layer.
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        Paint()..color = const Color(0xFFD6E3FF),
      );
      canvas.saveLayer(const Rect.fromLTWH(0, 0, 1024, 1024), Paint());
      paintForeground(canvas, monochrome: true);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        Paint()
          ..color = const Color(0xFF1B3A6B)
          ..blendMode = BlendMode.srcIn,
      );
      canvas.restore();
    case _Layer.full || _Layer.round || _Layer.store:
      // Legacy icons show what the adaptive mask shows: the central 72 of
      // 108 dp.
      const zoom = 108 / 72;
      final clip = layer == _Layer.round
          ? (Path()..addOval(const Rect.fromLTWH(0, 0, 1024, 1024)))
          : (Path()..addRRect(
              RRect.fromLTRBR(0, 0, 1024, 1024, const Radius.circular(180)),
            ));
      if (layer != _Layer.store) canvas.clipPath(clip);
      canvas.translate(512, 512);
      canvas.scale(zoom);
      canvas.translate(-512, -512);
      paintBackground(canvas);
      paintForeground(canvas);
  }

  final image = await recorder.endRecording().toImage(size, size);
  final file = File(path)..createSync(recursive: true);
  if (opaque) {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    file.writeAsBytesSync(_rgbPng(rgba!.buffer.asUint8List(), size, size));
    return;
  }
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  file.writeAsBytesSync(png!.buffer.asUint8List());
}

/// A PNG of [rgba] without its alpha channel (colour type 2, 8 bit).
List<int> _rgbPng(List<int> rgba, int width, int height) {
  final raw = <int>[];
  for (var y = 0; y < height; y++) {
    raw.add(0); // filter: none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw.addAll([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  List<int> u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];
  List<int> chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    return [...u32(data.length), ...body, ...u32(_crc32(body))];
  }

  return [
    137, 80, 78, 71, 13, 10, 26, 10, // signature
    ...chunk('IHDR', [...u32(width), ...u32(height), 8, 2, 0, 0, 0]),
    ...chunk('IDAT', ZLibCodec(level: 9).encode(raw)),
    ...chunk('IEND', const []),
  ];
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

const _iosIcons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

void main() {
  test('render launcher icons', () async {
    for (final MapEntry(key: density, value: (legacy, adaptive))
        in _densities.entries) {
      final dir = '$_res/mipmap-$density';
      await _render(_Layer.full, legacy, '$dir/ic_launcher.png');
      await _render(_Layer.round, legacy, '$dir/ic_launcher_round.png');
      await _render(
        _Layer.background,
        adaptive,
        '$dir/ic_launcher_background.png',
      );
      await _render(
        _Layer.foreground,
        adaptive,
        '$dir/ic_launcher_foreground.png',
      );
      await _render(
        _Layer.monochrome,
        adaptive,
        '$dir/ic_launcher_monochrome.png',
      );
    }
    File('$_res/mipmap-anydpi-v26/ic_launcher.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync(_adaptiveXml);
    File('$_res/mipmap-anydpi-v26/ic_launcher_round.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync(_adaptiveXml);
    await _render(_Layer.store, 512, 'docs/store/icon-512.png');
    // iOS: one full-bleed square; Xcode makes the smaller sizes.
    final iosDir = Directory(_iosIcons)..createSync(recursive: true);
    for (final old in iosDir.listSync().whereType<File>()) {
      if (old.path.endsWith('.png')) old.deleteSync();
    }
    await _render(
      _Layer.store,
      1024,
      '$_iosIcons/Icon-App-1024x1024@1x.png',
      opaque: true,
    );
    File('$_iosIcons/Contents.json').writeAsStringSync(_iosContents);
    // Large previews for review (not shipped).
    await _render(_Layer.full, 1024, 'build/icon_preview/full.png');
    await _render(_Layer.round, 256, 'build/icon_preview/round-256.png');
    await _render(_Layer.full, 96, 'build/icon_preview/full-96.png');
    await _render(_Layer.monoPreview, 432, 'build/icon_preview/mono-432.png');
  });
}

const _iosContents = '''{
  "images" : [
    {
      "filename" : "Icon-App-1024x1024@1x.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''';

const _adaptiveXml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''';
