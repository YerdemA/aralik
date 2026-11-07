import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
      'hb': '1',
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

  test('a dropped connection comes back with the secret and resends', () async {
    final first = FakeChannel();
    final second = FakeChannel();
    final opened = <Uri>[];
    final service = DuelService(
      serviceUri: () => base,
      connect: (uri) async {
        opened.add(uri);
        return opened.length == 1 ? first : second;
      },
    );
    final match = DuelMatch();
    final session = await service.join(
      code: 'K7M2P',
      name: 'Ayşe',
      bankSize: 99,
      match: match,
    );
    Future<void> settle() => Future<void>.delayed(Duration.zero);
    void say(FakeChannel c, Map<String, Object?> m) =>
        c.incoming.add(jsonEncode(m));

    say(first, {
      't': 'start',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': ['a', 'b'],
      'questionMs': 15000,
      'rejoin': 'secret-1',
    });
    say(first, {'t': 'question', 'i': 0, 'ms': 15000});
    await settle();
    expect(match.rejoin, 'secret-1');

    // The network goes; the lock made meanwhile cannot be sent.
    await first.incoming.close();
    await settle();
    session.lock(0, low: 10, high: 20);
    await settle();
    expect(opened, hasLength(2));
    expect(opened.last.queryParameters['rejoin'], 'secret-1');
    expect(match.reconnecting, isTrue);
    expect(match.phase, DuelPhase.question);

    // Back: the room has no lock from us yet, so it is sent again.
    say(second, {
      't': 'resume',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': ['a', 'b'],
      'questionMs': 15000,
      'rejoin': 'secret-1',
      'index': 0,
      'phase': 'question',
      'ms': 9000,
      'results': <Object>[],
      'totals': [0, 0],
      'locked': [false, true],
      'away': null,
      'awayMs': null,
    });
    await settle();
    expect(match.reconnecting, isFalse);
    expect(match.timeLeft, const Duration(seconds: 9));
    expect(match.opponentLocked, isTrue);
    expect(second.sent, [DuelMessages.lock(0, low: 10, high: 20)]);
    await session.close();
  });

  testWidgets('gives up once the window has passed', (tester) async {
    var calls = 0;
    final first = FakeChannel();
    final service = DuelService(
      serviceUri: () => base,
      connect: (uri) async {
        calls++;
        if (calls == 1) return first;
        throw const SocketException('no network');
      },
    );
    final match = DuelMatch();
    await service.join(code: 'K7M2P', name: 'Ayşe', bankSize: 99, match: match);
    first.incoming
      ..add(
        jsonEncode({
          't': 'start',
          'you': 0,
          'names': ['Ayşe', 'Bora'],
          'questions': ['a'],
          'questionMs': 15000,
          'rejoin': 's',
        }),
      )
      ..add(jsonEncode({'t': 'question', 'i': 0, 'ms': 15000}));
    await tester.pump();
    await first.incoming.close();
    await tester.pump();
    expect(match.reconnecting, isTrue);
    await tester.pump(const Duration(seconds: 30));
    expect(match.reconnecting, isTrue);
    await tester.pump(duelReconnectWindow);
    expect(match.phase, DuelPhase.failed);
    expect(match.error, 'connection_lost');
    expect(calls, greaterThan(5));
  });

  test('waits 1, 2, 4, then 5 seconds between attempts', () {
    expect(
      [for (var k = 0; k < 6; k++) reconnectDelay(k).inSeconds],
      [1, 2, 4, 5, 5, 5],
    );
  });

  group('the real channel', () {
    late HttpServer server;
    late Uri uri;

    /// A room that says hello once and answers pings when [pong].
    Future<void> serve({required bool pong}) async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      uri = Uri.parse('ws://127.0.0.1:${server.port}/');
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add('{"t":"hello"}');
        socket.listen((m) {
          if (pong && m == '{"t":"ping"}') socket.add('{"t":"pong"}');
        });
      });
    }

    tearDown(() => server.close(force: true));

    test('pings and hides the pongs while the room answers', () async {
      await serve(pong: true);
      final channel = await webSocketChannel(
        uri,
        pingEvery: const Duration(milliseconds: 40),
        silenceLimit: const Duration(milliseconds: 300),
      );
      final got = <String>[];
      var done = false;
      channel.messages.listen(got.add, onDone: () => done = true);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(got, ['{"t":"hello"}']);
      expect(done, isFalse);
      await channel.close();
    });

    test('a silent room ends the connection: no network', () async {
      await serve(pong: false);
      final channel = await webSocketChannel(
        uri,
        pingEvery: const Duration(milliseconds: 40),
        silenceLimit: const Duration(milliseconds: 200),
      );
      final done = Completer<void>();
      channel.messages.listen((_) {}, onDone: done.complete);
      await done.future.timeout(const Duration(seconds: 2));
    });
  });

  test('a refusal closes the connection at once', () async {
    final channel = FakeChannel();
    final match = DuelMatch();
    final service = DuelService(
      serviceUri: () => base,
      connect: (_) async => channel,
    );
    await service.join(code: 'K7M2P', name: 'Ayşe', bankSize: 9, match: match);
    channel.incoming.add('{"t":"error","code":"no_room"}');
    await pumpEventQueue();
    expect(match.phase, DuelPhase.failed);
    expect(match.error, 'no_room');
    expect(channel.closed, isTrue);
  });

  test('going back with a secret, and giving up with it', () async {
    final uris = <Uri>[];
    final channels = <FakeChannel>[];
    final service = DuelService(
      serviceUri: () => base,
      connect: (uri) async {
        uris.add(uri);
        final c = FakeChannel();
        channels.add(c);
        return c;
      },
    );
    final match = DuelMatch();
    await service.join(
      code: 'K7M2P',
      name: 'Ayşe',
      bankSize: 9,
      match: match,
      rejoin: 's3cret',
    );
    expect(uris.last.queryParameters['rejoin'], 's3cret');
    expect(uris.last.queryParameters.containsKey('resign'), isFalse);
    expect(match.rejoin, 's3cret');
    // Dropped before the room answered: the app tries again.
    match.connectionLost();
    expect(match.reconnecting, isTrue);

    final giving = service.resign(
      code: 'K7M2P',
      rejoin: 's3cret',
      name: 'Ayşe',
    );
    await pumpEventQueue();
    expect(uris.last.queryParameters['rejoin'], 's3cret');
    expect(uris.last.queryParameters['resign'], '1');
    channels.last.incoming.add(
      '{"t":"end","totals":[0,0],"winner":0,"reason":"left"}',
    );
    await giving;
    expect(channels.last.closed, isTrue);
  });

  test('giving up from the match sends resign', () async {
    final channel = FakeChannel();
    final session = await DuelService(
      serviceUri: () => base,
      connect: (_) async => channel,
    ).join(code: 'K7M2P', name: 'Ayşe', bankSize: 9, match: DuelMatch());
    session.resign();
    expect(channel.sent.map(jsonDecode), [
      {'t': 'resign'},
    ]);
  });
}
