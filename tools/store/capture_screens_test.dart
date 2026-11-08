// Draws the raw store screenshots from the real screens, with sample data,
// into play-store/screenshots/ (not in git): 1080 × 2400 like a Pixel 6,
// with a clean status bar (09:00) and the gesture bar. Then
// render_store_test.dart frames them for Google Play.
//
//   flutter test tools/store/capture_screens_test.dart
//   flutter test tools/store/render_store_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aralik/features/tournament/tournament_screen.dart';
import 'package:aralik/features/math/math_mode_screen.dart';
import 'package:aralik/data/tournament_client.dart';
import 'package:aralik/core/question_timer.dart';
import 'package:aralik/core/math/math_question.dart';
import 'package:aralik/core/math/math_problem.dart';
import 'package:aralik/core/answer_scale.dart';
import 'package:aralik/core/daily.dart';
import 'package:aralik/core/scoring.dart';
import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/question.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/features/duel/duel_screen.dart';
import 'package:aralik/features/game/game_screen.dart';
import 'package:aralik/features/home/home_screen.dart';
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

final _out = Directory('play-store/screenshots');
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

Future<void> _loadFonts() async {
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

Widget _app(Widget home, {bool dark = false}) => _Phone(
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

Future<void> _snap(WidgetTester tester, String name) async {
  final render =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: _ratio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${_out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('  ${_out.path}/$name.png');
}

void _phoneView(WidgetTester tester) {
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
Future<StatsStore> _seededStats(List<Question> bank, int today) async {
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

Question _byText(List<Question> bank, String start) =>
    bank.firstWhere((q) => q.text.startsWith(start));

class _Channel implements DuelChannel {
  final incoming = StreamController<String>();

  @override
  Stream<String> get messages => incoming.stream;

  @override
  void send(String message) {}

  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() => _out.createSync(recursive: true));

  testWidgets('capture store screens', (tester) async {
    _phoneView(tester);
    await tester.runAsync(_loadFonts);
    final repository = QuestionRepository();
    final bank = (await tester.runAsync(repository.load))!;
    final today = dayIndexFor(DateTime.now());
    final stats = await _seededStats(bank, today);
    final prefs = await SharedPreferences.getInstance();
    // ignore: invalid_use_of_visible_for_testing_member
    HomeScreen.updateOffered = true;

    Widget home() => HomeScreen(
      repository: repository,
      stats: stats,
      settings: SettingsStore(prefs),
      leaderboard: LeaderboardStore(
        prefs,
        serviceUri: () => Uri.parse('https://lb.example/'),
        deviceKey: () async => null,
      ),
    );

    // 01 Home (the seeded stats make this a player from before the
    // first-launch tour: it is not shown).
    await tester.pumpWidget(_app(home()));
    await tester.pump(const Duration(seconds: 2));
    await _snap(tester, '01-ana-ekran');

    // 02 Guess, 03 interval, 04 result: a daily question with its clock.
    final agri = _byText(bank, 'Ağrı Dağı');
    final shown = DateTime(2026, 11, 7, 9);
    var clock = shown.add(const Duration(seconds: 4));
    await tester.pumpWidget(
      _app(
        GameScreen(
          // The third question of the day: "Soru 3 / 5".
          questions: [agri, bank[1], bank[2]],
          alreadyAnswered: 2,
          startQuestion: (_) => shown,
          now: () => clock,
        ),
      ),
    );
    await tester.pump();
    for (final key in ['4', '5', '0', '0']) {
      await tester.tap(find.text(key).last);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(AppStrings.next));
    await tester.pump(const Duration(milliseconds: 500));
    clock = shown.add(const Duration(seconds: 7));
    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(-115, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await _snap(tester, '02-aralik');

    await tester.tap(find.text(AppStrings.lock));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await _snap(tester, '03-sonuc');

    // 05 A revealed duel question, 06 the podium: real intervals, points
    // by the real rule.
    final duelQuestions = [
      _byText(bank, 'Boğaziçi Üniversitesi'),
      _byText(bank, 'Everest Dağı'),
      _byText(bank, 'Pearl Harbor'),
      _byText(bank, 'İstanbul Boğazı'),
      _byText(bank, 'Galata Kulesi'),
    ];
    // (my low, high), (opponent's low, high) per question.
    const intervals = [
      ((1850, 1880), (1870, 1900)),
      ((8000, 9500), (6000, 12000)),
      ((1938, 1944), (1935, 1950)),
      ((25, 40), (40, 70)),
      ((50, 75), (60, 110)),
    ];
    final channel = _Channel();
    await tester.pumpWidget(
      _app(
        DuelScreen(
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
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    void say(Map<String, Object?> m) => channel.incoming.add(jsonEncode(m));
    say({
      't': 'start',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': [for (final q in duelQuestions) q.id],
      'questionMs': 15000,
    });
    var totals = [0, 0];
    for (var i = 0; i < 5; i++) {
      final q = duelQuestions[i];
      Map<String, Object?> result((int, int) interval) {
        final (low, high) = interval;
        final points = scoreFor(
          kind: q.kind,
          low: low,
          high: high,
          answer: q.answer,
          scale: scaleOf(q),
        );
        final hit = low <= q.answer && q.answer <= high;
        return {'low': low, 'high': high, 'points': points, 'hit': hit};
      }

      final (mine, theirs) = intervals[i];
      final me = result(mine);
      final them = result(theirs);
      totals = [
        totals[0] + (me['points']! as int),
        totals[1] + (them['points']! as int),
      ];
      say({'t': 'question', 'i': i, 'ms': 15000});
      await tester.pump();
      say({
        't': 'reveal',
        'i': i,
        'results': [me, them],
        'totals': totals,
        if (i < 4) 'ms': 12000,
      });
      await tester.pump();
      if (i == 0) {
        await tester.pump(const Duration(seconds: 1));
        await _snap(tester, '04-duello');
      }
    }
    say({
      't': 'end',
      'totals': totals,
      'winner': totals[0] >= totals[1] ? 0 : 1,
      'reason': 'done',
      'rematch': true,
    });
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text(AppStrings.duelSeeResult));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    // 05 The podium, the opponent asking for a rematch.
    say({'t': 'rematch', 'seat': 1});
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await _snap(tester, '05-rovans');

    // 06 Math mode: basic or further on.
    await tester.pumpWidget(_app(const MathModeScreen()));
    await tester.pump(const Duration(seconds: 1));
    await _snap(tester, '06-matematik');

    // 07 A math question (further on) with its interval, 60 s clock.
    final ladder = mathQuestion(generateMath(MathTopic.trigonometry, 1, 2026));
    final mathShown = DateTime(2026, 11, 8, 9);
    var mathClock = mathShown.add(const Duration(seconds: 9));
    await tester.pumpWidget(
      _app(
        GameScreen(
          questions: [ladder, bank[1], bank[2], bank[3]],
          alreadyAnswered: 1,
          startQuestion: (_) => mathShown,
          now: () => mathClock,
          timeLimit: mathTimeLimit,
          scale: mathScaleOf,
          minPoints: mathMinPoints,
        ),
      ),
    );
    await tester.pump();
    final guess = (ladder.answer * 1.08).round().toString();
    for (final key in guess.split('')) {
      await tester.tap(find.text(key).last);
      await tester.pump();
    }
    await tester.tap(find.text(AppStrings.next));
    await tester.pump(const Duration(milliseconds: 500));
    mathClock = mathShown.add(const Duration(seconds: 21));
    await tester.drag(find.byType(Slider), const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await _snap(tester, '07-matematik-soru');

    // 08 A tournament question revealed: five intervals, best first.
    final cupChannel = _Channel();
    void tell(Map<String, Object?> m) => cupChannel.incoming.add(jsonEncode(m));
    const names = ['Ayşe', 'Bora', 'Cem', 'Deniz', 'Ece'];
    final cupQuestion = _byText(bank, 'Galata Kulesi');
    await tester.pumpWidget(
      _app(
        TournamentScreen(
          service: TournamentService(
            serviceUri: () => Uri.parse('https://lb.example/'),
            connect: (_) async => cupChannel,
          ),
          repository: repository,
          stats: stats,
          code: 'K7M2P',
          name: 'Ayşe',
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    final players = [
      for (final (k, n) in names.indexed) {'id': k + 1, 'name': n},
    ];
    tell({'t': 'welcome', 'you': 1});
    tell({
      't': 'room',
      'code': 'K7M2P',
      'host': 1,
      'count': 5,
      'players': players,
      'min': 3,
      'max': 8,
    });
    tell({
      't': 'start',
      'questions': [
        cupQuestion.id,
        for (final q in bank.skip(10).take(4)) q.id,
      ],
      'questionMs': 15000,
      'players': players,
    });
    tell({'t': 'question', 'i': 0, 'ms': 15000});
    await tester.pump(const Duration(milliseconds: 400));
    final a = cupQuestion.answer.round();
    Map<String, Object?> range(int id, int low, int high) {
      final points = scoreFor(
        kind: cupQuestion.kind,
        low: low,
        high: high,
        answer: cupQuestion.answer,
        scale: scaleOf(cupQuestion),
      );
      final hit = low <= cupQuestion.answer && cupQuestion.answer <= high;
      return {'id': id, 'low': low, 'high': high, 'points': points, 'hit': hit};
    }

    tell({
      't': 'reveal',
      'i': 0,
      'results': [
        range(1, a - 5, a + 8),
        range(2, a - 20, a + 25),
        range(3, a + 15, a + 50),
        range(4, a - 30, a + 10),
        range(5, a - 9, a + 12),
      ],
      'ms': 12000,
    });
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await _snap(tester, '08-turnuva');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
