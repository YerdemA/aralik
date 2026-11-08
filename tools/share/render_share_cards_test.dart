// Renders one daily share card per mood (and two free-play rounds) into build/share_cards/ with the
// real Roboto font, to look at the design:
//
//   flutter test tools/share/render_share_cards_test.dart
import 'dart:io';

import 'package:aralik/features/result/share_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Directory _materialFonts() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    final fonts = Directory('${dir.path}/bin/cache/artifacts/material_fonts');
    if (fonts.existsSync()) return fonts;
    if (dir.parent.path == dir.path) {
      throw StateError('Flutter fonts not found');
    }
    dir = dir.parent;
  }
}

Future<void> _loadRoboto() async {
  final fonts = _materialFonts().path;
  final loader = FontLoader('Roboto');
  for (final f in ['regular', 'medium', 'bold', 'black']) {
    final bytes = File('$fonts/roboto-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// One example day per mood, best first.
const _days = {
  'efsane': [100, 98, 95, 97, 93],
  'harika': [92, 85, 61, 88, 74],
  'fena-degil': [90, 75, 40, -20, 72],
  'idare-eder': [60, -50, 35, 12, 48],
  'olmadi': [-50, 20, -50, -38, 10],
};

void main() {
  testWidgets('render share cards', (tester) async {
    await tester.runAsync(() async {
      await _loadRoboto();
      final out = Directory('build/share_cards')..createSync(recursive: true);
      for (final MapEntry(key: name, value: points) in _days.entries) {
        final png = await renderShareCard(
          ShareCardData(
            dayIndex: 3,
            results: [for (final p in points) (points: p, hit: p >= 40)],
            hits: 41,
            answered: 50,
          ),
        );
        File('${out.path}/$name.png').writeAsBytesSync(png);
      }
      // Free-play rounds ("Bir tur at"): no day, and a short one.
      for (final (name, points) in [
        ('tur-harika', [92, 85, 61, 88, 74]),
        ('tur-olmadi', [-50, 20, -50]),
      ]) {
        final png = await renderShareCard(
          ShareCardData(
            results: [for (final p in points) (points: p, hit: p >= 40)],
            hits: 41,
            answered: 50,
          ),
        );
        File('${out.path}/$name.png').writeAsBytesSync(png);
      }
    });
  });
}
