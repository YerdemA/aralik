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
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/features/duel/duel_screen.dart';
import 'package:aralik/features/game/game_screen.dart';
import 'package:aralik/features/home/home_screen.dart';
import 'package:aralik/features/leaderboard/leaderboard_screen.dart';
import 'package:aralik/data/ranked_client.dart';
import 'package:aralik/features/settings/mascot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phone_frame.dart';

import 'package:shared_preferences/shared_preferences.dart';

final _out = Directory('play-store/screenshots');

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
    phoneView(tester);
    await tester.runAsync(loadPhoneFonts);
    final repository = QuestionRepository();
    final bank = (await tester.runAsync(repository.load))!;
    final today = dayIndexFor(DateTime.now());
    final stats = await seededStats(bank, today);
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
    await tester.pumpWidget(phoneApp(home()));
    await tester.pump(const Duration(seconds: 2));
    await snapPhone(tester, _out, '01-ana-ekran');

    // 02 Guess, 03 interval, 04 result: a daily question with its clock.
    final agri = questionStarting(bank, 'Ağrı Dağı');
    final shown = DateTime(2026, 11, 7, 9);
    var clock = shown.add(const Duration(seconds: 4));
    await tester.pumpWidget(
      phoneApp(
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
    await snapPhone(tester, _out, '02-aralik');

    await tester.tap(find.text(AppStrings.lock));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await snapPhone(tester, _out, '03-sonuc');

    // 05 A revealed duel question, 06 the podium: real intervals, points
    // by the real rule.
    final duelQuestions = [
      questionStarting(bank, 'Boğaziçi Üniversitesi'),
      questionStarting(bank, 'Everest Dağı'),
      questionStarting(bank, 'Pearl Harbor'),
      questionStarting(bank, 'İstanbul Boğazı'),
      questionStarting(bank, 'Galata Kulesi'),
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
      phoneApp(
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
      'looks': ['111002024', '014312103'],
      'ranked': true,
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
        // Bora missed by a hair: a sad face from the other side.
        say({'t': 'react', 'seat': 1, 'r': 'sad'});
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        for (var k = 0; k < 4; k++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        await snapPhone(tester, _out, '04-duello');
      }
    }
    say({
      't': 'end',
      'totals': totals,
      'winner': totals[0] >= totals[1] ? 0 : 1,
      'reason': 'done',
      'rematch': true,
    });
    // The monthly rating, a moment after the end.
    say({
      't': 'rated',
      'ratings': [
        {'before': 120, 'after': 138},
        {'before': 131, 'after': 113},
      ],
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
    // The rating has counted up to the new total.
    await tester.pump(const Duration(seconds: 3));
    await snapPhone(tester, _out, '05-rovans');

    // 06 Math mode: basic or further on.
    await tester.pumpWidget(phoneApp(const MathModeScreen()));
    await tester.pump(const Duration(seconds: 1));
    await snapPhone(tester, _out, '06-matematik');

    // 09 The monthly duel ranking, with everyone's mascot.
    await prefs.setString('duel_name', 'Ayşe');
    await prefs.setString('mascot_look', '111002024');
    const rankNames = ['Deniz', 'Bora', 'Ayşe', 'Kerem', 'Cem', 'Ece', 'Gül'];
    const rankLooks = [
      '120131212',
      '014312103',
      '111002024',
      '002240311',
      '010331100',
      '100003020',
      '121110432',
    ];
    Map<String, Object?> rankRow(int i) => {
      'rank': i + 1,
      'nickname': rankNames[i],
      'rating': 386 - i * 23,
      'played': 20 - i,
      'won': 14 - i,
      'drawn': 1,
      'average': 290 - i * 9,
      'hitRate': 81 - i * 2,
      'look': rankLooks[i],
    };
    await tester.pumpWidget(
      phoneApp(
        LeaderboardScreen(
          store: LeaderboardStore(
            prefs,
            serviceUri: () => Uri.parse('https://lb.example/'),
            deviceKey: () async => null,
          ),
          ranked: RankedService(
            serviceUri: () => Uri.parse('https://lb.example/'),
            account: () => (id: 'p3', token: 't', nickname: 'Ayşe'),
            prefs: prefs,
            request: (method, uri, [body]) async => (
              status: 200,
              body: <String, Object?>{
                'month': 202611,
                'current': 202611,
                'mode': 'bank',
                'players': 48,
                'top': [for (var i = 0; i < rankNames.length; i++) rankRow(i)],
                'me': rankRow(2),
              },
            ),
          ),
          settings: SettingsStore(prefs),
          day: today,
          dayDone: true,
          initialTab: LeaderboardTab.duel,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(seconds: 1));
    await snapPhone(tester, _out, '09-siralama');

    // 10 The mascot editor.
    await prefs.setString('mascot_look', '110021212');
    await tester.pumpWidget(
      phoneApp(MascotScreen(settings: SettingsStore(prefs))),
    );
    await tester.pump(const Duration(seconds: 1));
    await snapPhone(tester, _out, '10-maskot');

    // 07 A math question (further on) with its interval, 60 s clock.
    final ladder = mathQuestion(generateMath(MathTopic.trigonometry, 1, 2026));
    final mathShown = DateTime(2026, 11, 8, 9);
    var mathClock = mathShown.add(const Duration(seconds: 9));
    await tester.pumpWidget(
      phoneApp(
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
    await snapPhone(tester, _out, '07-matematik-soru');

    // 08 A tournament question revealed: five intervals, best first.
    final cupChannel = _Channel();
    void tell(Map<String, Object?> m) => cupChannel.incoming.add(jsonEncode(m));
    const names = ['Ayşe', 'Bora', 'Cem', 'Deniz', 'Ece'];
    final cupQuestion = questionStarting(bank, 'Galata Kulesi');
    await tester.pumpWidget(
      phoneApp(
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
      for (final (k, n) in names.indexed)
        {'id': k + 1, 'name': n, 'look': rankLooks[k]},
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
    await snapPhone(tester, _out, '08-turnuva');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
