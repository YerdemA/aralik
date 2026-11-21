// Draws every part of the app step by step for the promo video, from the
// real screens with sample data, into play-store/video/ekranlar/ (not in
// git): 1080 × 2400 phone shots with a clean status bar, numbered in the
// order the video tells them (play-store/video/video-metni.md).
//
//   flutter test tools/video/capture_video_screens_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:aralik/core/answer_scale.dart';
import 'package:aralik/core/daily.dart';
import 'package:aralik/core/mascot_look.dart';
import 'package:aralik/core/math/math_problem.dart';
import 'package:aralik/core/math/math_question.dart';
import 'package:aralik/core/question_timer.dart';
import 'package:aralik/core/ranked.dart';
import 'package:aralik/core/scoring.dart';
import 'package:aralik/core/strings.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/question.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/ranked_client.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/data/tournament_client.dart';
import 'package:aralik/features/duel/duel_lobby_screen.dart';
import 'package:aralik/features/duel/duel_screen.dart';
import 'package:aralik/features/duel/duel_search_view.dart';
import 'package:aralik/features/game/game_screen.dart';
import 'package:aralik/features/home/home_screen.dart';
import 'package:aralik/features/intro/intro_screen.dart';
import 'package:aralik/features/leaderboard/leaderboard_screen.dart';
import 'package:aralik/features/math/math_mode_screen.dart';
import 'package:aralik/features/ranked/month_end_screen.dart';
import 'package:aralik/features/result/summary_screen.dart';
import 'package:aralik/features/settings/mascot_screen.dart';
import 'package:aralik/features/settings/settings_screen.dart';
import 'package:aralik/features/stats/stats_screen.dart';
import 'package:aralik/features/tournament/tournament_entry_screen.dart';
import 'package:aralik/features/tournament/tournament_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../store/phone_frame.dart';

final _out = Directory('play-store/video/ekranlar');

/// The player and the others, with their mascots.
const _me = 'Ayşe';
const _myLook = '111002024';
const _names = ['Deniz', 'Bora', 'Ayşe', 'Kerem', 'Cem', 'Ece', 'Gül'];
const _looks = [
  '120131212',
  '014312103',
  _myLook,
  '002240311',
  '010331100',
  '100003020',
  '121110432',
];
String _lookOf(String name) => _looks[_names.indexOf(name)];

class _Channel implements DuelChannel {
  final incoming = StreamController<String>();

  @override
  Stream<String> get messages => incoming.stream;

  @override
  void send(String message) {}

  @override
  Future<void> close() async {}
}

Map<String, Object?> _rankRow(int i) => {
  'rank': i + 1,
  'nickname': _names[i],
  'rating': 386 - i * 23,
  'played': 20 - i,
  'won': 14 - i,
  'drawn': 1,
  'average': 290 - i * 9,
  'hitRate': 81 - i * 2,
  'look': _looks[i],
};

Map<String, Object?> _rankedTable(String mode) => {
  'month': 202611,
  'current': 202611,
  'mode': mode,
  'players': 48,
  'top': [for (var i = 0; i < _names.length; i++) _rankRow(i)],
  'me': _rankRow(2),
};

Map<String, Object?> _dayBoard(int day) => {
  'day': day,
  'players': 64,
  'limit': 10,
  'top': [
    for (final (i, (name, points, hits)) in [
      ('Deniz', 482, 5),
      ('Bora', 455, 5),
      ('Kerem', 431, 5),
      ('Ayşe', 402, 4),
      ('Cem', 377, 4),
      ('Ece', 350, 4),
      ('Gül', 322, 4),
    ].indexed)
      {
        'rank': i + 1,
        'nickname': name,
        'points': points,
        'hits': hits,
        'me': name == _me,
        'look': _lookOf(name),
      },
  ],
  'me': {'rank': 4, 'points': 402, 'hits': 4},
};

Map<String, Object?> _archive(int today) => {
  'days': [
    for (final (i, name) in [
      'Deniz',
      'Ayşe',
      'Kerem',
      'Ece',
      'Bora',
      'Gül',
      'Deniz',
    ].indexed)
      {
        'day': today - i - 1,
        'nickname': name,
        'points': 470 - i * 9,
        'look': _lookOf(name),
      },
  ],
  'month': 202610,
  'duels': {
    'bank': [
      for (final (i, name) in ['Deniz', 'Ayşe', 'Bora'].indexed)
        {
          'rank': i + 1,
          'nickname': name,
          'rating': 412 - i * 30,
          'look': _lookOf(name),
        },
    ],
    'math': [
      for (final (i, name) in ['Cem', 'Gül', 'Kerem'].indexed)
        {
          'rank': i + 1,
          'nickname': name,
          'rating': 298 - i * 40,
          'look': _lookOf(name),
        },
    ],
  },
};

void main() {
  setUpAll(() {
    // Old shots go (their numbers may have moved); the folder stays.
    _out.createSync(recursive: true);
    for (final f in _out.listSync().whereType<File>()) {
      if (f.path.endsWith('.png')) f.deleteSync();
    }
  });

  testWidgets('capture video screens', (tester) async {
    phoneView(tester);
    await tester.runAsync(loadPhoneFonts);
    final repository = QuestionRepository();
    final bank = (await tester.runAsync(repository.load))!;
    final today = dayIndexFor(DateTime.now());
    // ignore: invalid_use_of_visible_for_testing_member
    HomeScreen.updateOffered = true;

    var count = 0;
    Future<void> shot(String name) =>
        snapPhone(tester, _out, '${'${++count}'.padLeft(2, '0')}-$name');
    Future<void> frames([int n = 4, int ms = 250]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(Duration(milliseconds: ms));
      }
    }

    Future<void> real([int ms = 50]) =>
        tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    Future<void> type(String digits) async {
      for (final key in digits.split('')) {
        await tester.tap(find.text(key).last);
        await tester.pump();
      }
    }

    // Taps the slider at [f] of its track (0 narrowest, 1 widest).
    Future<void> slide(double f) async {
      final box = tester.getRect(find.byType(Slider));
      const inset = 24.0; // the thumb's travel stops short of the ends
      await tester.tapAt(
        Offset(box.left + inset + (box.width - 2 * inset) * f, box.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    // --- Opening -----------------------------------------------------------
    await tester.pumpWidget(phoneApp(const IntroScreen(next: SizedBox())));
    await tester.pump(const Duration(milliseconds: 350));
    await shot('acilis');
    await frames();

    // First launch: the tour over the home screen.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'duel_name': _me});
    final freshPrefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      phoneApp(
        HomeScreen(
          repository: repository,
          stats: StatsStore(freshPrefs),
          settings: SettingsStore(freshPrefs),
          leaderboard: LeaderboardStore(
            freshPrefs,
            serviceUri: () => Uri.parse('https://lb.example/'),
            deviceKey: () async => null,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await frames();
    await shot('tanitim-hos-geldin');
    await tester.tap(find.text(AppStrings.tourNext));
    await frames();
    await shot('tanitim-gunun-seti');

    // --- A regular player: 14-day streak -----------------------------------
    final stats = await seededStats(bank, today);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('duel_name', _me);
    await prefs.setInt(
      'name_changed_at',
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString('mascot_look', _myLook);
    await prefs.setString('lb_id', 'p3');
    await prefs.setString('lb_token', 't');
    await prefs.setString('lb_nickname', _me);
    final settings = SettingsStore(prefs);
    final leaderboard = LeaderboardStore(
      prefs,
      serviceUri: () => Uri.parse('https://lb.example/'),
      deviceKey: () async => null,
      request: (method, uri, [body]) async => (
        status: 200,
        body: uri.path == '/v1/archive' ? _archive(today) : _dayBoard(today),
      ),
    );
    final ranked = RankedService(
      serviceUri: () => Uri.parse('https://lb.example/'),
      account: () => (id: 'p3', token: 't', nickname: _me),
      prefs: prefs,
      request: (method, uri, [body]) async => (
        status: 200,
        body: _rankedTable(uri.queryParameters['mode'] ?? 'bank'),
      ),
    );
    Widget home() => HomeScreen(
      repository: repository,
      stats: stats,
      settings: settings,
      leaderboard: leaderboard,
      ranked: ranked,
    );

    await tester.pumpWidget(phoneApp(home()));
    await tester.pump(const Duration(seconds: 2));
    await shot('ana-ekran');

    // --- The daily set -----------------------------------------------------
    final daily = [
      questionStarting(bank, 'Ağrı Dağı'),
      questionStarting(bank, 'Pearl Harbor'),
      questionStarting(bank, 'İstanbul Boğazı'),
      questionStarting(bank, 'Everest Dağı'),
      questionStarting(bank, 'Galata Kulesi'),
    ];
    final shown = DateTime(2026, 11, 21, 9);
    var clock = shown.add(const Duration(seconds: 2));
    await tester.pumpWidget(
      phoneApp(
        GameScreen(
          questions: daily,
          startQuestion: (_) => shown,
          now: () => clock,
          onLocked: (a) => stats.recordAnswer(
            questionId: a.question.id,
            category: a.question.category,
            outcome: a.outcome,
            dailyDay: today,
            points: a.points,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot('soru');
    clock = shown.add(const Duration(seconds: 4));
    await type('4500');
    await tester.pump(const Duration(milliseconds: 500));
    await shot('tahmin');
    await tester.tap(find.text(AppStrings.next));
    await tester.pump(const Duration(milliseconds: 500));
    clock = shown.add(const Duration(seconds: 6));
    await slide(.62);
    await shot('aralik-genis');
    clock = shown.add(const Duration(seconds: 8));
    await slide(.17);
    await shot('aralik-dar');
    await tester.tap(find.text(AppStrings.lock));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await shot('isabet');

    // A year question, too sure: a miss.
    await tester.tap(find.text(AppStrings.next));
    await frames(3);
    clock = shown.add(const Duration(seconds: 3));
    await type('1946');
    await tester.tap(find.text(AppStrings.next));
    await tester.pump(const Duration(milliseconds: 500));
    await slide(.2);
    await shot('yil-sorusu');
    await tester.tap(find.text(AppStrings.lock));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await shot('iska');

    // The other three, close guesses.
    for (final q in daily.skip(2)) {
      await tester.tap(find.text(AppStrings.next));
      await frames(3);
      await type((q.answer * 1.12).round().toString());
      await tester.tap(find.text(AppStrings.next));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.drag(find.byType(Slider), const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(AppStrings.lock));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
    }
    await real();

    // The day's summary and its share card.
    await tester.pumpWidget(
      phoneApp(
        SummaryScreen(
          mascot: MascotLook.parse(_myLook),
          results: stats.dailyResults(today),
          hits: stats.hits,
          answered: stats.answered,
          dayIndex: today,
          onLeaderboard: () {},
        ),
      ),
    );
    await frames(8);
    await shot('gun-ozeti');
    await tester.tap(find.text(AppStrings.share));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await real(300);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await shot('paylasim');

    await tester.pumpWidget(phoneApp(home()));
    await tester.pump(const Duration(seconds: 2));
    await shot('ana-ekran-set-bitti');

    await tester.pumpWidget(phoneApp(StatsScreen(stats: stats, today: today)));
    await frames(6);
    await shot('istatistikler');

    // --- Free play: an on-device distance question -------------------------
    final distances = (await tester.runAsync(repository.distanceQuestions))!;
    final rng = math.Random(11);
    Question? distance;
    while (distance == null || !distance.text.contains('İzmir')) {
      distance = distances.pick(rng);
    }
    await tester.pumpWidget(
      phoneApp(GameScreen(questions: [distance, ...bank.skip(40).take(4)])),
    );
    await tester.pump();
    await type((distance.answer * 0.9).round().toString());
    await tester.tap(find.text(AppStrings.next));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.drag(find.byType(Slider), const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('bir-tur-aralik');
    await tester.tap(find.text(AppStrings.lock));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await shot('bir-tur-sonuc');

    // --- Duel --------------------------------------------------------------
    final duelService = DuelService(
      serviceUri: () => Uri.parse('https://lb.example/'),
    );
    await tester.pumpWidget(
      phoneApp(
        DuelLobbyScreen(
          service: duelService,
          repository: repository,
          stats: stats,
          settings: settings,
        ),
      ),
    );
    await frames(6);
    await shot('duello-lobi');

    await tester.pumpWidget(
      phoneApp(
        Scaffold(
          appBar: AppBar(
            leading: const CloseButton(),
            title: const Text(AppStrings.duelTitle),
          ),
          body: const SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: DuelSearchView(name: _me, firstTip: 5),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(seconds: 4));
    await shot('duello-rakip-arama');
    await tester.pumpWidget(const SizedBox());

    final duelQuestions = [
      questionStarting(bank, 'Boğaziçi Üniversitesi'),
      questionStarting(bank, 'Everest Dağı'),
      questionStarting(bank, 'Pearl Harbor'),
      questionStarting(bank, 'İstanbul Boğazı'),
      questionStarting(bank, 'Galata Kulesi'),
    ];
    const intervals = [
      ((1850, 1880), (1870, 1900)),
      ((8000, 9500), (6000, 12000)),
      ((1938, 1944), (1935, 1950)),
      ((25, 40), (40, 70)),
      ((50, 75), (60, 110)),
    ];
    final channel = _Channel();
    void say(Map<String, Object?> m) => channel.incoming.add(jsonEncode(m));
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
          name: _me,
        ),
      ),
    );
    await real(0);
    await tester.pump();
    say({
      't': 'start',
      'you': 0,
      'names': [_me, 'Bora'],
      'looks': [_myLook, _lookOf('Bora')],
      'ranked': true,
      'questions': [for (final q in duelQuestions) q.id],
      'questionMs': 15000,
    });
    say({'t': 'question', 'i': 0, 'ms': 15000});
    await real(0);
    await frames(2);
    await type('1865');
    await tester.pump(const Duration(milliseconds: 300));
    say({'t': 'locked', 'i': 0, 'seat': 1});
    await real(0);
    await frames(3);
    await shot('duello-soru');

    // Held down: the reactions fan, the finger on "Kıl payı!".
    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel(AppStrings.reactionButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(tester.getCenter(find.text(AppStrings.reactionClose)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shot('duello-tepki');
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

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
      if (i > 0) say({'t': 'question', 'i': i, 'ms': 15000});
      say({
        't': 'reveal',
        'i': i,
        'results': [me, them],
        'totals': totals,
        if (i < 4) 'ms': 12000,
      });
      await real(0);
      await tester.pump();
      if (i == 0) {
        say({'t': 'react', 'seat': 1, 'r': 'sad'});
        await real(0);
        await frames();
        await shot('duello-cevap');
      }
    }
    say({
      't': 'end',
      'totals': totals,
      'winner': totals[0] >= totals[1] ? 0 : 1,
      'reason': 'done',
      'rematch': true,
    });
    say({
      't': 'rated',
      'ratings': [
        {'before': 120, 'after': 138},
        {'before': 131, 'after': 113},
      ],
    });
    for (var i = 0; i < 3; i++) {
      await real(0);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text(AppStrings.duelSeeResult));
    await frames(4, 400);
    await tester.pump(const Duration(milliseconds: 300));
    await shot('duello-sonuc-puan');
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await shot('duello-sonuc');
    say({'t': 'rematch', 'seat': 1});
    await real(0);
    await frames();
    await shot('duello-rovans');
    await tester.tap(find.text(AppStrings.share));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await real(300);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await shot('duello-paylasim');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));

    // --- Math ----------------------------------------------------------------
    await tester.pumpWidget(phoneApp(const MathModeScreen()));
    await tester.pump(const Duration(seconds: 1));
    await shot('matematik-secim');
    final ladder = mathQuestion(generateMath(MathTopic.trigonometry, 1, 2026));
    final mathShown = DateTime(2026, 11, 21, 9);
    await tester.pumpWidget(
      phoneApp(
        GameScreen(
          questions: List.filled(5, ladder),
          startQuestion: (_) => mathShown,
          now: () => mathShown.add(const Duration(seconds: 14)),
          timeLimit: mathTimeLimit,
          scale: mathScaleOf,
          minPoints: mathMinPoints,
        ),
      ),
    );
    await tester.pump();
    await type((ladder.answer * 1.08).round().toString());
    await tester.tap(find.text(AppStrings.next));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.drag(find.byType(Slider), const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('matematik-soru');
    await tester.tap(find.text(AppStrings.lock));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await shot('matematik-cozum');

    // --- Tournament ----------------------------------------------------------
    await tester.pumpWidget(
      phoneApp(
        TournamentEntryScreen(
          service: TournamentService(
            serviceUri: () => Uri.parse('https://lb.example/'),
          ),
          repository: repository,
          stats: stats,
          settings: settings,
        ),
      ),
    );
    await frames(6);
    await shot('turnuva-giris');

    final cupChannel = _Channel();
    void tell(Map<String, Object?> m) => cupChannel.incoming.add(jsonEncode(m));
    const cupNames = [_me, 'Bora', 'Cem', 'Deniz', 'Ece'];
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
          name: _me,
        ),
      ),
    );
    await real(0);
    await tester.pump();
    final players = [
      for (final (k, n) in cupNames.indexed)
        {'id': k + 1, 'name': n, 'look': _lookOf(n)},
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
    await real(0);
    await frames(3);
    await shot('turnuva-oda');
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
    await real(0);
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
    await real(0);
    await frames(3, 300);
    await shot('turnuva-cevap');
    tell({
      't': 'end',
      'questions': 5,
      'standings': [
        {'id': 1, 'name': _me, 'points': 402, 'hits': 5, 'left': false},
        {'id': 5, 'name': 'Ece', 'points': 351, 'hits': 4, 'left': false},
        {'id': 2, 'name': 'Bora', 'points': 280, 'hits': 4, 'left': false},
        {'id': 3, 'name': 'Cem', 'points': 120, 'hits': 2, 'left': false},
        {'id': 4, 'name': 'Deniz', 'points': -40, 'hits': 1, 'left': false},
      ],
    });
    await real(0);
    await frames(2);
    await tester.tap(find.byType(FilledButton).last);
    await frames(3);
    await shot('turnuva-sonuc');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));

    // --- Leaderboards --------------------------------------------------------
    for (final (name, tab) in [
      ('gunun-liderleri', LeaderboardTab.day),
      ('aylik-siralama', LeaderboardTab.duel),
      ('arsiv', LeaderboardTab.archive),
    ]) {
      await tester.pumpWidget(
        phoneApp(
          LeaderboardScreen(
            store: leaderboard,
            ranked: ranked,
            settings: settings,
            day: today,
            dayDone: true,
            initialTab: tab,
          ),
        ),
      );
      await real(0);
      await frames(6);
      await shot(name);
    }

    await tester.pumpWidget(
      phoneApp(
        MonthEndScreen(
          tables: [
            RankedTable.fromJson(_rankedTable('bank'))!,
            RankedTable.fromJson(_rankedTable('math'))!,
          ],
          look: MascotLook.parse(_myLook),
          save: (_, _) async => true,
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await real(300);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await shot('ay-sonu-karti');

    // --- Mascot, settings, dark theme ---------------------------------------
    await prefs.setString('mascot_look', '110021212');
    await tester.pumpWidget(phoneApp(MascotScreen(settings: settings)));
    await frames();
    await shot('maskot');
    await prefs.setString('mascot_look', _myLook);

    await tester.pumpWidget(
      phoneApp(SettingsScreen(settings: settings, leaderboard: leaderboard)),
    );
    await frames();
    await shot('ayarlar');

    await tester.pumpWidget(phoneApp(home(), dark: true));
    await tester.pump(const Duration(seconds: 2));
    await shot('ana-ekran-koyu');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
