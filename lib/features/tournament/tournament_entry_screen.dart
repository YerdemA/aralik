import 'package:flutter/material.dart';

import '../../core/duel.dart';
import '../../core/strings.dart';
import '../../data/duel_client.dart';
import '../../data/leaderboard.dart';
import '../../data/pending_match.dart';
import '../../data/question_repository.dart';
import '../../data/settings_store.dart';
import '../../data/stats_store.dart';
import '../../data/tournament_client.dart';
import '../settings/user_name_sheet.dart';
import '../settings/settings_screen.dart';
import 'tournament_screen.dart';

/// Start of a tournament: open a room (main action) or join one with its
/// code. The name comes from Settings, as for duels.
class TournamentEntryScreen extends StatefulWidget {
  const TournamentEntryScreen({
    super.key,
    required this.service,
    required this.repository,
    required this.stats,
    required this.settings,
    this.leaderboard,
    this.pending,
    this.scaled = true,
  });

  final TournamentService service;
  final QuestionRepository repository;
  final StatsStore stats;
  final SettingsStore settings;

  /// Passed on to Settings, where the name is chosen or changed.
  final LeaderboardStore? leaderboard;

  /// Keeps a match in progress for going back to it after leaving.
  final PendingMatchStore? pending;

  /// Whether today's matches use the scaled rule (see answer_scale.dart).
  final bool scaled;

  @override
  State<TournamentEntryScreen> createState() => _TournamentEntryScreenState();
}

class _TournamentEntryScreenState extends State<TournamentEntryScreen> {
  final _code = TextEditingController();
  String? _codeError;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String? get _name => widget.settings.userName;

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(
        settings: widget.settings,
        leaderboard: widget.leaderboard,
      ),
    ),
  );

  Future<void> _create() async {
    final name = _name;
    if (name == null || _busy) return;
    setState(() => _busy = true);
    try {
      final code = await widget.service.createRoom();
      await _play(code, name);
    } on DuelException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.failure == DuelFailure.offline
                ? AppStrings.duelOffline
                : AppStrings.duelServerError,
          ),
        ),
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
    await _play(code, name);
  }

  Future<void> _play(String code, String name) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentScreen(
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
    _code.clear();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => _build(context, _name),
  );

  Widget _build(BuildContext context, String? name) {
    final theme = Theme.of(context);
    final ready = name != null && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.tournament)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(AppStrings.tournamentIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            if (name == null)
              NameNeededCard(onPick: _openSettings)
            else
              PlayingAsCard(name: name, onChange: _openSettings),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: ready ? _create : null,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.groups_rounded),
              label: const Text(AppStrings.tournamentCreate),
            ),
            const SizedBox(height: 32),
            Text(
              AppStrings.tournamentJoinTitle,
              style: theme.textTheme.titleMedium,
            ),
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
                      labelText: AppStrings.tournamentRoomCode,
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
                    onPressed: ready ? _join : null,
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
