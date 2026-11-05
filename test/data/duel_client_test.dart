import 'dart:async';
import 'dart:convert';

import 'package:aralik/core/duel.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [DuelChannel] the test drives: [incoming] is what the room says,
/// [sent] what the app said.
class FakeChannel implements DuelChannel {
  final incoming = StreamController<String>();
  final sent = <String>[];
  bool closed = false;

  @override
  Stream<String> get messages => incoming.stream;

  @override
  void send(String message) => sent.add(message);

  @override
  Future<void> close() async => closed = true;
}

void main() {
  final base = Uri.parse('https://lb.example/');

  test('creates a room', () async {
    final calls = <String>[];
    final service = DuelService(
      serviceUri: () => base,
      request: (method, uri, [body]) async {
        calls.add('$method $uri');
        return (status: 201, body: <String, Object?>{'code': 'K7M2P'});
      },
    );
    expect(service.isAvailable, isTrue);
    expect(await service.createRoom(), 'K7M2P');
    expect(calls, ['POST https://lb.example/v1/duel/rooms']);
  });

  test('room creation failures', () async {
    Future<JsonReply> busy(String m, Uri u, [Map<String, Object?>? b]) async =>
        (status: 503, body: <String, Object?>{'error': 'busy'});
    Future<JsonReply> offline(String m, Uri u, [Map<String, Object?>? b]) =>
        Future.error(Exception('no network'));
    await expectLater(
      DuelService(serviceUri: () => base, request: busy).createRoom(),
      throwsA(
        isA<DuelException>().having(
          (e) => e.failure,
          'failure',
          DuelFailure.server,
        ),
      ),
    );
    await expectLater(
      DuelService(serviceUri: () => base, request: offline).createRoom(),
      throwsA(
        isA<DuelException>().having(
          (e) => e.failure,
          'failure',
          DuelFailure.offline,
        ),
      ),
    );
    expect(DuelService(serviceUri: () => null).isAvailable, isFalse);
  });

  test('joins over a WebSocket and relays both ways', () async {
    final channel = FakeChannel();
    Uri? opened;
    final service = DuelService(
      serviceUri: () => base,
      connect: (uri) async {
        opened = uri;
        return channel;
      },
    );
    final match = DuelMatch();
    final session = await service.join(
      code: 'K7M2P',
      name: 'Ayşe Nur',
      bankSize: 1001,
      match: match,
    );
    expect(opened!.scheme, 'wss');
    expect(opened!.path, '/v1/duel/rooms/K7M2P');
    expect(opened!.queryParameters, {
      'v': '$duelProtocolVersion',
      'name': 'Ayşe Nur',
      'bank': '1001',
    });

    channel.incoming.add(jsonEncode({'t': 'waiting', 'code': 'K7M2P'}));
    await pumpEventQueue();
    expect(match.phase, DuelPhase.waiting);

    session
      ..lock(0, low: 5, high: 9)
      ..next(0);
    expect(channel.sent.map(jsonDecode), [
      {'t': 'lock', 'i': 0, 'low': 5, 'high': 9},
      {'t': 'next', 'i': 0},
    ]);

    await channel.incoming.close();
    await pumpEventQueue();
    expect(match.phase, DuelPhase.failed);
    expect(match.error, 'connection_lost');
  });

  test('closing on purpose is not a lost connection', () async {
    final channel = FakeChannel();
    final match = DuelMatch();
    final session = await DuelService(
      serviceUri: () => base,
      connect: (_) async => channel,
    ).join(code: 'K7M2P', name: 'Ayşe', bankSize: 1, match: match);
    await session.close();
    expect(channel.closed, isTrue);
    expect(match.phase, DuelPhase.connecting);
  });

  test('a failed connection is reported as offline', () async {
    final service = DuelService(
      serviceUri: () => base,
      connect: (_) => Future.error(Exception('refused')),
    );
    await expectLater(
      service.join(
        code: 'K7M2P',
        name: 'Ayşe',
        bankSize: 1,
        match: DuelMatch(),
      ),
      throwsA(isA<DuelException>()),
    );
  });

  group('random opponent', () {
    late FakeChannel channel;
    late List<Uri> opened;
    late DuelService service;

    setUp(() {
      channel = FakeChannel();
      opened = [];
      service = DuelService(
        serviceUri: () => base,
        connect: (uri) async {
          opened.add(uri);
          return channel;
        },
      );
    });

    test('waits in the lobby until matched', () async {
      final search = await service.findOpponent(name: 'Ayşe', bankSize: 9);
      expect(opened.single.path, '/v1/duel/random');
      expect(opened.single.scheme, 'wss');
      expect(opened.single.queryParameters['bank'], '9');
      channel.incoming.add(jsonEncode({'t': 'searching'}));
      channel.incoming.add(jsonEncode({'t': 'matched', 'code': 'K7M2P'}));
      expect(await search.code, 'K7M2P');
      await pumpEventQueue();
      expect(channel.closed, isTrue);
    });

    test('a refusal or a dropped lobby fails the search', () async {
      final refused = await service.findOpponent(name: 'Ayşe', bankSize: 9);
      channel.incoming.add(jsonEncode({'t': 'error', 'code': 'no_opponent'}));
      await expectLater(
        refused.code,
        throwsA(
          isA<DuelRefused>().having((e) => e.code, 'code', 'no_opponent'),
        ),
      );

      channel = FakeChannel();
      final dropped = await service.findOpponent(name: 'Ayşe', bankSize: 9);
      await channel.incoming.close();
      await expectLater(dropped.code, throwsA(isA<DuelException>()));
    });
  });
}
