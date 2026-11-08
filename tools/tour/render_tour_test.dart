// Renders the first-launch tour's home steps into build/tour/ with the
// real Roboto font, to look at it:
//
//   flutter test tools/tour/render_tour_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Directory _materialFonts() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    final fonts = Directory('${dir.path}/bin/cache/artifacts/material_fonts');
    if (fonts.existsSync()) return fonts;
    if (dir.parent.path == dir.path) throw StateError('fonts not found');
    dir = dir.parent;
  }
}

Future<void> _loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final f in ['regular', 'medium', 'bold', 'black']) {
    final bytes = File('${_materialFonts().path}/roboto-$f.ttf')
        .readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('${_materialFonts().path}/materialicons-regular.otf')
              .readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

ThemeData _withRoboto(ThemeData t) => t.copyWith(
  textTheme: t.textTheme.apply(fontFamily: 'Roboto'),
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

void main() {
  testWidgets('render tour', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadRoboto);
    final out = Directory('build/tour')..createSync(recursive: true);
    final boundary = GlobalKey();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'duel_name': 'Ayşe'});
    final prefs = await SharedPreferences.getInstance();
    // ignore: invalid_use_of_visible_for_testing_member
    HomeScreen.updateOffered = true;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _withRoboto(AppTheme.light),
          home: HomeScreen(
            repository: QuestionRepository(),
            stats: StatsStore(prefs),
            settings: SettingsStore(prefs),
            leaderboard: LeaderboardStore(
              prefs,
              serviceUri: () => Uri.parse('https://lb.example/'),
              deviceKey: () async => null,
            ),
          ),
        ),
      ),
    );
    Future<void> snap(String name) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 3);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    await tester.pump(const Duration(milliseconds: 600));
    for (var step = 1; step <= 9; step++) {
      await snap('adim-$step');
      final next = find.text(
        step == 9 ? AppStrings.tourDone : AppStrings.tourNext,
      );
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
    }
  });
}
