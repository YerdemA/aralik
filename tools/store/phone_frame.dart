// Shared by the store and video captures: a Pixel 6 sized phone (1080 ×
// 2400) with a clean status bar (09:00) and the gesture bar, the real
// Roboto font, and sample stats of a regular player.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aralik/core/scoring.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/question.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pixel 6: 1080 × 2400 at 420 dpi.
const _physical = Size(1080, 2400);
const _ratio = 2.625;
const _statusBar = 44.0; // with the camera cutout
const _gestureBar = 24.0;

final _boundary = GlobalKey();

Directory _materialFonts() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    final fonts = Directory('${dir.path}/bin/cache/artifacts/material_fonts');
    if (fonts.existsSync()) return fonts;
    if (dir.parent.path == dir.path) throw StateError('fonts not found');
    dir = dir.parent;
  }
}

/// Roboto and the Material icons, as on the phone (call in runAsync).
Future<void> loadPhoneFonts() async {
  final dir = _materialFonts().path;
  ByteData read(String file) =>
      ByteData.sublistView(File('$dir/$file').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final f in ['regular', 'medium', 'bold', 'black']) {
    roboto.addFont(Future.value(read('roboto-$f.ttf')));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(read('materialicons-regular.otf')))).load();
  // Emoji, as the phone draws them (Windows' colour emoji font).
  final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
  if (emoji.existsSync()) {
    await (FontLoader(
          'Emoji',
        )..addFont(Future.value(ByteData.sublistView(emoji.readAsBytesSync()))))
        .load();
  }
}

ThemeData _withRoboto(ThemeData t) => t.copyWith(
  textTheme: t.textTheme.apply(
    fontFamily: 'Roboto',
    fontFamilyFallback: const ['Emoji'],
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: t.filledButtonTheme.style?.copyWith(
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: (t.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: (t.textButtonTheme.style ?? const ButtonStyle()).copyWith(
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
      ),
    ),
  ),
);

/// The phone around the app: a clean status bar and the gesture handle,
/// drawn over the app the way Android draws them edge to edge.
class _Phone extends StatelessWidget {
  const _Phone({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? const Color(0xFFE6E1E9) : const Color(0xFF1D1B20);
    return RepaintBoundary(
      key: _boundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _statusBar,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        '09:00',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: ink,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.network_wifi_rounded, size: 16, color: ink),
                      const SizedBox(width: 4),
                      Icon(Icons.battery_full_rounded, size: 16, color: ink),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 108,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: .75),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [home] in the app's theme inside the phone.
Widget phoneApp(Widget home, {bool dark = false}) => _Phone(
  dark: dark,
  child: MaterialApp(
    key: UniqueKey(),
    debugShowCheckedModeBanner: false,
    theme: _withRoboto(AppTheme.light),
    darkTheme: _withRoboto(AppTheme.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: home,
  ),
);

/// Writes the phone as it is now to [out]/[name].png.
Future<void> snapPhone(WidgetTester tester, Directory out, String name) async {
  final render =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: _ratio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('  ${out.path}/$name.png');
}

/// Sizes the test view like the phone, insets included.
void phoneView(WidgetTester tester) {
  tester.view.physicalSize = _physical;
  tester.view.devicePixelRatio = _ratio;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar * _ratio,
    bottom: _gestureBar * _ratio,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
}

/// Fourteen finished days before today (a 14-day streak), ~89 %
/// calibration, the last day 340 points.
Future<StatsStore> seededStats(List<Question> bank, int today) async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final stats = StatsStore(await SharedPreferences.getInstance());
  final random = math.Random(7);
  const lastDay = [92, 81, -12, 79, 100]; // 340
  var q = 0;
  for (var day = today - 14; day < today; day++) {
    for (var i = 0; i < 5; i++) {
      final question = bank[(q++ * 37) % bank.length];
      final miss = random.nextInt(9) == 0;
      final points = day == today - 1
          ? lastDay[i]
          : miss
          ? random.nextInt(40) - 30
          : 45 + random.nextInt(50);
      final hit = day == today - 1 ? points >= 0 : !miss;
      await stats.recordAnswer(
        questionId: question.id,
        category: question.category,
        outcome: hit ? Outcome.hit : Outcome.tooHigh,
        dailyDay: day,
        points: points,
      );
    }
  }
  return stats;
}

/// The first question whose text starts with [start].
Question questionStarting(List<Question> bank, String start) =>
    bank.firstWhere((q) => q.text.startsWith(start));
