import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../data/net_check.dart';

/// Ayarlar → Bağlantı testi: tries the leaderboard server step by step
/// (proxy, DNS, direct connection, HTTPS, content, WebSocket) and says what
/// stands in the way, with a copyable report for the developer.
class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key, required this.service});

  /// The leaderboard server.
  final Uri service;

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  late final ConnectionCheck _check = ConnectionCheck(widget.service);

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text(AppStrings.netTestCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.netTest)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _check,
          builder: (context, _) {
            final results = _check.results;
            final finished = results.isNotEmpty && !_check.running;
            final verdict = finished ? checkVerdict(results) : null;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(AppStrings.netTestIntro, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                if (results.isNotEmpty)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [for (final r in results) _StepTile(result: r)],
                    ),
                  ),
                if (verdict != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    verdict,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _check.running ? null : _check.run,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    results.isEmpty
                        ? AppStrings.netTestRun
                        : AppStrings.netTestAgain,
                  ),
                ),
                if (verdict != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _copy(checkReport(results, verdict)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text(AppStrings.netTestCopy),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.result});

  final CheckResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget leading = switch (result.status) {
      CheckStatus.running => const SizedBox.square(
        dimension: 24,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      CheckStatus.ok => Icon(Icons.check_circle_rounded, color: scheme.primary),
      CheckStatus.warn => Icon(Icons.error_rounded, color: scheme.tertiary),
      CheckStatus.fail => Icon(Icons.cancel_rounded, color: scheme.error),
    };
    return ListTile(
      leading: leading,
      title: Text(checkTitle(result.kind)),
      subtitle: Text(result.detail),
    );
  }
}
