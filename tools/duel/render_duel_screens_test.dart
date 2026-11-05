// Renders the duel's reveal and end screens, and the home screen with its
// duel card, with the real Roboto font into build/duel_screens/, to look
// at the design:
//
//   flutter test tools/duel/render_duel_screens_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aralik/core/daily.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/features/duel/duel_screen.dart';
import 'package:aralik/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Channel implements DuelChannel {
  final incoming = StreamController<String>();

  @override
  Stream<String> get messages => incoming.stream;

  @override
  void send(String message) {}

  @override
  Future<void> close() async {}
}

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
  textButtonTheme: TextButtonThemeData(
    style: (t.textButtonTheme.style ?? const ButtonStyle()).copyWith(
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
      ),
    ),
  ),
);

/// Each case: the theme, the player's and the opponent's points per
/// question (hit when ≥ 0 here), and the end's winner seat.
final _cases = {
  'kazandi': (AppTheme.light, [92, 75, 40, -50, 81], [55, -50, -20, 10, 30]),
  'kaybetti-koyu': (AppTheme.dark, [20, -50, 64, 5, -30], [88, 70, 95, 61, 40]),
  'berabere': (AppTheme.light, [50, 50, 50, 50, 50], [70, 30, 50, 60, 40]),
};

void main() {
  testWidgets('render duel screens', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadRoboto);
    // A test under tools/, not test/: the analyzer does not see it as one.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final repository = QuestionRepository();
    final bank = (await tester.runAsync(repository.load))!;
    final questions = bank.take(5).toList();
    final out = Directory('build/duel_screens')..createSync(recursive: true);
    final boundary = GlobalKey();

    Future<void> snap(String name) async {
      await tester.pump(const Duration(seconds: 1));
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 3);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    for (final MapEntry(key: name, value: (theme, me, them))
        in _cases.entries) {
      final channel = _Channel();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            key: UniqueKey(),
            debugShowCheckedModeBanner: false,
            theme: _withRoboto(theme),
            home: DuelScreen(
              service: DuelService(
                serviceUri: () => Uri.parse('https://lb.example/'),
                connect: (_) async => channel,
              ),
              repository: repository,
              stats: stats,
              code: 'K7M2P',
              name: 'Ayşe',
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      void say(Map<String, Object?> m) => channel.incoming.add(jsonEncode(m));
      say({
        't': 'start',
        'you': 0,
        'names': ['Ayşe', 'Bora'],
        'questions': [for (final q in questions) q.id],
        'questionMs': 15000,
      });
      var totals = [0, 0];
      for (var i = 0; i < 5; i++) {
        final q = questions[i];
        Map<String, Object?> result(int points) {
          final a = q.answer.round();
          final hit = points >= 0;
          final low = hit ? (a * 0.8).round() : (a * 1.4).round();
          final high = hit ? (a * 1.25).round() : (a * 2).round();
          return {'low': low, 'high': high, 'points': points, 'hit': hit};
        }

        totals = [totals[0] + me[i], totals[1] + them[i]];
        say({'t': 'question', 'i': i, 'ms': 15000});
        await tester.pump();
        say({
          't': 'reveal',
          'i': i,
          'results': [result(me[i]), result(them[i])],
          'totals': totals,
        });
        await tester.pump();
        if (i == 0) await snap('$name-soru');
      }
      final winner = totals[0] == totals[1]
          ? null
          : totals[0] > totals[1]
          ? 0
          : 1;
      say({'t': 'end', 'totals': totals, 'winner': winner, 'reason': 'done'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Sonucu gör'));
      await tester.pump();
      await snap('$name-sonuc');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('render home', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadRoboto);
    final out = Directory('build/duel_screens')..createSync(recursive: true);
    final today = dayIndexFor(DateTime.now());
    final boundary = GlobalKey();
    for (final (name, finished) in [
      ('ana-ekran', false),
      ('ana-ekran-bitti', true),
    ]) {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({
        if (finished) ...{
          'daily_results_$today': ['92:1', '75:1', '-50:0', '40:1', '81:1'],
          'completed_days': ['$today'],
        },
      });
      final prefs = await SharedPreferences.getInstance();
      // ignore: invalid_use_of_visible_for_testing_member
      HomeScreen.updateOffered = true;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            key: UniqueKey(),
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
      await tester.pump(const Duration(seconds: 2));
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 3);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });
}
