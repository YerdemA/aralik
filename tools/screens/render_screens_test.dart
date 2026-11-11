// Renders the leaderboard (light and dark), settings (the one name),
// the duel lobby, the duel search and a tournament (room, reveal, standings) with the real Roboto font into
// build/screens/, to look at the design:
//
//   flutter test tools/screens/render_screens_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aralik/core/daily.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/features/duel/duel_lobby_screen.dart';
import 'package:aralik/features/duel/duel_search_view.dart';
import 'package:aralik/data/tournament_client.dart';
import 'package:aralik/features/tournament/tournament_screen.dart';
import 'package:aralik/features/leaderboard/leaderboard_screen.dart';
import 'package:aralik/data/ranked_client.dart';
import 'package:aralik/features/settings/mascot_screen.dart';
import 'package:aralik/features/settings/settings_screen.dart';
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
        TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700),
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

Map<String, Object?> _entry(int rank, String name, int points, int hits) => {
  'rank': rank,
  'nickname': name,
  'points': points,
  'hits': hits,
  'me': false,
};

void main() {
  final out = Directory('build/screens')..createSync(recursive: true);
  final boundary = GlobalKey();

  Future<void> snap(WidgetTester tester, String name) async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('render leaderboard', (tester) async {
    phone(tester);
    await tester.runAsync(_loadRoboto);
    final day = dayIndexFor(DateTime.now());
    for (final (name, theme, tab) in [
      ('liderlik', AppTheme.light, LeaderboardTab.day),
      ('liderlik-koyu', AppTheme.dark, LeaderboardTab.day),
      ('liderlik-arsiv', AppTheme.light, LeaderboardTab.archive),
      ('liderlik-arsiv-koyu', AppTheme.dark, LeaderboardTab.archive),
    ]) {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LeaderboardStore(
        prefs,
        serviceUri: () => Uri.parse('https://lb.example/'),
        deviceKey: () async => null,
        request: (method, uri, [body]) async => (
          status: 200,
          body: uri.path == '/v1/archive'
              ? _archive(day)
              : {
                  'day': day,
                  'players': 64,
                  'limit': 10,
                  'top': [
                    _entry(1, 'Aslan', 482, 5),
                    _entry(2, 'Pars', 455, 5),
                    _entry(3, 'Kartal', 431, 5),
                    _entry(4, 'Tilki', 402, 4),
                    _entry(5, 'Ceylan', 377, 4),
                    _entry(6, 'Baykuş', 350, 4),
                  ],
                  'me': {'rank': 9, 'points': 311, 'hits': 4},
                },
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            key: UniqueKey(),
            debugShowCheckedModeBanner: false,
            theme: _withRoboto(theme),
            home: LeaderboardScreen(
              store: store,
              settings: SettingsStore(prefs),
              day: day,
              dayDone: true,
              initialTab: tab,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await snap(tester, name);
    }
  });

  testWidgets('render duel search', (tester) async {
    phone(tester);
    await tester.runAsync(_loadRoboto);
    for (final (name, theme) in [
      ('duello-arama', AppTheme.light),
      ('duello-arama-koyu', AppTheme.dark),
    ]) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            key: UniqueKey(),
            debugShowCheckedModeBanner: false,
            theme: _withRoboto(theme),
            home: Scaffold(
              appBar: AppBar(
                leading: const CloseButton(),
                title: const Text('Düello'),
              ),
              body: const SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: DuelSearchView(name: 'Ayşe', firstTip: 5),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(seconds: 4));
      await snap(tester, name);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('render settings', (tester) async {
    phone(tester);
    await tester.runAsync(_loadRoboto);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'duel_name': 'Ayşe',
      'name_changed_at': DateTime.now().millisecondsSinceEpoch,
      'lb_id': 'p1',
      'lb_token': 't',
      'lb_nickname': 'Ayşe',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LeaderboardStore(
      prefs,
      serviceUri: () => Uri.parse('https://lb.example/'),
      deviceKey: () async => null,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _withRoboto(AppTheme.light),
          home: SettingsScreen(
            settings: SettingsStore(prefs),
            leaderboard: store,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await snap(tester, 'ayarlar');
    await tester.tap(find.text('Ayşe'));
    await tester.pumpAndSettle();
    await snap(tester, 'ayarlar-ad');
  });

  testWidgets('render ranked table', (tester) async {
    phone(tester);
    await tester.runAsync(_loadRoboto);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'duel_name': 'Yusuf',
      'mascot_look': '011100100',
    });
    final prefs = await SharedPreferences.getInstance();
    const names = ['Deniz', 'Ayşe', 'Yusuf', 'Bora', 'Cem', 'Ece', 'Gül'];
    const looks = [
      '120131212',
      '111002024',
      '011100100',
      '002240311',
      '014312103',
      '100003020',
      '121110432',
    ];
    Map<String, Object?> row(int i) => {
      'rank': i + 1,
      'nickname': names[i],
      'rating': 386 - i * 23,
      'played': 20 - i,
      'won': 14 - i,
      'drawn': 1,
      'average': 290 - i * 9,
      'hitRate': 81 - i * 2,
      'look': looks[i],
    };
    final service = RankedService(
      serviceUri: () => Uri.parse('https://lb.example/'),
      account: () => (id: 'p3', token: 't', nickname: 'Yusuf'),
      prefs: prefs,
      request: (method, uri, [body]) async => (
        status: 200,
        body: <String, Object?>{
          'month': 202611,
          'current': 202611,
          'mode': 'bank',
          'players': 48,
          'top': [for (var i = 0; i < names.length; i++) row(i)],
          'me': row(2),
        },
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _withRoboto(AppTheme.light),
          home: LeaderboardScreen(
            store: LeaderboardStore(
              prefs,
              serviceUri: () => Uri.parse('https://lb.example/'),
              deviceKey: () async => null,
            ),
            ranked: service,
            settings: SettingsStore(prefs),
            day: 10,
            dayDone: true,
            initialTab: LeaderboardTab.duel,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await snap(tester, 'aylik-siralama');
  });

  testWidgets('render mascot editor', (tester) async {
    phone(tester);
    await tester.runAsync(_loadRoboto);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'mascot_look': '110021212'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _withRoboto(AppTheme.light),
          home: MascotScreen(settings: SettingsStore(prefs)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await snap(tester, 'maskot');
  });

  testWidgets('render duel lobby', (tester) async {
    phone(tester);
    await tester.runAsync(_loadRoboto);
    for (final (name, prefs) in [
      ('duello-lobi', {'duel_name': 'Ayşe'}),
      ('duello-lobi-adsiz', <String, Object>{}),
    ]) {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues(prefs);
      final settings = await SettingsStore.open();
      final stats = await StatsStore.open();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            key: UniqueKey(),
            debugShowCheckedModeBanner: false,
            theme: _withRoboto(AppTheme.light),
            home: DuelLobbyScreen(
              service: DuelService(
                serviceUri: () => Uri.parse('https://lb.example/'),
              ),
              repository: QuestionRepository(),
              stats: stats,
              settings: settings,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await snap(tester, name);
    }
  });

  testWidgets('render tournament', (tester) async {
    phone(tester);
    await tester.runAsync(_loadRoboto);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final repository = QuestionRepository();
    final bank = (await tester.runAsync(repository.load))!;
    final question = bank[3];
    final channel = _Channel();
    void say(Map<String, Object?> m) => channel.incoming.add(jsonEncode(m));
    const names = ['Ayşe', 'Bora', 'Cem', 'Deniz', 'Ece'];
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _withRoboto(AppTheme.light),
          home: TournamentScreen(
            service: TournamentService(
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
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    say({'t': 'welcome', 'you': 1});
    say({
      't': 'room',
      'code': 'K7M2P',
      'host': 1,
      'count': 5,
      'players': [
        for (final (k, n) in names.indexed) {'id': k + 1, 'name': n},
      ],
      'min': 3,
      'max': 8,
    });
    await settle();
    await snap(tester, 'turnuva-oda');

    say({
      't': 'start',
      'questions': [question.id],
      'questionMs': 15000,
      'players': [
        for (final (k, n) in names.indexed) {'id': k + 1, 'name': n},
      ],
    });
    say({'t': 'question', 'i': 0, 'ms': 15000});
    await settle();
    final a = question.answer.round();
    say({
      't': 'reveal',
      'i': 0,
      'results': [
        {'id': 1, 'low': a - 2, 'high': a + 3, 'points': 92, 'hit': true},
        {'id': 2, 'low': a - 40, 'high': a + 30, 'points': 48, 'hit': true},
        {'id': 3, 'low': a + 20, 'high': a + 60, 'points': -12, 'hit': false},
        {'id': 4, 'low': null, 'high': null, 'points': -50, 'hit': false},
        {'id': 5, 'low': a - 10, 'high': a + 10, 'points': 77, 'hit': true},
      ],
    });
    say({
      't': 'end',
      'questions': 5,
      'standings': [
        {'id': 1, 'name': 'Ayşe', 'points': 402, 'hits': 5, 'left': false},
        {'id': 5, 'name': 'Ece', 'points': 351, 'hits': 4, 'left': false},
        {'id': 2, 'name': 'Bora', 'points': 280, 'hits': 4, 'left': false},
        {'id': 3, 'name': 'Cem', 'points': 120, 'hits': 2, 'left': false},
        {'id': 4, 'name': 'Deniz', 'points': -150, 'hits': 0, 'left': true},
      ],
    });
    await settle();
    await snap(tester, 'turnuva-soru-sonu');
    await tester.tap(find.byType(FilledButton).last);
    await settle();
    await snap(tester, 'turnuva-sonuc');
    await tester.pumpWidget(const SizedBox());
  });
}

class _Channel implements DuelChannel {
  final incoming = StreamController<String>();

  @override
  Stream<String> get messages => incoming.stream;

  @override
  void send(String message) {}

  @override
  Future<void> close() async {}
}

/// The archive tab's sample: a week of day leaders, last month's podiums.
Map<String, Object?> _archive(int today) => {
  'days': [
    for (final (i, name, look) in [
      (1, 'Aslan', '120131212'),
      (2, 'Ayşe', '111002024'),
      (3, 'Pars', '002240311'),
      (4, 'Ece', '100003020'),
      (5, 'Kartal', '014312103'),
      (6, 'Gül', '121110432'),
      (7, 'Aslan', '120131212'),
    ])
      {'day': today - i, 'nickname': name, 'points': 470 - i * 9, 'look': look},
  ],
  'month': 202610,
  'duels': {
    'bank': [
      {'rank': 1, 'nickname': 'Deniz', 'rating': 412, 'look': '120131212'},
      {'rank': 2, 'nickname': 'Ayşe', 'rating': 377, 'look': '111002024'},
      {'rank': 3, 'nickname': 'Bora', 'rating': 351, 'look': '002240311'},
    ],
    'math': [
      {'rank': 1, 'nickname': 'Cem', 'rating': 298, 'look': '014312103'},
      {'rank': 2, 'nickname': 'Gül', 'rating': 240, 'look': '121110432'},
    ],
  },
};
