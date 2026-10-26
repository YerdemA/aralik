import 'dart:typed_data';

import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/features/result/share_card.dart';
import 'package:aralik/features/result/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _card = ShareCardData(
  dayIndex: 41,
  results: [
    (points: 93, hit: true),
    (points: 75, hit: true),
    (points: 40, hit: true),
    (points: -20, hit: false),
    (points: 72, hit: true),
  ],
  hits: 40,
  answered: 50,
);

/// Width and height from a PNG's IHDR chunk.
(int, int) pngSize(Uint8List png) {
  final data = ByteData.sublistView(png);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  testWidgets('renders a 1080 × 1920 PNG story card', (tester) async {
    final png = await tester.runAsync(() => renderShareCard(_card));
    expect(png!.sublist(1, 4), 'PNG'.codeUnits);
    expect(pngSize(png), (1080, 1920));
  });

  testWidgets('also renders before the first day and without calibration', (
    tester,
  ) async {
    final png = await tester.runAsync(
      () => renderShareCard(
        const ShareCardData(
          dayIndex: -3,
          results: [(points: -100, hit: false)],
          hits: 0,
          answered: 1,
        ),
      ),
    );
    expect(pngSize(png!), (1080, 1920));
  });

  testWidgets('the share sheet offers the image and the text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ShareSheet(card: _card, render: (_) async => _transparentPng),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.shareImage), findsOneWidget);
    expect(find.text(AppStrings.shareTextOnly), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a daily summary opens the share sheet', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SummaryScreen(
          results: _card.results,
          hits: 40,
          answered: 50,
          dayIndex: 41,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text(AppStrings.share));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ShareSheet), findsOneWidget);
    expect(find.text(AppStrings.shareTextOnly), findsOneWidget);
  });
}

/// A 1 × 1 transparent PNG.
final _transparentPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
