import 'dart:convert';

import 'package:aralik/core/tournament.dart';
import 'package:aralik/data/tournament_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'duel_client_test.dart' show FakeChannel;

void main() {
  late List<Uri> opened;
  late List<FakeChannel> channels;

  TournamentService service() => TournamentService(
    serviceUri: () => Uri.parse('https://lb.example/'),
    connect: (uri) async {
      opened.add(uri);
      final channel = FakeChannel();
      channels.add(channel);
      return channel;
    },
  );

  Map<String, Object?> roomMsg({bool away = false}) => {
    't': 'room',
    'code': 'K7M2P',
    'host': 1,
    'count': 5,
    'players': [
      {'id': 1, 'name': 'Ayşe'},
      {'id': 2, 'name': 'Bora', 'away': ?(away ? true : null)},
    ],
    'min': 3,
    'max': 8,
  };

  void say(FakeChannel c, Map<String, Object?> m) =>
      c.incoming.add(jsonEncode(m));

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    opened = [];
    channels = [];
  });

  test('a drop in the lobby goes back to the same seat', () async {
    final room = TournamentRoom();
    final session = await service().join(
      code: 'K7M2P',
      name: 'Ayşe',
      bankSize: 100,
      room: room,
    );
    say(channels[0], {'t': 'welcome', 'you': 1, 'rejoin': 's1'});
    say(channels[0], roomMsg());
    await flush();
    expect(room.phase, TournamentPhase.lobby);

    // The app was in the background; the connection is gone.
    await channels[0].incoming.close();
    await flush();
    expect(room.reconnecting, isTrue);
    expect(opened, hasLength(2));
    expect(opened[1].queryParameters['rejoin'], 's1');

    say(channels[1], {'t': 'welcome', 'you': 1, 'rejoin': 's1'});
    say(channels[1], roomMsg());
    await flush();
    expect(room.reconnecting, isFalse);
    expect(room.phase, TournamentPhase.lobby);
    expect(room.you, 1);
    await session.close();
  });

  test('a seat that is gone is taken again by name', () async {
    final room = TournamentRoom();
    final session = await service().join(
      code: 'K7M2P',
      name: 'Ayşe',
      bankSize: 100,
      room: room,
    );
    say(channels[0], {'t': 'welcome', 'you': 1, 'rejoin': 's1'});
    say(channels[0], roomMsg());
    await flush();
    await channels[0].incoming.close();
    await flush();

    // Away too long: the room forgot the secret.
    say(channels[1], {'t': 'error', 'code': 'rejoin_over'});
    await flush();
    expect(channels[1].closed, isTrue);
    expect(room.phase, isNot(TournamentPhase.failed));
    expect(opened, hasLength(3));
    expect(opened[2].queryParameters.containsKey('rejoin'), isFalse);
    expect(opened[2].queryParameters['name'], 'Ayşe');

    say(channels[2], {'t': 'welcome', 'you': 4, 'rejoin': 's4'});
    say(channels[2], roomMsg(away: true));
    await flush();
    expect(room.reconnecting, isFalse);
    expect(room.you, 4);
    expect(room.rejoin, 's4');
    expect(room.isAway(2), isTrue);
    await session.close();
  });
}
