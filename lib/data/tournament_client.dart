import 'dart:async';
import 'dart:io';

import '../core/duel.dart';
import '../core/tournament.dart';
import 'duel_client.dart';
import 'leaderboard.dart';

/// Talks to the tournament rooms of the leaderboard server (same Worker,
/// server/leaderboard/src/tournament.js). Uses the duel's connection
/// pieces; no account, a display name and a room code.
class TournamentService {
  TournamentService({
    required this.serviceUri,
    JsonRequest? request,
    DuelConnector? connect,
  }) : _request = request ?? defaultJsonRequest,
       _connect = connect ?? webSocketChannel;

  final Uri? Function() serviceUri;
  final JsonRequest _request;
  final DuelConnector _connect;

  bool get isAvailable => serviceUri() != null;

  /// Opens a room and returns its code; the first to join it hosts.
  Future<String> createRoom() async {
    final base = serviceUri();
    if (base == null) throw const DuelException(DuelFailure.offline);
    final JsonReply reply;
    try {
      reply = await _request('POST', base.resolve('v1/tournament/rooms'));
    } on Object {
      throw const DuelException(DuelFailure.offline);
    }
    final body = reply.body;
    final code = body is Map ? body['code'] : null;
    if (reply.status != 201 || code is! String) {
      throw const DuelException(DuelFailure.server);
    }
    return code;
  }

  /// Joins room [code] as [name] and feeds its events into [room]. With
  /// [rejoin] (this player's secret, kept by [PendingMatchStore]) it goes
  /// back to a match it left instead.
  Future<TournamentSession> join({
    required String code,
    required String name,
    required int bankSize,
    required TournamentRoom room,
    String? rejoin,
  }) async {
    Future<DuelChannel> open({String? rejoin}) async {
      final base = serviceUri();
      if (base == null) throw const DuelException(DuelFailure.offline);
      final http = base.resolve('v1/tournament/rooms/$code');
      final uri = http.replace(
        scheme: http.scheme == 'http' ? 'ws' : 'wss',
        queryParameters: {
          'v': '$tournamentProtocolVersion',
          'name': name,
          'bank': '$bankSize',
          'rejoin': ?rejoin,
          // This app pings (see webSocketChannel).
          'hb': '1',
        },
      );
      try {
        return await _connect(uri);
      } on WebSocketException {
        throw const DuelException(DuelFailure.server);
      } on Object {
        throw const DuelException(DuelFailure.offline);
      }
    }

    if (rejoin != null) room.expectRejoin(code, rejoin);
    final channel = await open(rejoin: rejoin);
    return TournamentSession._(channel, room, (token) => open(rejoin: token));
  }
}

/// An open room: forwards its events to [room] and sends this player's
/// moves. When the connection drops mid-match it comes back by itself
/// (the room keeps the player until the match ends) and sends again a lock
/// or "next" the room did not get.
class TournamentSession {
  TournamentSession._(this._channel, this.room, this._reopen) {
    _listen(_channel);
  }

  DuelChannel _channel;
  final TournamentRoom room;
  final Future<DuelChannel> Function(String rejoin) _reopen;
  StreamSubscription<String>? _subscription;
  bool _closed = false;
  bool _reconnecting = false;

  ({int index, int? low, int? high})? _lastLock;
  int? _lastNext;

  void _listen(DuelChannel channel) {
    _subscription = channel.messages.listen(
      (text) {
        final event = TournamentEvent.parse(text);
        if (event == null) return;
        room.handle(event);
        if (event is TournamentResume) _sendAgain();
        // Refused or removed: nothing more will come, and the room may take
        // a while to close the connection.
        if (event is TournamentError || event is TournamentKicked) {
          unawaited(close());
        }
      },
      onDone: () => _lost(channel),
      onError: (_) => _lost(channel),
      cancelOnError: true,
    );
  }

  void _lost(DuelChannel channel) {
    if (_closed || !identical(channel, _channel)) return;
    room.connectionLost();
    if (room.reconnecting) _reconnect();
  }

  Future<void> _reconnect() async {
    if (_reconnecting) return;
    _reconnecting = true;
    var waited = Duration.zero;
    for (var attempt = 0; !_closed && room.reconnecting; attempt++) {
      final token = room.rejoin;
      if (token == null) break;
      try {
        final channel = await _reopen(token);
        if (_closed) {
          await channel.close();
          return;
        }
        final old = _subscription;
        _channel = channel;
        _listen(channel);
        unawaited(old?.cancel());
        _reconnecting = false;
        return;
      } on Object {
        // not yet: wait and try again
      }
      final wait = reconnectDelay(attempt);
      waited += wait;
      if (waited >= duelReconnectWindow) break;
      await Future<void>.delayed(wait);
    }
    _reconnecting = false;
    if (!_closed && room.reconnecting) room.reconnectFailed();
  }

  void _sendAgain() {
    final lock = _lastLock;
    if (lock != null &&
        room.phase == TournamentPhase.question &&
        room.index == lock.index &&
        !room.myLocked) {
      _send(
        TournamentMessages.lock(lock.index, low: lock.low, high: lock.high),
      );
    }
    if (_lastNext != null &&
        room.phase == TournamentPhase.reveal &&
        room.index == _lastNext) {
      _send(TournamentMessages.next(_lastNext!));
    }
  }

  void setCount(int n) => _send(TournamentMessages.count(n));
  void kick(int id) => _send(TournamentMessages.kick(id));
  void start() => _send(TournamentMessages.start());

  void lock(int index, {int? low, int? high}) {
    _lastLock = (index: index, low: low, high: high);
    _send(TournamentMessages.lock(index, low: low, high: high));
  }

  void next(int index) {
    _lastNext = index;
    _send(TournamentMessages.next(index));
  }

  void _send(String message) {
    if (_closed || room.reconnecting) return;
    try {
      _channel.send(message);
    } on Object {
      _lost(_channel);
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait([?_subscription?.cancel(), _channel.close()]);
  }
}
