import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/daily.dart';
import 'device_key.dart' as device;

/// Optional daily leaderboard (server/leaderboard, a Cloudflare Worker).
///
/// Nothing is sent until the player joins with a nickname. After that the
/// five locked intervals of each finished daily set are sent; the server
/// computes the score itself. Each day has its own board, so it starts
/// empty when the day's questions change.
///
/// Joining and sending also carry the device key (data/device_key.dart):
/// the server keeps one account per device, so reinstalling the app gives
/// the same account back and a day cannot be sent twice.

/// Reply of one JSON request: HTTP status and decoded body.
typedef JsonReply = ({int status, Object? body});

/// Sends one JSON request; throws on network failure.
typedef JsonRequest = Future<JsonReply> Function(
  String method,
  Uri uri, [
  Map<String, Object?>? body,
]);

typedef LeaderboardAccount = ({String id, String token, String nickname});

/// One locked daily interval as sent to the server; [low] and [high] are
/// null when time ran out before a guess.
typedef DailyInterval = ({String questionId, int? low, int? high});

/// A row of the board.
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.points,
    required this.hits,
    this.nickname,
    this.isMe = false,
  });

  final int rank;
  final int points;
  final int hits;

  /// Null for the player's own row outside the top (the app knows it).
  final String? nickname;
  final bool isMe;
}

/// One day's board.
@immutable
class LeaderboardBoard {
  const LeaderboardBoard({
    required this.day,
    required this.players,
    required this.top,
    this.me,
  });

  final int day;

  /// Players who sent a score for [day].
  final int players;

  /// The best players, best first (top 10 until enough have joined).
  final List<LeaderboardEntry> top;

  /// The player's own row, or null without a score on [day].
  final LeaderboardEntry? me;

  /// Whether the player's row is already among [top].
  bool get meInTop => top.any((e) => e.isMe);

  factory LeaderboardBoard.fromJson(Map<String, dynamic> json) {
    final me = json['me'] as Map<String, dynamic>?;
    return LeaderboardBoard(
      day: json['day'] as int,
      players: json['players'] as int,
      top: [
        for (final e in (json['top'] as List).cast<Map<String, dynamic>>())
          LeaderboardEntry(
            rank: e['rank'] as int,
            nickname: e['nickname'] as String,
            points: e['points'] as int,
            hits: e['hits'] as int,
            isMe: e['me'] == true,
          ),
      ],
      me: me == null
          ? null
          : LeaderboardEntry(
              rank: me['rank'] as int,
              points: me['points'] as int,
              hits: me['hits'] as int,
              isMe: true,
            ),
    );
  }
}

enum LeaderboardFailure {
  /// No connection, timeout or the server is unreachable.
  offline,
  nicknameInvalid,
  nicknameBlocked,
  nicknameTaken,
  rateLimited,

  /// The nickname changed less than three days ago
  /// ([LeaderboardException.retryAt] says when it can change again).
  renameWait,

  /// The account no longer exists on the server.
  unauthorized,

  /// The server refused the request for good (closed day, wrong set).
  rejected,

  /// Anything else; worth trying again later.
  server,
}

class LeaderboardException implements Exception {
  const LeaderboardException(this.failure, {this.retryAt});

  final LeaderboardFailure failure;

  /// For [LeaderboardFailure.renameWait]: when the nickname may change.
  final DateTime? retryAt;

  @override
  String toString() => 'LeaderboardException($failure)';
}

/// The player's leaderboard account, the intervals of recent daily sets
/// and which of them were sent (shared_preferences).
class LeaderboardStore extends ChangeNotifier {
  LeaderboardStore(
    this._prefs, {
    required this._serviceUri,
    JsonRequest? request,
    Future<String?> Function()? deviceKey,
  }) : _request = request ?? defaultJsonRequest,
       _deviceKey = deviceKey ?? device.deviceKey;

  /// For development: `--dart-define=LEADERBOARD_URL=https://…/` when the
  /// manifest does not name a server yet.
  static const _definedUrl = String.fromEnvironment('LEADERBOARD_URL');

  static const _idKey = 'lb_id';
  static const _tokenKey = 'lb_token';
  static const _nicknameKey = 'lb_nickname';
  static const _daysKey = 'lb_days';
  static String _answersKey(int day) => 'lb_answers_$day';
  static const _devicePlayedKey = 'lb_device_played';
  static const _deviceCheckedKey = 'lb_device_checked';
  static String _sentKey(int day) => 'lb_sent_$day';

  /// Days whose intervals are kept, counting back from the newest.
  static const _keepDays = 3;

  final SharedPreferences _prefs;
  final Uri? Function() _serviceUri;
  final JsonRequest _request;
  final Future<String?> Function() _deviceKey;
  final Set<int> _sending = {};

  /// The server, or null while the leaderboard is not available.
  Uri? get serviceUri {
    final uri =
        _serviceUri() ??
        (_definedUrl.isEmpty ? null : Uri.tryParse(_definedUrl));
    if (uri == null) return null;
    // Resolve endpoints below the given path, not beside it.
    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }

  bool get isAvailable => serviceUri != null;

  LeaderboardAccount? get account {
    final id = _prefs.getString(_idKey);
    final token = _prefs.getString(_tokenKey);
    final nickname = _prefs.getString(_nicknameKey);
    if (id == null || token == null || nickname == null) return null;
    return (id: id, token: token, nickname: nickname);
  }

  bool get joined => account != null;

  /// Keeps a locked daily interval, joined or not, so a player who joins
  /// after finishing the set can still send it. Stays on the device.
  Future<void> recordDailyInterval(int day, DailyInterval interval) async {
    final list = [...dailyIntervals(day), interval];
    final days = {..._days, day};
    final newest = days.reduce((a, b) => a > b ? a : b);
    for (final old in days.where((d) => d <= newest - _keepDays).toList()) {
      days.remove(old);
      await _prefs.remove(_answersKey(old));
      await _prefs.remove(_sentKey(old));
    }
    await _prefs.setString(
      _answersKey(day),
      jsonEncode([
        for (final i in list) [i.questionId, i.low, i.high],
      ]),
    );
    await _prefs.setStringList(_daysKey, [for (final d in days) '$d']);
  }

  Set<int> get _days => {
    for (final d in _prefs.getStringList(_daysKey) ?? const <String>[])
      ?int.tryParse(d),
  };

  /// Intervals kept for [day], in order.
  List<DailyInterval> dailyIntervals(int day) {
    final raw = _prefs.getString(_answersKey(day));
    if (raw == null) return const [];
    try {
      return [
        for (final e in (jsonDecode(raw) as List).cast<List<dynamic>>())
          (questionId: e[0] as String, low: e[1] as int?, high: e[2] as int?),
      ];
    } on Object {
      return const [];
    }
  }

  /// Whether this device sent [day]'s set to the server before, by the
  /// server's word (see [checkDevice]): its data was cleared since, so the
  /// set must not be played again.
  bool playedOnDevice(int day) =>
      (_prefs.getStringList(_devicePlayedKey) ?? const []).contains('$day');

  /// After the app's data was cleared there is no account here, yet the
  /// server may know this device. Asks it once a day while not joined:
  /// gets the account back (returns true) and the days the device already
  /// sent. The server stores nothing for a device that never joined.
  /// Never throws; offline it tries again on the next launch.
  Future<bool> checkDevice(int today) async {
    if (joined || !isAvailable) return false;
    if (_prefs.getInt(_deviceCheckedKey) == today) return false;
    final key = await _deviceKey();
    if (key == null) return false;
    final Map<String, dynamic> body;
    try {
      body = await _call('POST', 'v1/device', {
        'device': key,
      }) as Map<String, dynamic>;
    } on Object {
      return false;
    }
    await _prefs.setInt(_deviceCheckedKey, today);
    await _prefs.setStringList(_devicePlayedKey, [
      for (final d in (body['days'] as List? ?? const [])) '$d',
    ]);
    final account = body['account'];
    if (account is Map<String, dynamic>) {
      await _prefs.setString(_idKey, account['id'] as String);
      await _prefs.setString(_tokenKey, account['token'] as String);
      await _prefs.setString(_nicknameKey, account['nickname'] as String);
    }
    notifyListeners();
    return account is Map;
  }

  /// Whether [day]'s score reached the server (or was refused for good).
  bool isSent(int day) => _prefs.getBool(_sentKey(day)) ?? false;

  /// Joins with [nickname]. Returns true when the server gave back this
  /// device's earlier account (with its own nickname) instead of making a
  /// new one. Throws [LeaderboardException].
  Future<bool> join(String nickname) async {
    final reply = await _call('POST', 'v1/register', {
      'nickname': nickname,
      'device': await _deviceKey(),
    });
    final body = reply as Map<String, dynamic>;
    await _prefs.setString(_idKey, body['id'] as String);
    await _prefs.setString(_tokenKey, body['token'] as String);
    await _prefs.setString(_nicknameKey, body['nickname'] as String);
    notifyListeners();
    return body['restored'] == true;
  }

  /// Changes the nickname. Throws [LeaderboardException].
  Future<void> rename(String nickname) async {
    final reply = await _authed('v1/rename', {'nickname': nickname});
    await _prefs.setString(
      _nicknameKey,
      (reply as Map<String, dynamic>)['nickname'] as String,
    );
    notifyListeners();
  }

  /// Deletes the account and its scores on the server, then forgets it
  /// here. Throws [LeaderboardException] (except when it is already gone).
  Future<void> leave() async {
    try {
      await _authed('v1/delete', const {});
    } on LeaderboardException catch (e) {
      if (e.failure != LeaderboardFailure.unauthorized) rethrow;
    }
    await _forgetAccount();
  }

  /// Sends [day]'s five intervals if joined, finished and not sent yet.
  /// Returns whether the score is on the server now. Network failures
  /// leave it for a later try; a refusal is final.
  Future<bool> submit(int day) async {
    if (isSent(day)) return true;
    final intervals = dailyIntervals(day);
    if (!joined ||
        !isAvailable ||
        intervals.length != questionsPerDay ||
        !_sending.add(day)) {
      return false;
    }
    try {
      await _authed('v1/submit', {
        'device': await _deviceKey(),
        'day': day,
        'answers': [
          for (final i in intervals)
            {'q': i.questionId, 'low': i.low, 'high': i.high},
        ],
      });
      await _prefs.setBool(_sentKey(day), true);
      notifyListeners();
      return true;
    } on LeaderboardException catch (e) {
      if (e.failure == LeaderboardFailure.rejected) {
        await _prefs.setBool(_sentKey(day), true); // never accepted: stop
      }
      return false;
    } finally {
      _sending.remove(day);
    }
  }

  /// Sends every finished, unsent set of [today] and yesterday (the server
  /// accepts no older days). Never throws.
  Future<void> submitPending(int today) async {
    for (final day in [today - 1, today]) {
      try {
        await submit(day);
      } on Object {
        // try again on the next launch
      }
    }
  }

  /// [day]'s board. Throws [LeaderboardException].
  Future<LeaderboardBoard> fetchBoard(int day) async {
    final id = account?.id;
    final reply = await _call(
      'GET',
      'v1/day/$day${id == null ? '' : '?player=${Uri.encodeQueryComponent(id)}'}',
    );
    try {
      return LeaderboardBoard.fromJson(reply as Map<String, dynamic>);
    } on Object {
      throw const LeaderboardException(LeaderboardFailure.server);
    }
  }

  Future<Object?> _authed(String path, Map<String, Object?> body) async {
    final a = account;
    if (a == null) {
      throw const LeaderboardException(LeaderboardFailure.unauthorized);
    }
    try {
      return await _call('POST', path, {...body, 'id': a.id, 'token': a.token});
    } on LeaderboardException catch (e) {
      // Deleted on the server (or the database was reset): join again.
      if (e.failure == LeaderboardFailure.unauthorized) await _forgetAccount();
      rethrow;
    }
  }

  Future<void> _forgetAccount() async {
    await _prefs.remove(_idKey);
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_nicknameKey);
    for (final d in _days) {
      await _prefs.remove(_sentKey(d));
    }
    notifyListeners();
  }

  Future<Object?> _call(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final base = serviceUri;
    if (base == null) {
      throw const LeaderboardException(LeaderboardFailure.offline);
    }
    final JsonReply reply;
    try {
      reply = await _request(method, base.resolve(path), body);
    } on Object {
      throw const LeaderboardException(LeaderboardFailure.offline);
    }
    if (reply.status >= 200 && reply.status < 300) return reply.body;
    final error = reply.body is Map ? (reply.body as Map)['error'] : null;
    if (error == 'rename_wait') {
      final at = (reply.body as Map)['retry_at'];
      throw LeaderboardException(
        LeaderboardFailure.renameWait,
        retryAt: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null,
      );
    }
    throw LeaderboardException(switch ((reply.status, error)) {
      (_, 'invalid_nickname') => LeaderboardFailure.nicknameInvalid,
      (_, 'blocked_nickname') => LeaderboardFailure.nicknameBlocked,
      (_, 'nickname_taken') => LeaderboardFailure.nicknameTaken,
      (429, _) => LeaderboardFailure.rateLimited,
      (401, _) => LeaderboardFailure.unauthorized,
      (400 || 422, _) => LeaderboardFailure.rejected,
      _ => LeaderboardFailure.server,
    });
  }
}

/// JSON over [HttpClient] with short timeouts. No package needed.
Future<JsonReply> defaultJsonRequest(
  String method,
  Uri uri, [
  Map<String, Object?>? body,
]) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..userAgent = 'Kabaca-Android';
  try {
    final request = await client.openUrl(method, uri);
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close().timeout(const Duration(seconds: 15));
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 15));
    Object? json;
    try {
      json = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      json = null;
    }
    return (status: response.statusCode, body: json);
  } finally {
    client.close(force: true);
  }
}
