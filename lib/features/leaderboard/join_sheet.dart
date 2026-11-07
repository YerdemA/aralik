import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../data/leaderboard.dart';
import '../../data/settings_store.dart';
import '../settings/settings_screen.dart';

/// Text for a failed leaderboard request.
String leaderboardFailureText(LeaderboardFailure failure) => switch (failure) {
  LeaderboardFailure.offline => AppStrings.leaderboardOffline,
  LeaderboardFailure.nicknameInvalid => AppStrings.nicknameBadCharacters,
  LeaderboardFailure.nicknameBlocked => AppStrings.nicknameBlocked,
  LeaderboardFailure.nicknameTaken => AppStrings.nicknameTaken,
  LeaderboardFailure.rateLimited => AppStrings.rateLimited,
  LeaderboardFailure.renameWait => AppStrings.renameRule,
  LeaderboardFailure.unauthorized => AppStrings.leaderboardMissing,
  LeaderboardFailure.rejected ||
  LeaderboardFailure.server => AppStrings.leaderboardError,
};

/// Joins the leaderboard with the player's name from Settings (the name
/// is never typed here). Without a name it sends the player to Settings.
/// Resolves to true once joined.
Future<bool> showJoinSheet(
  BuildContext context,
  LeaderboardStore store,
  SettingsStore settings,
) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _JoinSheet(store: store, settings: settings),
  );
  return done ?? false;
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet({required this.store, required this.settings});

  final LeaderboardStore store;
  final SettingsStore settings;

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  String? _error;
  bool _busy = false;

  void _openSettings() {
    final navigator = Navigator.of(context)..pop(false);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          leaderboard: widget.store,
        ),
      ),
    );
  }

  Future<void> _join(String name) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final restored = await widget.store.join(name);
      final nickname = widget.store.account?.nickname ?? name;
      // A restored account keeps its name: it becomes the name everywhere.
      await widget.settings.adoptUserName(nickname);
      if (!mounted) return;
      if (restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.leaderboardRestored(nickname))),
        );
      }
      Navigator.of(context).pop(true);
    } on LeaderboardException catch (e) {
      final refused = switch (e.failure) {
        LeaderboardFailure.nicknameTaken => AppStrings.leaderboardNameTaken,
        LeaderboardFailure.nicknameBlocked ||
        LeaderboardFailure.nicknameInvalid => AppStrings.leaderboardNameBlocked,
        _ => null,
      };
      // The name cannot be used here: picking another is not held back.
      if (refused != null) await widget.settings.freeNameChange();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = refused ?? leaderboardFailureText(e.failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.settings.userName;
    final error = _error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.leaderboardJoinTitle,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            name == null
                ? AppStrings.leaderboardJoinNeedsName
                : AppStrings.leaderboardJoinBody(name),
            style: theme.textTheme.bodyMedium,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (name != null)
            FilledButton(
              onPressed: _busy ? null : () => _join(name),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text(AppStrings.join),
            ),
          if (name != null) const SizedBox(height: 8),
          if (name == null)
            FilledButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_rounded),
              label: const Text(AppStrings.openSettings),
            )
          else
            OutlinedButton.icon(
              onPressed: _busy ? null : _openSettings,
              icon: const Icon(Icons.settings_rounded),
              label: const Text(AppStrings.duelNameInSettings),
            ),
        ],
      ),
    );
  }
}
