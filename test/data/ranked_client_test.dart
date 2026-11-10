import 'package:aralik/core/duel.dart';
import 'package:aralik/core/ranked.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/ranked_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'duel_client_test.dart' show FakeChannel;

final _base = Uri.parse('https://lb.example/');
const LeaderboardAccount _account = (id: 'p1', token: 't', nickname: 'Ayşe');

Map<String, Object?> _table(int month, {bool me = true}) => {
  'month': month,
  'current': 202612,
  'mode': 'bank',
  'players': 3,
  'top': [
    {'rank': 1, 'nickname': 'Ayşe', 'rating': 1040, 'played': 3},
  ],
  if (me) 'me': {'rank': 1, 'nickname': 'Ayşe', 'rating': 1040, 'played': 3},
};

void main() {
  test('asks for a table with the viewer and reads it', () async {
    SharedPreferences.setMockInitialValues({});
    final asked = <Uri>[];
    final service = RankedService(
      serviceUri: () => _base,
      account: () => _account,
      prefs: await SharedPreferences.getInstance(),
      request: (method, uri, [body]) async {
        asked.add(uri);
        return (status: 200, body: _table(202612));
      },
    );
    final t = await service.table(RankedMode.math, month: 202611);
    expect(asked.single.path, '/v1/duel/ranked');
    expect(asked.single.queryParameters, {
      'mode': 'math',
      'month': '202611',
      'player': 'p1',
    });
    expect(t.me!.rating, 1040);
  });

  test('failures', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    RankedService with_(JsonRequest request) => RankedService(
      serviceUri: () => _base,
      account: () => null,
      prefs: prefs,
      request: request,
    );
    await expectLater(
      with_((m, u, [b]) => Future.error(Exception('down')))
          .table(RankedMode.bank),
      throwsA(isA<RankedException>()),
    );
    await expectLater(
      with_((m, u, [b]) async => (status: 500, body: null))
          .table(RankedMode.bank),
      throwsA(isA<RankedException>()),
    );
  });

  test('the month-end recap: only tables with a line, once', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    final service = RankedService(
      serviceUri: () => _base,
      account: () => _account,
      prefs: prefs,
      now: () => DateTime.utc(2026, 12, 2, 9),
      request: (method, uri, [body]) async {
        calls++;
        expect(uri.queryParameters['month'], '202611');
        final math = uri.queryParameters['mode'] == 'math';
        return (status: 200, body: _table(202611, me: !math));
      },
    );
    final tables = await service.monthEndRecap();
    expect(tables, hasLength(1));
    expect(tables.single.month, 202611);
    // Not marked until shown: asked again.
    expect(await service.monthEndRecap(), hasLength(1));
    await service.markRecapShown(202611);
    calls = 0;
    expect(await service.monthEndRecap(), isEmpty);
    expect(calls, 0);
  });

  test('no recap without an account; nothing to show is marked', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    RankedService service(LeaderboardAccount? account) => RankedService(
      serviceUri: () => _base,
      account: () => account,
      prefs: prefs,
      now: () => DateTime.utc(2026, 12, 2, 9),
      request: (method, uri, [body]) async {
        calls++;
        return (status: 200, body: _table(202611, me: false));
      },
    );
    expect(await service(null).monthEndRecap(), isEmpty);
    expect(calls, 0);
    expect(await service(_account).monthEndRecap(), isEmpty);
    expect(calls, 2);
    expect(await service(_account).monthEndRecap(), isEmpty);
    expect(calls, 2);
  });

  test('the account goes only to a random opponent\'s room', () async {
    final opened = <Uri>[];
    final service = DuelService(
      serviceUri: () => _base,
      account: () => (id: 'p1', token: 'secret'),
      connect: (uri) async {
        opened.add(uri);
        return FakeChannel();
      },
    );
    await service.join(
      code: 'K7M2P',
      name: 'Ayşe',
      bankSize: 9,
      match: DuelMatch(),
      ranked: true,
    );
    await service.join(
      code: 'K7M2P',
      name: 'Ayşe',
      bankSize: 9,
      match: DuelMatch(),
    );
    await service.join(
      code: 'K7M2P',
      name: 'Ayşe',
      bankSize: 9,
      match: DuelMatch(),
      ranked: true,
      rejoin: 'r',
    );
    expect(opened[0].queryParameters['pid'], 'p1');
    expect(opened[0].queryParameters['ptok'], 'secret');
    expect(opened[1].queryParameters.containsKey('pid'), isFalse);
    expect(opened[2].queryParameters.containsKey('ptok'), isFalse);
  });
}
