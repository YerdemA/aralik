import 'dart:io';

import 'package:aralik/data/leaderboard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Sent = ({String method, Uri uri, Map<String, Object?>? body});

final _device = 'd' * 64;

void main() {
  late SharedPreferences prefs;
  late List<Sent> sent;
  late JsonReply Function(Sent request) reply;
  Uri? service;

  LeaderboardStore store() => LeaderboardStore(
    prefs,
    serviceUri: () => service,
    request: (method, uri, [body]) async {
      final request = (method: method, uri: uri, body: body);
      sent.add(request);
      return reply(request);
    },
    deviceKey: () async => _device,
  );

  const registered = (
    status: 201,
    body: {'id': 'p1', 'token': 'secret', 'nickname': 'Kaplan'},
  );

  Future<LeaderboardStore> joinedStore() async {
    final s = store();
    reply = (_) => registered;
    await s.join('Kaplan');
    sent.clear();
    return s;
  }

  Future<void> finishDay(LeaderboardStore s, int day) async {
    for (var i = 0; i < 5; i++) {
      await s.recordDailyInterval(day, (
        questionId: 'q$i',
        low: i == 4 ? null : 10 * i + 1,
        high: i == 4 ? null : 10 * i + 5,
      ));
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    sent = [];
    service = Uri.parse('https://lb.example/api');
    reply = (_) => (status: 200, body: const <String, Object?>{});
  });

  test('available only with a server; endpoints go below its path', () async {
    service = null;
    expect(store().isAvailable, isFalse);
    service = Uri.parse('https://lb.example/api');
    expect(store().serviceUri, Uri.parse('https://lb.example/api/'));
    final s = await joinedStore();
    reply = (_) => (
      status: 200,
      body: {'day': 3, 'players': 0, 'top': <Object>[], 'me': null},
    );
    await s.fetchBoard(3);
    expect(
      sent.single.uri,
      Uri.parse('https://lb.example/api/v1/day/3?player=p1'),
    );
  });

  test('join keeps the account', () async {
    final s = store();
    expect(s.joined, isFalse);
    var notified = 0;
    s.addListener(() => notified++);
    reply = (_) => registered;
    await s.join('Kaplan');
    expect(sent.single.body, {'nickname': 'Kaplan', 'device': _device});
    expect(s.account, (id: 'p1', token: 'secret', nickname: 'Kaplan'));
    expect(store().joined, isTrue); // persisted
    expect(notified, 1);
  });

  test('maps server errors and network failures', () async {
    final s = store();
    Future<LeaderboardFailure?> failure() async {
      try {
        await s.join('Kaplan');
        return null;
      } on LeaderboardException catch (e) {
        return e.failure;
      }
    }

    reply = (_) => (status: 409, body: {'error': 'nickname_taken'});
    expect(await failure(), LeaderboardFailure.nicknameTaken);
    reply = (_) => (status: 400, body: {'error': 'blocked_nickname'});
    expect(await failure(), LeaderboardFailure.nicknameBlocked);
    reply = (_) => (status: 400, body: {'error': 'invalid_nickname'});
    expect(await failure(), LeaderboardFailure.nicknameInvalid);
    reply = (_) => (status: 429, body: {'error': 'rate_limited'});
    expect(await failure(), LeaderboardFailure.rateLimited);
    reply = (_) => (status: 500, body: null);
    expect(await failure(), LeaderboardFailure.server);
    reply = (_) => throw const SocketException('offline');
    expect(await failure(), LeaderboardFailure.offline);
    expect(s.joined, isFalse);
  });

  test('a finished day is sent once, with its intervals', () async {
    final s = await joinedStore();
    await finishDay(s, 3);
    expect(await s.submit(3), isTrue);
    expect(sent.single.uri.path, '/api/v1/submit');
    expect(sent.single.body, {
      'device': _device,
      'day': 3,
      'answers': [
        {'q': 'q0', 'low': 1, 'high': 5},
        {'q': 'q1', 'low': 11, 'high': 15},
        {'q': 'q2', 'low': 21, 'high': 25},
        {'q': 'q3', 'low': 31, 'high': 35},
        {'q': 'q4', 'low': null, 'high': null},
      ],
      'id': 'p1',
      'token': 'secret',
    });
    expect(s.isSent(3), isTrue);
    expect(await s.submit(3), isTrue);
    expect(sent, hasLength(1));
  });

  test('nothing is sent before joining or before the set is done', () async {
    final s = store();
    await finishDay(s, 3);
    expect(await s.submit(3), isFalse);
    expect(sent, isEmpty);
    expect(s.dailyIntervals(3), hasLength(5)); // kept for a later join

    final joined = await joinedStore();
    await joined.recordDailyInterval(4, (questionId: 'q0', low: 1, high: 2));
    expect(await joined.submit(4), isFalse);
    expect(sent, isEmpty);
  });

  test('offline keeps the day pending; submitPending sends it', () async {
    final s = await joinedStore();
    await finishDay(s, 3);
    reply = (_) => throw const SocketException('offline');
    expect(await s.submit(3), isFalse);
    expect(s.isSent(3), isFalse);

    reply = (_) => (status: 200, body: const <String, Object?>{});
    sent.clear();
    await s.submitPending(4); // yesterday and today
    expect(sent.single.body!['day'], 3);
    expect(s.isSent(3), isTrue);
  });

  test('a refused day is not tried again', () async {
    final s = await joinedStore();
    await finishDay(s, 3);
    reply = (_) => (status: 422, body: {'error': 'day_closed'});
    expect(await s.submit(3), isFalse);
    expect(s.isSent(3), isTrue);
    expect(await s.submit(3), isTrue);
    expect(sent, hasLength(1));
  });

  test('an account gone from the server is forgotten', () async {
    final s = await joinedStore();
    await finishDay(s, 3);
    reply = (_) => (status: 401, body: {'error': 'unauthorized'});
    expect(await s.submit(3), isFalse);
    expect(s.joined, isFalse);
    expect(s.dailyIntervals(3), hasLength(5)); // sent again after rejoining
  });

  test('rename and leave', () async {
    final s = await joinedStore();
    reply = (_) => (status: 200, body: {'nickname': 'Pars'});
    await s.rename('Pars');
    expect(s.account?.nickname, 'Pars');
    expect(sent.last.body, {'nickname': 'Pars', 'id': 'p1', 'token': 'secret'});

    await finishDay(s, 3);
    reply = (_) => (status: 200, body: const <String, Object?>{});
    await s.submit(3);
    reply = (_) => (status: 200, body: {'deleted': true});
    await s.leave();
    expect(sent.last.uri.path, '/api/v1/delete');
    expect(s.joined, isFalse);
    expect(s.isSent(3), isFalse); // a new account may send it again
  });

  test('leaving offline keeps the account', () async {
    final s = await joinedStore();
    reply = (_) => throw const SocketException('offline');
    await expectLater(s.leave(), throwsA(isA<LeaderboardException>()));
    expect(s.joined, isTrue);
  });

  test('only the last few days of intervals are kept', () async {
    final s = store();
    await finishDay(s, 1);
    await finishDay(s, 2);
    await finishDay(s, 5);
    expect(s.dailyIntervals(1), isEmpty);
    expect(s.dailyIntervals(2), isEmpty);
    expect(s.dailyIntervals(5), hasLength(5));
  });

  test('parses a board', () {
    final board = LeaderboardBoard.fromJson({
      'day': 3,
      'players': 12,
      'limit': 10,
      'top': [
        {'rank': 1, 'nickname': 'İki', 'points': 480, 'hits': 5, 'me': false},
      ],
      'me': {'rank': 7, 'points': 210, 'hits': 4},
    });
    expect(board.players, 12);
    expect(board.top.single.nickname, 'İki');
    expect(board.me?.rank, 7);
    expect(board.me?.isMe, isTrue);
    expect(board.meInTop, isFalse);
  });

  test('joining from a device that had an account gets it back', () async {
    final s = store();
    reply = (_) => (
      status: 200,
      body: {'id': 'p9', 'token': 'new', 'nickname': 'Eski', 'restored': true},
    );
    expect(await s.join('Yeni'), isTrue);
    expect(s.account, (id: 'p9', token: 'new', nickname: 'Eski'));
    reply = (_) => registered;
    expect(await store().join('Kaplan'), isFalse);
  });

  test('a day this device already sent is not tried again', () async {
    final s = await joinedStore();
    await finishDay(s, 3);
    reply = (_) => (status: 422, body: {'error': 'already_played'});
    expect(await s.submit(3), isFalse);
    expect(s.isSent(3), isTrue);
  });

  test('a cleared app gets its account and played days back', () async {
    final s = store();
    reply = (_) => (
      status: 200,
      body: {
        'account': {'id': 'p7', 'token': 't7', 'nickname': 'Kaplan'},
        'days': [3, 4],
      },
    );
    expect(await s.checkDevice(4), isTrue);
    expect(sent.single.uri.path, '/api/v1/device');
    expect(sent.single.body, {'device': _device});
    expect(s.account, (id: 'p7', token: 't7', nickname: 'Kaplan'));
    expect(s.playedOnDevice(4), isTrue);
    expect(s.playedOnDevice(5), isFalse);
    // Joined now: no more questions to the server.
    expect(await s.checkDevice(5), isFalse);
    expect(sent, hasLength(1));
  });

  test('the device is asked about once a day, offline again later', () async {
    final s = store();
    reply = (_) => throw const SocketException('offline');
    expect(await s.checkDevice(4), isFalse);
    reply = (_) => (status: 200, body: {'account': null, 'days': <int>[]});
    expect(await s.checkDevice(4), isFalse);
    expect(await s.checkDevice(4), isFalse);
    expect(sent, hasLength(2)); // the offline try, then one answer
    expect(s.joined, isFalse);
    expect(s.playedOnDevice(4), isFalse);
  });
}
