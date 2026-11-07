import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/duel.dart';
import 'leaderboard.dart';

/// A text connection to a duel room. The real one is a WebSocket; tests
/// pass a fake.
abstract interface class DuelChannel {
  Stream<String> get messages;
  void send(String message);
  Future<void> close();
}

/// Opens a [DuelChannel] to [uri]; throws when it cannot connect.
typedef DuelConnector = Future<DuelChannel> Function(Uri uri);

enum DuelFailure {
  /// No connection or the server is unreachable.
  offline,

  /// The server could not open a room right now.
  server,
}

class DuelException implements Exception {
  const DuelException(this.failure);
  final DuelFailure failure;

  @override
  String toString() => 'DuelException($failure)';
}

/// Talks to the duel rooms of the leaderboard server (same Worker, see
/// server/leaderboard/src/duel.js). No account: a room code and a display
/// name are all it needs.
class DuelService {
  DuelService({
    required this.serviceUri,
    JsonRequest? request,
    DuelConnector? connect,
  }) : _request = request ?? defaultJsonRequest,
       _connect = connect ?? webSocketChannel;

  /// The server (manifest's `leaderboard` field), or null without one.
  final Uri? Function() serviceUri;
  final JsonRequest _request;
  final DuelConnector _connect;

  bool get isAvailable => serviceUri() != null;

  /// Opens a room for a friend and returns its code.
  Future<String> createRoom() async {
    final base = serviceUri();
    if (base == null) throw const DuelException(DuelFailure.offline);
    final JsonReply reply;
    try {
      reply = await _request('POST', base.resolve('v1/duel/rooms'));
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

  /// Waits in the lobby for a random opponent.
  Future<DuelSearch> findOpponent({
    required String name,
    required int bankSize,
  }) async {
    final channel = await _open('v1/duel/random', name, bankSize);
    return DuelSearch._(channel);
  }

  Future<DuelChannel> _open(
    String path,
    String name,
    int bankSize, {
    String? rejoin,
  }) async {
    final base = serviceUri();
    if (base == null) throw const DuelException(DuelFailure.offline);
    final http = base.resolve(path);
    final uri = http.replace(
      scheme: http.scheme == 'http' ? 'ws' : 'wss',
      queryParameters: {
        'v': '$duelProtocolVersion',
        'name': name,
        'bank': '$bankSize',
        'rejoin': ?rejoin,
      },
    );
    try {
      return await _connect(uri);
    } on WebSocketException {
      // The server answered but refused the upgrade (e.g. an older server
      // without this route): not the player's connection.
      throw const DuelException(DuelFailure.server);
    } on Object {
      throw const DuelException(DuelFailure.offline);
    }
  }

  /// Joins room [code] as [name] and feeds its events into [match].
  ///
  /// [bankSize] is how many questions this app's bank holds; the room only
  /// picks questions both players have. Returns the open [DuelSession], or
  /// throws [DuelException] when the connection cannot be made.
  Future<DuelSession> join({
    required String code,
    required String name,
    required int bankSize,
    required DuelMatch match,
  }) async {
    final path = 'v1/duel/rooms/$code';
    final channel = await _open(path, name, bankSize);
    return DuelSession._(
      channel,
      match,
      (token) => _open(path, name, bankSize, rejoin: token),
    );
  }
}

/// The room or lobby refused: [code] as in [DuelError] (also
/// `no_opponent` when nobody turned up).
class DuelRefused implements Exception {
  const DuelRefused(this.code);
  final String code;

  @override
  String toString() => 'DuelRefused($code)';
}

/// A search for a random opponent in the lobby. [code] completes with the
/// room both players join, or fails with [DuelRefused] / [DuelException].
class DuelSearch {
  DuelSearch._(this._channel) {
    _subscription = _channel.messages.listen(
      (text) {
        final m = _decode(text);
        switch (m?['t']) {
          case 'matched':
            final code = m!['code'];
            if (code is String) _finish(code);
          case 'error':
            _fail(DuelRefused('${m!['code']}'));
        }
      },
      onDone: () => _fail(const DuelException(DuelFailure.offline)),
      onError: (_) => _fail(const DuelException(DuelFailure.offline)),
      cancelOnError: true,
    );
  }

  final DuelChannel _channel;
  late final StreamSubscription<String> _subscription;
  final _code = Completer<String>();

  Future<String> get code => _code.future;

  static Map<String, dynamic>? _decode(String text) {
    try {
      final m = jsonDecode(text);
      return m is Map<String, dynamic> ? m : null;
    } on FormatException {
      return null;
    }
  }

  void _finish(String code) {
    if (!_code.isCompleted) _code.complete(code);
    cancel();
  }

  void _fail(Object error) {
    if (!_code.isCompleted) _code.completeError(error);
  }

  /// Stops searching (leaving the screen). [code] then never completes.
  Future<void> cancel() async {
    await Future.wait([_subscription.cancel(), _channel.close()]);
  }
}

/// Waits between attempts to come back: 1, 2, 4, then every 5 seconds.
Duration reconnectDelay(int attempt) =>
    Duration(seconds: attempt >= 3 ? 5 : 1 << attempt);

/// An open duel: forwards the room's events to [match] and sends this
/// player's locks. When the connection drops in play it comes back by
/// itself within [duelReconnectWindow] (the room keeps the seat), and
/// sends again a lock or "next" the room did not get.
class DuelSession {
  DuelSession._(this._channel, this.match, this._reopen) {
    _listen(_channel);
  }

  DuelChannel _channel;
  final DuelMatch match;
  final Future<DuelChannel> Function(String rejoin) _reopen;
  StreamSubscription<String>? _subscription;
  bool _closed = false;
  bool _reconnecting = false;

  ({int index, int? low, int? high})? _lastLock;
  int? _lastNext;

  void _listen(DuelChannel channel) {
    _subscription = channel.messages.listen(
      (text) {
        final event = DuelEvent.parse(text);
        if (event == null) return;
        match.handle(event);
        if (event is DuelResume) _sendAgain();
      },
      onDone: () => _lost(channel),
      onError: (_) => _lost(channel),
      cancelOnError: true,
    );
  }

  void _lost(DuelChannel channel) {
    if (_closed || !identical(channel, _channel)) return;
    match.connectionLost();
    if (match.reconnecting) _reconnect();
  }

  Future<void> _reconnect() async {
    if (_reconnecting) return;
    _reconnecting = true;
    var waited = Duration.zero;
    for (var attempt = 0; !_closed && match.reconnecting; attempt++) {
      final token = match.rejoin;
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
    if (!_closed && match.reconnecting) match.reconnectFailed();
  }

  /// After coming back: what the room missed while the connection was gone.
  void _sendAgain() {
    final lock = _lastLock;
    if (lock != null &&
        match.phase == DuelPhase.question &&
        match.index == lock.index &&
        !match.myLocked) {
      _send(DuelMessages.lock(lock.index, low: lock.low, high: lock.high));
    }
    if (_lastNext != null &&
        match.phase == DuelPhase.reveal &&
        match.index == _lastNext) {
      _send(DuelMessages.next(_lastNext!));
    }
  }

  void lock(int index, {int? low, int? high}) {
    _lastLock = (index: index, low: low, high: high);
    _send(DuelMessages.lock(index, low: low, high: high));
  }

  void next(int index) {
    _lastNext = index;
    _send(DuelMessages.next(index));
  }

  void _send(String message) {
    if (_closed || match.reconnecting) return;
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

/// [DuelChannel] over dart:io's WebSocket. No package needed.
Future<DuelChannel> webSocketChannel(Uri uri) async {
  final socket = await WebSocket.connect(uri.toString())
      .timeout(const Duration(seconds: 10));
  socket.pingInterval = const Duration(seconds: 20);
  return _WebSocketChannel(socket);
}

class _WebSocketChannel implements DuelChannel {
  _WebSocketChannel(this._socket);

  final WebSocket _socket;

  @override
  Stream<String> get messages => _socket.where((m) => m is String).cast();

  @override
  void send(String message) => _socket.add(message);

  @override
  Future<void> close() => _socket.close();
}
