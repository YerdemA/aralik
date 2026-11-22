// Shared by the store and video captures: a Pixel 6 sized phone (1080 ×
// 2400) with a clean status bar (09:00) and the gesture bar, the real
// Roboto font, and sample stats of a regular player.
//
// With `--dart-define=phone=iphone` the phone is an iPhone 16 Pro Max
// (1320 × 2868, the App Store's 6.9" size): iOS status bar (9:41, Dynamic
// Island) and home indicator, no Android chrome (App Store rule 2.3.10).
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

/// True when drawing the App Store's iPhone instead of the Pixel.
const isIphone = String.fromEnvironment('phone') == 'iphone';

/// Pixel 6: 1080 × 2400 at 420 dpi. iPhone 16 Pro Max: 1320 × 2868 at @3x.
const _physical = isIphone ? Size(1320, 2868) : Size(1080, 2400);
const _ratio = isIphone ? 3.0 : 2.625;
const _statusBar = isIphone ? 62.0 : 44.0; // with the camera cutout / island
const _gestureBar = isIphone ? 34.0 : 24.0;

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
  // On the iPhone, Material lays out as it does on iOS (centred titles,
  // chevron back button).
  platform: isIphone ? TargetPlatform.iOS : TargetPlatform.android,
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

/// The phone around the app: a clean status bar and the gesture handle (or
/// the home indicator), drawn over the app edge to edge.
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
            if (isIphone) ..._iosChrome(ink) else ..._androidChrome(ink),
          ],
        ),
      ),
    );
  }
}

/// Android's status bar and gesture handle.
List<Widget> _androidChrome(Color ink) => [
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
];

/// iOS's status bar (9:41 beside the Dynamic Island, signal, Wi-Fi and a
/// full battery, drawn) and the home indicator.
List<Widget> _iosChrome(Color ink) => [
  Positioned(
    top: 0,
    left: 0,
    right: 0,
    height: 54,
    child: IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            width: 150,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                '9:41',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
          ),
          Positioned(
            top: 11,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 126,
                height: 37,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            width: 150,
            top: 0,
            bottom: 0,
            child: Center(
              child: CustomPaint(
                size: const Size(78, 13),
                painter: _IosStatusIcons(ink),
              ),
            ),
          ),
        ],
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
          width: 144,
          height: 5,
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    ),
  ),
];

/// Signal bars, the Wi-Fi fan and the battery, in a 78 × 13 box.
class _IosStatusIcons extends CustomPainter {
  const _IosStatusIcons(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = ink;
    // Signal: four bars, rising.
    for (var i = 0; i < 4; i++) {
      final h = 4.0 + i * 3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 4.5, size.height - h, 3, h),
          const Radius.circular(1),
        ),
        fill,
      );
    }
    // Wi-Fi: three arcs and a dot, fanning up from one point.
    final centre = Offset(28.5, size.height);
    final arc = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final r in [5.5, 9.0, 12.5]) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: r),
        math.pi * 1.25,
        math.pi * .5,
        false,
        arc,
      );
    }
    canvas.drawCircle(centre.translate(0, -1.5), 1.6, fill);
    // Battery: outline, full charge and the cap.
    const body = Rect.fromLTWH(46, .5, 25, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(3.5)),
      Paint()
        ..color = ink.withValues(alpha: .4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.deflate(2), const Radius.circular(2)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(72.5, 4.5, 1.5, 4),
        const Radius.circular(1),
      ),
      Paint()..color = ink.withValues(alpha: .4),
    );
  }

  @override
  bool shouldRepaint(_IosStatusIcons old) => old.ink != ink;
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
