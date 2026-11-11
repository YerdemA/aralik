import 'package:flutter/material.dart';

import '../../core/archive.dart';
import '../../core/daily.dart';
import '../../core/ranked.dart';
import '../../core/strings.dart';
import '../../data/leaderboard.dart';
import '../../data/moderation.dart';
import '../../widgets/player_actions.dart';
import '../ranked/ranked_view.dart' show MascotFace;
import 'leaderboard_screen.dart' show Medal;

/// The leaderboard's archive tab: who led each of the last seven days,
/// and the first three of last month's duel tables, each with their
/// mascot.
class ArchiveView extends StatefulWidget {
  const ArchiveView({super.key, required this.store});

  final LeaderboardStore store;

  @override
  State<ArchiveView> createState() => _ArchiveViewState();
}

class _ArchiveViewState extends State<ArchiveView>
    with AutomaticKeepAliveClientMixin {
  // Kept while the leaderboard is open: switching tabs does not reload.
  @override
  bool get wantKeepAlive => true;

  late Future<LeaderboardArchive> _archive = widget.store.fetchArchive();

  @override
  void initState() {
    super.initState();
    Moderation.instance.addListener(_blockedChanged);
  }

  @override
  void dispose() {
    Moderation.instance.removeListener(_blockedChanged);
    super.dispose();
  }

  void _blockedChanged() {
    if (mounted) setState(() {});
  }

  void _reload() {
    final archive = widget.store.fetchArchive();
    setState(() {
      _archive = archive;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return FutureBuilder<LeaderboardArchive>(
      future: _archive,
      builder: (context, snapshot) {
        final archive = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (archive == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(AppStrings.archiveLoadError),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _reload,
                  child: const Text(AppStrings.retry),
                ),
              ],
            ),
          );
        }
        final month = rankedMonthLabel(archive.month);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Heading(
              AppStrings.archiveDaysTitle,
              icon: Icons.emoji_events_rounded,
            ),
            if (archive.days.isEmpty)
              const _Empty(AppStrings.archiveDaysEmpty)
            else
              for (final e in archive.days)
                _ArchiveTile(
                  entry: e,
                  mine: e.nickname == widget.store.account?.nickname,
                  label: dayLabel(dateOfDay(e.day!)),
                  medal: Medal.gold,
                  detail: e.value == null
                      ? null
                      : AppStrings.archivePoints(e.value!),
                ),
            const SizedBox(height: 24),
            _Heading(
              AppStrings.archiveDuelTitle(month),
              icon: Icons.leaderboard_rounded,
            ),
            for (final (title, icon, podium) in [
              (AppStrings.duelKindBank, Icons.lightbulb_rounded, archive.bank),
              (AppStrings.duelKindMath, Icons.calculate_rounded, archive.math),
            ]) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(title, style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
              if (podium.isEmpty)
                const _Empty(AppStrings.archiveDuelEmpty)
              else
                for (final e in podium)
                  _ArchiveTile(
                    entry: e,
                    mine: e.nickname == widget.store.account?.nickname,
                    label: month,
                    medal: Medal.ofRank(e.rank ?? 0),
                    rank: e.rank,
                    detail: e.value == null
                        ? null
                        : AppStrings.archivePoints(e.value!),
                  ),
            ],
          ],
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.titleMedium)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One name of the archive: mascot, name, date (a day or a month), and
/// the place on a podium. Opens report / block like the board.
class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    required this.entry,
    required this.label,
    required this.medal,
    this.mine = false,
    this.rank,
    this.detail,
  });

  final ArchiveEntry entry;
  final String label;
  final Medal? medal;

  /// The player's own name: no report / block.
  final bool mine;
  final int? rank;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medal = this.medal;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: medal == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: medal.mid, width: 2),
            ),
      child: InkWell(
        onTap: mine
            ? null
            : () => showPlayerActions(
                context,
                name: entry.nickname,
                place: ReportPlace.board,
              ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            children: [
              if (rank != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: medal?.gradient,
                    color: medal == null ? scheme.surfaceContainerHigh : null,
                  ),
                  child: Text(
                    '$rank',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: medal == null ? scheme.onSurface : Colors.white,
                      shadows: medal == null
                          ? null
                          : [Shadow(color: medal.dark, blurRadius: 3)],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              MascotFace(
                look: entry.look,
                background: scheme.surfaceContainerHigh,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mine
                          ? '${entry.nickname} (${AppStrings.you})'
                          : Moderation.instance.shown(entry.nickname),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
