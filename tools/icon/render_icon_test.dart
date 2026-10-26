// Renders the app icon to PNG files. Not part of the app or the test suite.
//
//   flutter test tools/icon/render_icon_test.dart
//
// Writes the Android launcher icons (legacy, round, adaptive layers and the
// Android 13 monochrome layer) into android/app/src/main/res/ and a 512 px
// Play Store icon into docs/store/icon-512.png.
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

Future<void> _render(_Layer layer, int size, String path) async {
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
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(png!.buffer.asUint8List());
}

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
    // Large previews for review (not shipped).
    await _render(_Layer.full, 1024, 'build/icon_preview/full.png');
    await _render(_Layer.round, 256, 'build/icon_preview/round-256.png');
    await _render(_Layer.full, 96, 'build/icon_preview/full-96.png');
    await _render(_Layer.monoPreview, 432, 'build/icon_preview/mono-432.png');
  });
}

const _adaptiveXml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''';
