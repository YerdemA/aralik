import 'dart:typed_data';

import 'package:aralik/core/mascot_look.dart';
import 'package:aralik/core/ranked.dart';
import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/ranked_client.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/features/ranked/month_end_screen.dart';
import 'package:aralik/features/ranked/ranked_screen.dart';
import 'package:aralik/features/result/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const RankedRow _me = RankedRow(
  rank: 2,
  nickname: 'Bora',
  rating: 1012,
  played: 5,
  won: 3,
  drawn: 0,
  average: 240,
  hitRate: 72,
);

RankedTable _table({bool me = true, int month = 202611}) => RankedTable(
  month: month,
  current: 202611,
  mode: RankedMode.bank,
  players: 2,
  top: const [
    RankedRow(
      rank: 1,
      nickname: 'Ayşe',
      rating: 1040,
      played: 6,
      won: 5,
      drawn: 0,
      average: 300,
      hitRate: 80,
    ),
    _me,
  ],
  me: me ? _me : null,
);

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

Future<(RankedService, SettingsStore)> _stores({
  required bool joined,
  required List<Uri> asked,
}) async {
  SharedPreferences.setMockInitialValues({'duel_name': 'Bora'});
  final prefs = await SharedPreferences.getInstance();
  const LeaderboardAccount account = (id: 'p2', token: 't', nickname: 'Bora');
  final service = RankedService(
    serviceUri: () => Uri.parse('https://lb.example/'),
    account: () => joined ? account : null,
    prefs: prefs,
    request: (method, uri, [body]) async {
      asked.add(uri);
      return (
        status: 200,
        body: <String, Object?>{
          'month': 202611,
          'current': 202611,
          'mode': uri.queryParameters['mode'],
          'players': 2,
          'top': [
            {'rank': 1, 'nickname': 'Ayşe', 'rating': 1040, 'played': 6},
            {'rank': 2, 'nickname': 'Bora', 'rating': 1012, 'played': 5},
          ],
          if (joined)
            'me': {
              'rank': 2,
              'nickname': 'Bora',
              'rating': 1012,
              'played': 5,
              'won': 3,
            },
        },
      );
    },
  );
  return (service, SettingsStore(prefs));
}

void main() {
  testWidgets('the month table: my line, the leaders, the other mode', (
    tester,
  ) async {
    final asked = <Uri>[];
    final (service, settings) = await _stores(joined: true, asked: asked);
    await tester.pumpWidget(
      _app(RankedScreen(service: service, settings: settings)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kasım 2026 · 2 oyuncu'), findsOneWidget);
    expect(find.byType(MyRankedCard), findsOneWidget);
    expect(find.byType(RankedRowTile), findsNWidgets(2));
    expect(find.text('Ayşe'), findsOneWidget);
    expect(asked.single.queryParameters['mode'], 'bank');
    await tester.tap(find.text(AppStrings.duelKindMath));
    await tester.pumpAndSettle();
    expect(asked.last.queryParameters['mode'], 'math');
  });

  testWidgets('not joined: the offer to join, no line of mine', (tester) async {
    final (service, settings) = await _stores(joined: false, asked: []);
    SharedPreferences.setMockInitialValues({});
    final store = LeaderboardStore(
      await SharedPreferences.getInstance(),
      serviceUri: () => Uri.parse('https://lb.example/'),
      deviceKey: () async => null,
    );
    await tester.pumpWidget(
      _app(
        RankedScreen(service: service, settings: settings, leaderboard: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.rankedJoinFirst), findsOneWidget);
    expect(find.byType(MyRankedCard), findsNothing);
  });

  testWidgets('month end: download saves, or falls back to sharing', (
    tester,
  ) async {
    final saved = <String>[];
    RankedCardData? drawn;
    await tester.pumpWidget(
      _app(
        MonthEndScreen(
          tables: [_table()],
          look: MascotLook.woman,
          render: (data) async {
            drawn = data;
            return Uint8List.fromList(_png);
          },
          save: (png, name) async {
            saved.add(name);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kasım 2026 bitti!'), findsOneWidget);
    expect(find.text('2 oyuncu arasında 2. oldun'), findsOneWidget);
    expect(drawn!.me.rating, 1012);
    expect(drawn!.look, MascotLook.woman);
    await tester.tap(find.text(AppStrings.monthEndDownload));
    await tester.pumpAndSettle();
    expect(saved, ['kabaca-2026-11-bilgi.png']);
    expect(find.text(AppStrings.monthEndSaved), findsOneWidget);
  });

  test('the card: mood by place, text and file name', () {
    RankedCardData card(int rank, int players) => RankedCardData(
      month: 202611,
      math: true,
      players: players,
      me: RankedRow(
        rank: rank,
        nickname: 'Bora',
        rating: 1012,
        played: 5,
        won: 3,
        drawn: 0,
        average: 240,
        hitRate: 72,
      ),
      look: MascotLook.philosopher,
    );
    expect(card(1, 10).mood.name, 'legend');
    expect(card(3, 10).mood.name, 'great');
    expect(card(5, 10).mood.name, 'proud');
    expect(card(6, 10).mood.name, 'unsure');
    expect(
      card(2, 10).shareText,
      'Kabaca · Kasım 2026 · Matematik düellosu\n'
      '2. oldum · 1012 puan\n'
      '5 düello, 3 galibiyet',
    );
    expect(card(2, 10).fileName, 'kabaca-2026-11-matematik.png');
  });
}

/// A 1 × 1 transparent PNG.
const _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
