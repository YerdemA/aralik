import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/duel.dart';
import 'leaderboard.dart';
import 'net.dart';

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

  /// Opens a room for a friend and returns its code; a math duel's room
  /// with [math].
  Future<String> createRoom({bool math = false}) async {
    final base = serviceUri();
    if (base == null) throw const DuelException(DuelFailure.offline);
    final JsonReply reply;
    try {
      reply = await _request(
        'POST',
        base.resolve(math ? 'v1/duel/rooms?mode=math' : 'v1/duel/rooms'),
      );
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

  /// Waits in the lobby for a random opponent (for a math duel with
  /// [math]: a lobby of its own).
  Future<DuelSearch> findOpponent({
    required String name,
    required int bankSize,
    bool math = false,
  }) async {
    final channel = await _open(
      'v1/duel/random',
      name,
      bankSize,
      mode: math ? 'math' : null,
    );
    return DuelSearch._(channel);
  }

  Future<DuelChannel> _open(
    String path,
    String name,
    int bankSize, {
    String? rejoin,
    bool resign = false,
    String? mode,
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
        if (resign) 'resign': '1',
        // This app pings (see webSocketChannel): the room may close the
        // connection when the pings stop.
        'hb': '1',
        // This app knows rematches.
        'rm': '1',
        // This app can play math duels.
        'math': '1',
        'mode': ?mode,
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
  /// picks questions both players have. With [rejoin] (this player's
  /// secret, kept by [PendingMatchStore]) it goes back to a duel it left
  /// instead. Returns the open [DuelSession], or throws [DuelException]
  /// when the connection cannot be made.
  Future<DuelSession> join({
    required String code,
    required String name,
    required int bankSize,
    required DuelMatch match,
    String? rejoin,
  }) async {
    final path = 'v1/duel/rooms/$code';
    if (rejoin != null) match.expectRejoin(code, rejoin);
    final channel = await _open(path, name, bankSize, rejoin: rejoin);
    return DuelSession._(
      channel,
      match,
      (token) => _open(path, name, bankSize, rejoin: token),
    );
  }

  /// Gives up a duel this player left (the app was closed, or they quit):
  /// the opponent wins at once instead of waiting. Best effort: offline,
  /// the room ends it by itself when the time to come back runs out.
  Future<void> resign({
    required String code,
    required String rejoin,
    required String name,
  }) async {
    final DuelChannel channel;
    try {
      channel = await _open(
        'v1/duel/rooms/$code',
        name,
        1,
        rejoin: rejoin,
        resign: true,
      );
    } on Object {
      return;
    }
    // The room answers with the end (or an error); then it is done.
    try {
      await channel.messages.first.timeout(const Duration(seconds: 5));
    } on Object {
      // nothing more to do
    }
    await channel.close();
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
        // A rematch starts afresh: nothing of the last duel is sent again.
        if (event is DuelStart) {
          _lastLock = null;
          _lastNext = null;
        }
        match.handle(event);
        if (event is DuelResume) _sendAgain();
        // Refused or over: the room closes the connection anyway, but may
        // take a while; nothing more will come.
        if (event is DuelError) unawaited(close());
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

  /// Gives up: the opponent wins at once.
  void resign() => _send(DuelMessages.resign());

  /// After the end: asks for a rematch, or accepts the opponent's.
  void rematch() {
    if (match.askRematch()) _send(DuelMessages.rematch());
  }

  /// After the end: no rematch.
  void declineRematch() {
    if (match.declineRematch()) _send(DuelMessages.rematchNo());
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

/// How often the app pings the room, and how long without a word from it
/// (a pong or anything else) means the connection is dead. A phone that
/// loses its network does not close its socket, so silence is the only
/// sign; the room watches for the pings the same way
/// (server/leaderboard/src/liveness.js, PING_EVERY_MS and STALE_MS).
const Duration duelPingEvery = Duration(seconds: 3);
const Duration duelSilenceLimit = Duration(seconds: 9);
const String _ping = '{"t":"ping"}';
const String _pong = '{"t":"pong"}';

/// [DuelChannel] over dart:io's WebSocket. No package needed. Pings every
/// [duelPingEvery] and ends [messages] when the room has been silent for
/// [duelSilenceLimit], so a lost network is noticed in seconds.
Future<DuelChannel> webSocketChannel(
  Uri uri, {
  Duration pingEvery = duelPingEvery,
  Duration silenceLimit = duelSilenceLimit,
}) async {
  final socket = await connectWebSocket(uri);
  return _WebSocketChannel(socket, silenceLimit)..start(pingEvery);
}

class _WebSocketChannel implements DuelChannel {
  _WebSocketChannel(this._socket, this._silenceLimit) {
    _subscription = _socket.listen(
      (m) {
        _heard = DateTime.now();
        if (m is String && m != _pong) _messages.add(m);
      },
      onDone: _end,
      onError: (Object e) {
        if (!_messages.isClosed) _messages.addError(e);
        _end();
      },
      cancelOnError: true,
    );
  }

  void start(Duration pingEvery) {
    _pinger = Timer.periodic(pingEvery, (_) => _beat());
  }

  final WebSocket _socket;
  final Duration _silenceLimit;
  final _messages = StreamController<String>();
  late final StreamSubscription<dynamic> _subscription;
  Timer? _pinger;
  DateTime _heard = DateTime.now();

  void _beat() {
    // Also catches up after the app was frozen in the background.
    if (DateTime.now().difference(_heard) > _silenceLimit) {
      _abandon();
      return;
    }
    try {
      _socket.add(_ping);
    } on Object {
      _abandon();
    }
  }

  void _end() {
    _pinger?.cancel();
    if (!_messages.isClosed) _messages.close();
  }

  /// The connection is dead: let go of it without waiting for the network.
  void _abandon() {
    _end();
    unawaited(_subscription.cancel());
    unawaited(_closeSocket());
  }

  Future<void> _closeSocket() async {
    try {
      await _socket.close().timeout(const Duration(seconds: 2));
    } on Object {
      // dead anyway
    }
  }

  @override
  Stream<String> get messages => _messages.stream;

  @override
  void send(String message) => _socket.add(message);

  @override
  Future<void> close() async {
    _end();
    await _closeSocket();
  }
}
