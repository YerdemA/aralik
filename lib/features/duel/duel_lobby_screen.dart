import 'package:flutter/material.dart';

import '../../core/duel.dart';
import '../../core/strings.dart';
import '../../data/duel_client.dart';
import '../../data/leaderboard.dart';
import '../../data/pending_match.dart';
import '../../data/question_repository.dart';
import '../../data/settings_store.dart';
import '../../data/stats_store.dart';
import '../settings/user_name_sheet.dart';
import '../settings/settings_screen.dart';
import 'duel_screen.dart';

/// Start of a duel: find a random opponent (main action), or play a
/// friend: open a room, or join theirs with its code. The name comes from
/// Settings (it is only typed there); without one the lobby sends the
/// player there first.
class DuelLobbyScreen extends StatefulWidget {
  const DuelLobbyScreen({
    super.key,
    required this.service,
    required this.repository,
    required this.stats,
    required this.settings,
    this.leaderboard,
    this.pending,
    this.scaled = true,
  });

  /// Whether today's duels use the scaled rule (see answer_scale.dart).
  final bool scaled;

  final DuelService service;
  final QuestionRepository repository;
  final StatsStore stats;
  final SettingsStore settings;

  /// Passed on to Settings, where the name is chosen or changed.
  final LeaderboardStore? leaderboard;

  /// Keeps a match in progress for going back to it after leaving.
  final PendingMatchStore? pending;

  @override
  State<DuelLobbyScreen> createState() => _DuelLobbyScreenState();
}

class _DuelLobbyScreenState extends State<DuelLobbyScreen> {
  final _code = TextEditingController();
  String? _codeError;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// The name from Settings, or null when none is chosen yet.
  String? get _name => widget.settings.userName;

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(
        settings: widget.settings,
        leaderboard: widget.leaderboard,
      ),
    ),
  );

  Future<void> _findOpponent() async {
    final name = _name;
    if (name == null || _busy) return;
    await _play(code: null, name: name);
  }

  Future<void> _create() async {
    final name = _name;
    if (name == null || _busy) return;
    setState(() => _busy = true);
    try {
      final code = await widget.service.createRoom();
      await _play(code: code, name: name);
    } on DuelException catch (e) {
      _snack(
        e.failure == DuelFailure.offline
            ? AppStrings.duelOffline
            : AppStrings.duelServerError,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final name = _name;
    final code = normalizeRoomCode(_code.text);
    setState(() => _codeError = code == null ? AppStrings.duelBadCode : null);
    if (name == null || code == null || _busy) return;
    await _play(code: code, name: name);
  }

  /// Plays in room [code], or against a random opponent when it is null.
  Future<void> _play({required String? code, required String name}) async {
    final again = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DuelScreen(
          service: widget.service,
          repository: widget.repository,
          stats: widget.stats,
          code: code,
          name: name,
          scaled: widget.scaled,
          pending: widget.pending,
        ),
      ),
    );
    if (!mounted) return;
    if (again != true) Navigator.of(context).pop();
    _code.clear();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => _build(context, _name),
  );

  Widget _build(BuildContext context, String? name) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.duelTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(AppStrings.duelIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            if (name == null) ...[
              NameNeededCard(onPick: _openSettings),
              const SizedBox(height: 16),
            ] else ...[
              PlayingAsCard(name: name, onChange: _openSettings),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _busy || name == null ? null : _findOpponent,
              icon: const Icon(Icons.person_search_rounded),
              label: const Text(AppStrings.duelFindOpponent),
            ),
            const SizedBox(height: 32),
            Text(AppStrings.duelWithFriend, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy || name == null ? null : _create,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text(AppStrings.duelCreate),
            ),
            const SizedBox(height: 20),
            Text(AppStrings.duelOrJoin, style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    maxLength: roomCodeLength,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: theme.textTheme.titleLarge?.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                    onSubmitted: (_) => _join(),
                    decoration: InputDecoration(
                      labelText: AppStrings.duelCodeLabel,
                      errorText: _codeError,
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 64,
                  child: OutlinedButton(
                    onPressed: _busy || name == null ? null : _join,
                    child: const Text(AppStrings.duelJoin),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
