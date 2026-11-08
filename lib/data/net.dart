import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// What every request of the app sends as its User-Agent.
const String userAgent = 'Kabaca-Android';

/// The HTTP proxy Android uses on the current network ("host:port"), or
/// null when there is none. dart:io does not read Android's proxy setting
/// by itself, so a network that only lets traffic out through a proxy
/// (some libraries, schools, offices) worked in the browser but not in the
/// app. A PAC file shows up as a proxy on localhost that Android runs.
/// Read from MainActivity.kt; null in tests and on failure.
Future<String?> systemProxy() async {
  try {
    final proxy = await _channel.invokeMethod<String>('proxy');
    return proxy == null || proxy.isEmpty ? null : proxy;
  } on Object {
    return null;
  }
}

/// The value for [HttpClient.findProxy] with [proxy]: through it, and
/// straight out when the proxy itself cannot be reached.
String proxyDirective(String? proxy) =>
    proxy == null ? 'DIRECT' : 'PROXY $proxy; DIRECT';

/// A client with short timeouts that goes through Android's proxy.
Future<HttpClient> newHttpClient({
  Duration connectionTimeout = const Duration(seconds: 8),
}) async {
  final directive = proxyDirective(await systemProxy());
  return HttpClient()
    ..connectionTimeout = connectionTimeout
    ..userAgent = userAgent
    ..findProxy = (_) => directive;
}

/// Opens a WebSocket through Android's proxy.
Future<WebSocket> connectWebSocket(
  Uri uri, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final proxy = await systemProxy();
  final client = proxy == null
      ? null
      : (HttpClient()
          ..connectionTimeout = timeout
          ..userAgent = userAgent
          ..findProxy = (_) => proxyDirective(proxy));
  return WebSocket.connect(
    uri.toString(),
    customClient: client,
  ).timeout(timeout);
}

/// Why a connection failed, as far as the error tells.
enum NetFailure {
  /// The name could not be looked up: no network, or the network's DNS
  /// does not answer for it.
  dns,

  /// Nothing came back in time.
  timeout,

  /// The address refused or dropped the connection.
  refused,

  /// The secure connection failed: usually a network that looks inside
  /// encrypted traffic with its own certificate.
  tls,

  /// Something in between answered instead of the server (a filter's
  /// block page, a proxy, a login page), or would not pass a WebSocket.
  blocked,

  /// Anything else.
  other,
}

/// Sorts [error] from a request or socket into a [NetFailure].
NetFailure classifyNetError(Object error) {
  if (error is TimeoutException) return NetFailure.timeout;
  if (error is HandshakeException || error is TlsException) {
    return NetFailure.tls;
  }
  if (error is WebSocketException) return NetFailure.blocked;
  if (error is SocketException) {
    final text = '${error.message} ${error.osError?.message ?? ''}'
        .toLowerCase();
    if (text.contains('host lookup') ||
        text.contains('no address associated') ||
        text.contains('nodename nor servname')) {
      return NetFailure.dns;
    }
    if (text.contains('timed out')) return NetFailure.timeout;
    return NetFailure.refused;
  }
  if (error is HttpException) {
    final text = error.message.toLowerCase();
    if (text.contains('websocket') || text.contains('upgrade')) {
      return NetFailure.blocked;
    }
    return NetFailure.refused;
  }
  return NetFailure.other;
}

const _channel = MethodChannel('com.yerdema.kabaca/net');
