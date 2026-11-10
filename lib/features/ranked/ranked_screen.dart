import 'package:flutter/material.dart';

import '../../core/mascot_look.dart';
import '../../core/ranked.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/leaderboard.dart';
import '../../data/moderation.dart';
import '../../data/ranked_client.dart';
import '../../data/settings_store.dart';
import '../../widgets/mascot_portrait.dart';
import '../../widgets/player_actions.dart';
import '../leaderboard/join_sheet.dart';
import '../leaderboard/leaderboard_screen.dart' show Medal;

/// This month's ranked duel table: knowledge or math, the player's own
/// line on top, then the leaders. One action: picking the table.
class RankedScreen extends StatefulWidget {
  const RankedScreen({
    super.key,
    required this.service,
    required this.settings,
    this.leaderboard,
    this.math = false,
  });

  final RankedService service;
  final SettingsStore settings;

  /// To join the leaderboard from here; null hides the offer.
  final LeaderboardStore? leaderboard;

  /// Opens on the math table.
  final bool math;

  @override
  State<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends State<RankedScreen> {
  late RankedMode _mode = widget.math ? RankedMode.math : RankedMode.bank;
  late Future<RankedTable> _table = _load();

  Future<RankedTable> _load() => widget.service.table(_mode);

  void _reload() {
    final table = _load();
    // A block: an arrow would hand the Future to setState.
    setState(() {
      _table = table;
    });
  }

  Future<void> _join() async {
    final store = widget.leaderboard;
    if (store == null) return;
    if (await showJoinSheet(context, store, widget.settings)) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joined = widget.service.account() != null;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.rankedTitle)),
      body: SafeArea(
        child: FutureBuilder<RankedTable>(
          future: _table,
          builder: (context, snapshot) {
            final table = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                SegmentedButton<RankedMode>(
                  segments: const [
                    ButtonSegment(
                      value: RankedMode.bank,
                      icon: Icon(Icons.lightbulb_rounded),
                      label: Text(AppStrings.duelKindBank),
                    ),
                    ButtonSegment(
                      value: RankedMode.math,
                      icon: Icon(Icons.calculate_rounded),
                      label: Text(AppStrings.duelKindMath),
                    ),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (choice) {
                    _mode = choice.single;
                    _reload();
                  },
                ),
                const SizedBox(height: 12),
                if (table != null)
                  Text(
                    '${rankedMonthLabel(table.month)} · '
                    '${AppStrings.rankedPlayers(table.players)}',
                    style: theme.textTheme.titleMedium,
                  ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.rankedRule,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (!joined && widget.leaderboard != null) ...[
                  _JoinCard(onJoin: _join),
                  const SizedBox(height: 16),
                ],
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (table == null)
                  _Failed(onRetry: _reload)
                else ...[
                  if (joined) ...[
                    if (table.me case final me?)
                      MyRankedCard(row: me, look: widget.settings.mascot)
                    else
                      Text(
                        AppStrings.rankedNotYet,
                        style: theme.textTheme.bodyLarge,
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (table.top.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        AppStrings.rankedEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  for (final row in table.top)
                    RankedRowTile(
                      row: row,
                      me: joined && row.rank == table.me?.rank,
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

class _JoinCard extends StatelessWidget {
  const _JoinCard({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(AppStrings.rankedJoinFirst),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onJoin,
            child: const Text(AppStrings.rankedJoin),
          ),
        ],
      ),
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        const Text(AppStrings.rankedLoadError),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
      ],
    ),
  );
}

/// The player's own line: place, rating and the month's numbers.
class MyRankedCard extends StatelessWidget {
  const MyRankedCard({super.key, required this.row, required this.look});

  final RankedRow row;
  final MascotLook look;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = scheme.onPrimaryContainer;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _Face(look: look, background: Palette.duelMe, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row.rank}. · ${row.nickname}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: on,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        AppStrings.rankedRecord(row.won, row.drawn, row.lost),
                        style: theme.textTheme.bodyMedium?.copyWith(color: on),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${row.rating}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: on,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(AppStrings.rankedPlayed, '${row.played}', on),
                _Stat(AppStrings.rankedWon, '${row.won}', on),
                _Stat(AppStrings.rankedAverage, '${row.average}', on),
                _Stat(
                  AppStrings.rankedHitRate,
                  AppStrings.rankedPercent(row.hitRate),
                  on,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// A line of the table: place (gold, silver, bronze for the first three),
/// mascot, name, record and rating. Another player's line opens report /
/// block.
class RankedRowTile extends StatelessWidget {
  const RankedRowTile({super.key, required this.row, this.me = false});

  final RankedRow row;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medal = Medal.ofRank(row.rank);
    final name = me ? row.nickname : Moderation.instance.shown(row.nickname);
    final onRow = me ? scheme.onPrimaryContainer : null;
    return Card(
      color: me ? scheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: medal == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: medal.mid, width: 2.5),
            ),
      child: InkWell(
        onTap: me
            ? null
            : () => showPlayerActions(
                context,
                name: row.nickname,
                place: ReportPlace.board,
              ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: medal?.gradient,
                  color: medal == null ? scheme.surfaceContainerHigh : null,
                ),
                child: Text(
                  '${row.rank}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: medal == null ? scheme.onSurface : Colors.white,
                    shadows: medal == null
                        ? null
                        : [Shadow(color: medal.dark, blurRadius: 3)],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Face(
                look: row.look,
                background: me ? Palette.duelMe : scheme.surfaceContainerHigh,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onRow,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      AppStrings.rankedRecord(row.won, row.drawn, row.lost),
                      style: theme.textTheme.bodySmall?.copyWith(color: onRow),
                    ),
                  ],
                ),
              ),
              Text(
                '${row.rating}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: onRow,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.look,
    required this.background,
    required this.size,
  });

  final MascotLook look;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: background),
    clipBehavior: Clip.antiAlias,
    child: MascotPortrait(look: look, size: size),
  );
}
