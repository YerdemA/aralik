import 'dart:async';
import 'dart:io';

import 'package:aralik/core/strings.dart';
import 'package:aralik/data/net.dart';
import 'package:aralik/data/net_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('proxy', () {
    test('goes through the proxy, straight out when it fails', () {
      expect(proxyDirective(null), 'DIRECT');
      expect(proxyDirective('10.0.0.1:3128'), 'PROXY 10.0.0.1:3128; DIRECT');
    });

    test('is null without Android', () async {
      expect(await systemProxy(), isNull);
    });
  });

  group('classifyNetError', () {
    test('sorts the usual errors', () {
      expect(classifyNetError(TimeoutException('x')), NetFailure.timeout);
      expect(
        classifyNetError(const HandshakeException('bad cert')),
        NetFailure.tls,
      );
      expect(
        classifyNetError(
          const WebSocketException('was not upgraded to websocket'),
        ),
        NetFailure.blocked,
      );
      expect(
        classifyNetError(
          const SocketException(
            "Failed host lookup: 'api.kabaca.app'",
            osError: OSError('No address associated with hostname', 7),
          ),
        ),
        NetFailure.dns,
      );
      expect(
        classifyNetError(
          const SocketException(
            'Connection failed',
            osError: OSError('Connection timed out', 110),
          ),
        ),
        NetFailure.timeout,
      );
      expect(
        classifyNetError(
          const SocketException(
            'Connection failed',
            osError: OSError('Connection refused', 111),
          ),
        ),
        NetFailure.refused,
      );
      expect(classifyNetError(StateError('x')), NetFailure.other);
    });
  });

  group('checkVerdict', () {
    CheckResult ok(CheckKind kind) => CheckResult(kind, CheckStatus.ok, '');

    List<CheckResult> all({
      CheckResult? proxy,
      CheckResult? dns,
      CheckResult? https,
      CheckResult? socket,
    }) => [
      proxy ?? ok(CheckKind.proxy),
      dns ?? ok(CheckKind.dns),
      ok(CheckKind.direct),
      https ?? ok(CheckKind.https),
      ok(CheckKind.content),
      socket ?? ok(CheckKind.webSocket),
    ];

    test('all well', () {
      expect(checkVerdict(all()), AppStrings.netVerdictOk);
    });

    test('names the first thing in the way', () {
      expect(
        checkVerdict(
          all(dns: const CheckResult(CheckKind.dns, CheckStatus.fail, '')),
        ),
        AppStrings.netVerdictDns,
      );
      expect(
        checkVerdict(
          all(
            https: const CheckResult(
              CheckKind.https,
              CheckStatus.fail,
              '',
              failure: NetFailure.tls,
            ),
          ),
        ),
        AppStrings.netVerdictTls,
      );
      // The same server under another name works: blocked by name.
      expect(
        checkVerdict([
          ...all(
            https: const CheckResult(
              CheckKind.https,
              CheckStatus.fail,
              '',
              failure: NetFailure.tls,
            ),
          ),
          const CheckResult(CheckKind.sni, CheckStatus.ok, ''),
        ]),
        AppStrings.netVerdictName,
      );
      expect(
        checkVerdict(
          all(
            https: const CheckResult(
              CheckKind.https,
              CheckStatus.fail,
              '',
              failure: NetFailure.blocked,
            ),
          ),
        ),
        AppStrings.netVerdictBlocked,
      );
      expect(
        checkVerdict(
          all(
            socket: const CheckResult(
              CheckKind.webSocket,
              CheckStatus.fail,
              '',
            ),
          ),
        ),
        AppStrings.netVerdictSocket,
      );
      expect(
        checkVerdict(
          all(
            socket: const CheckResult(
              CheckKind.webSocket,
              CheckStatus.warn,
              '',
            ),
          ),
        ),
        AppStrings.netVerdictUnstable,
      );
      expect(
        checkVerdict(
          all(proxy: const CheckResult(CheckKind.proxy, CheckStatus.warn, '')),
        ),
        AppStrings.netVerdictProxy,
      );
    });
  });

  test('the report lists every step and the verdict', () {
    final report = checkReport([
      const CheckResult(CheckKind.proxy, CheckStatus.ok, 'Yok'),
      const CheckResult(
        CheckKind.https,
        CheckStatus.fail,
        'Zaman aşımı',
        failure: NetFailure.timeout,
      ),
    ], 'Sonuç');
    expect(
      report,
      '✓ ${AppStrings.netCheckProxy}: Yok\n'
      '✗ ${AppStrings.netCheckHttps}: Zaman aşımı [timeout]\n'
      'Sonuç',
    );
  });
}
