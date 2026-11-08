import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/strings.dart';
import 'content_sync.dart';
import 'net.dart';

/// One step of the connection test (Ayarlar → Bağlantı testi).
enum CheckKind { proxy, dns, direct, https, sni, content, webSocket }

enum CheckStatus { running, ok, warn, fail }

class CheckResult {
  const CheckResult(this.kind, this.status, this.detail, {this.failure});

  final CheckKind kind;
  final CheckStatus status;

  /// Short Turkish text shown under the step.
  final String detail;

  /// Why it failed, when it did.
  final NetFailure? failure;
}

/// The step's name on screen.
String checkTitle(CheckKind kind) => switch (kind) {
  CheckKind.proxy => AppStrings.netCheckProxy,
  CheckKind.dns => AppStrings.netCheckDns,
  CheckKind.direct => AppStrings.netCheckDirect,
  CheckKind.https => AppStrings.netCheckHttps,
  CheckKind.sni => AppStrings.netCheckSni,
  CheckKind.content => AppStrings.netCheckContent,
  CheckKind.webSocket => AppStrings.netCheckSocket,
};

/// [failure] in a few words.
String failureText(NetFailure failure) => switch (failure) {
  NetFailure.dns => AppStrings.netFailDns,
  NetFailure.timeout => AppStrings.netFailTimeout,
  NetFailure.refused => AppStrings.netFailRefused,
  NetFailure.tls => AppStrings.netFailTls,
  NetFailure.blocked => AppStrings.netFailBlocked,
  NetFailure.other => AppStrings.netFailOther,
};

/// What the test concludes, from the finished [results]: the first thing
/// that explains why the leaderboard or duels would not work here.
String checkVerdict(List<CheckResult> results) {
  CheckResult? of(CheckKind kind) =>
      results.where((r) => r.kind == kind).firstOrNull;
  final https = of(CheckKind.https);
  final socket = of(CheckKind.webSocket);
  final dns = of(CheckKind.dns);
  final proxy = of(CheckKind.proxy);
  if (dns?.status == CheckStatus.fail) return AppStrings.netVerdictDns;
  if (https?.status == CheckStatus.fail) {
    if (https!.failure == NetFailure.tls &&
        of(CheckKind.sni)?.status == CheckStatus.ok) {
      return AppStrings.netVerdictName;
    }
    return switch (https.failure) {
      NetFailure.tls => AppStrings.netVerdictTls,
      NetFailure.blocked => AppStrings.netVerdictBlocked,
      _ => AppStrings.netVerdictHttps,
    };
  }
  if (socket?.status == CheckStatus.fail) return AppStrings.netVerdictSocket;
  if (socket?.status == CheckStatus.warn) return AppStrings.netVerdictUnstable;
  if (proxy?.status == CheckStatus.warn) return AppStrings.netVerdictProxy;
  return AppStrings.netVerdictOk;
}

/// The results as plain text to copy and send to the developer.
String checkReport(List<CheckResult> results, String verdict) {
  final lines = [
    for (final r in results)
      '${switch (r.status) {
            CheckStatus.ok => '✓',
            CheckStatus.warn => '!',
            CheckStatus.fail => '✗',
            CheckStatus.running => '…',
          }} ${checkTitle(r.kind)}: ${r.detail}'
          '${r.failure == null ? '' : ' [${r.failure!.name}]'}',
    verdict,
  ];
  return lines.join('\n');
}

/// Runs the steps against the leaderboard server at [service] one by one
/// and reports each on [results]. Nothing is sent but the requests
/// themselves; the server only answers.
class ConnectionCheck extends ChangeNotifier {
  ConnectionCheck(this.service);

  final Uri service;
  final List<CheckResult> results = [];
  bool _running = false;
  bool _disposed = false;

  bool get running => _running;

  /// How long the WebSocket step keeps pinging.
  static const socketFor = Duration(seconds: 15);

  Future<void> run() async {
    if (_running) return;
    _running = true;
    results.clear();
    _notify();
    final proxy = await systemProxy();
    _add(
      CheckResult(
        CheckKind.proxy,
        proxy == null ? CheckStatus.ok : CheckStatus.warn,
        proxy ?? AppStrings.netNoProxy,
      ),
    );
    final addresses = await _step(CheckKind.dns, _lookup);
    if (addresses != null) {
      await _step(
        CheckKind.direct,
        () => _direct(addresses, viaProxy: proxy != null),
      );
    }
    await _step(CheckKind.https, _https);
    final https = results.last;
    final v4 = addresses
        ?.where((a) => a.type == InternetAddressType.IPv4)
        .firstOrNull;
    if (https.failure == NetFailure.tls && v4 != null) {
      await _step(CheckKind.sni, () => _otherName(v4));
    }
    await _step(CheckKind.content, _content);
    await _step(CheckKind.webSocket, _webSocket);
    _running = false;
    _notify();
  }

  /// Runs [body], which returns its value and a detail (or a warning by
  /// throwing [_Warn]); a thrown error fails the step.
  Future<T?> _step<T>(
    CheckKind kind,
    Future<(T, String)> Function() body,
  ) async {
    _add(CheckResult(kind, CheckStatus.running, AppStrings.netChecking));
    final watch = Stopwatch()..start();
    try {
      final (value, detail) = await body();
      _replace(CheckResult(kind, CheckStatus.ok, '$detail · ${_ms(watch)}'));
      return value;
    } on _Warn catch (w) {
      _replace(CheckResult(kind, CheckStatus.warn, w.detail));
    } on Object catch (e) {
      final failure = classifyNetError(e);
      _replace(
        CheckResult(
          kind,
          CheckStatus.fail,
          [
            failureText(failure),
            _ms(watch),
            if (failure != NetFailure.timeout) _raw(e),
            if (kind == CheckKind.https && _certificate != null) _certificate!,
          ].join(' · '),
          failure: failure,
        ),
      );
    }
    return null;
  }

  Future<(List<InternetAddress>, String)> _lookup() async {
    final found = await InternetAddress.lookup(service.host)
        .timeout(const Duration(seconds: 8));
    final v4 = found.where((a) => a.type == InternetAddressType.IPv4).length;
    return (found, AppStrings.netAddresses(v4, found.length - v4));
  }

  Future<(void, String)> _direct(
    List<InternetAddress> addresses, {
    required bool viaProxy,
  }) async {
    final parts = <String>[];
    var reached = false;
    for (final type in [InternetAddressType.IPv4, InternetAddressType.IPv6]) {
      final address = addresses.where((a) => a.type == type).firstOrNull;
      if (address == null) continue;
      final label = type == InternetAddressType.IPv4 ? 'IPv4' : 'IPv6';
      final watch = Stopwatch()..start();
      try {
        final socket = await Socket.connect(
          address,
          443,
          timeout: const Duration(seconds: 5),
        );
        socket.destroy();
        reached = true;
        parts.add('$label ${_ms(watch)}');
      } on Object catch (e) {
        parts.add('$label ${failureText(classifyNetError(e))}');
      }
    }
    final detail = parts.join(', ');
    if (!reached) {
      // Behind a proxy the direct way may well be closed.
      if (viaProxy) throw _Warn(detail);
      throw SocketException(detail);
    }
    if (parts.length > 1 && parts.any((p) => !p.endsWith('ms'))) {
      throw _Warn(detail);
    }
    return (null, detail);
  }

  /// Who signed the certificate the leaderboard address presented, when
  /// it was not trusted: names the filter that looks inside.
  String? _certificate;

  Future<(void, String)> _https() async {
    _certificate = null;
    final client = await newHttpClient();
    client.badCertificateCallback = (cert, host, port) {
      _certificate = '${AppStrings.netCertificate}: ${cert.issuer}';
      return false;
    };
    try {
      final request = await client.getUrl(service.resolve('v1'));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      Object? body;
      try {
        body = jsonDecode(text);
      } on FormatException {
        body = null;
      }
      if (response.statusCode != 200 || body is! Map || body['ok'] != true) {
        // Something else answered: a block page, a login page, a proxy.
        throw WebSocketException('HTTP ${response.statusCode}');
      }
      return (null, 'HTTP 200');
    } finally {
      client.close(force: true);
    }
  }

  Future<(void, String)> _content() async {
    final client = await newHttpClient();
    try {
      final request = await client.getUrl(
        ContentSync.defaultBaseUri.resolve('manifest.json'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      await response.drain<void>();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      return (null, 'HTTP 200');
    } finally {
      client.close(force: true);
    }
  }

  Future<(void, String)> _webSocket() async {
    final uri = service.replace(
      scheme: 'wss',
      path:
          '${service.path.endsWith('/') ? service.path : '${service.path}/'}'
          'v1/echo',
    );
    final WebSocket socket;
    try {
      socket = await connectWebSocket(uri);
    } on WebSocketException catch (e) {
      // A server from before the test existed.
      if (e.message.contains('404')) {
        throw const _Warn(AppStrings.netSocketUnsupported);
      }
      rethrow;
    }
    var sent = 0;
    var answered = 0;
    var longest = Duration.zero;
    var last = DateTime.now();
    final done = Completer<void>();
    final subscription = socket.listen(
      (m) {
        final now = DateTime.now();
        final gap = now.difference(last);
        if (gap > longest) longest = gap;
        last = now;
        answered++;
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    final pinger = Timer.periodic(const Duration(seconds: 3), (_) {
      sent++;
      socket.add('{"t":"ping"}');
    });
    sent++;
    socket.add('{"t":"ping"}');
    await Future.any([done.future, Future<void>.delayed(socketFor)]);
    pinger.cancel();
    final closedEarly = done.isCompleted;
    await subscription.cancel();
    await socket.close().timeout(const Duration(seconds: 2), onTimeout: () {});
    final quiet = DateTime.now().difference(last);
    if (quiet > longest) longest = quiet;
    final detail = AppStrings.netPongs(answered, sent, longest.inSeconds);
    if (answered == 0) throw WebSocketException(detail);
    if (closedEarly || answered < sent - 1 || longest > duelSilenceGuide) {
      throw _Warn(detail);
    }
    return (null, detail);
  }

  /// The same server address under a well-known name: when this works and
  /// the leaderboard's does not, the network blocks by name (the server
  /// name the app sends in the clear), not by address.
  static const otherName = 'www.cloudflare.com';

  Future<(void, String)> _otherName(InternetAddress address) async {
    final raw = await Socket.connect(
      address.address,
      443,
      timeout: const Duration(seconds: 8),
    );
    try {
      final socket = await SecureSocket.secure(
        raw,
        host: otherName,
        onBadCertificate: (_) => true,
      ).timeout(const Duration(seconds: 10));
      socket.destroy();
    } finally {
      raw.destroy();
    }
    return (null, AppStrings.netOtherNameOk);
  }

  static String _raw(Object e) {
    final text = switch (e) {
      TlsException(:final osError?) => '${e.message} ${osError.message}',
      SocketException(:final osError?) => '${e.message} ${osError.message}',
      _ => '$e',
    }.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }

  /// Longer than this without an answer and a duel would count the player
  /// as gone (lib/data/duel_client.dart, duelSilenceLimit).
  static const duelSilenceGuide = Duration(seconds: 8);

  static String _ms(Stopwatch watch) => '${watch.elapsedMilliseconds} ms';

  void _add(CheckResult result) {
    results.add(result);
    _notify();
  }

  void _replace(CheckResult result) {
    results[results.length - 1] = result;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _Warn implements Exception {
  const _Warn(this.detail);
  final String detail;
}
