import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/daily.dart';
import '../../core/scoring.dart';
import '../../core/share_text.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/calibration_text.dart';
import '../../widgets/count_up.dart';
import 'share_card.dart';

enum SummaryAction { newRound, home }

/// End of a daily set (share) or a free-play round (new round; it can be
/// shared too).
/// Pops with the chosen [SummaryAction].
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    super.key,
    required this.results,
    required this.hits,
    required this.answered,
    this.dayIndex,
    this.onLeaderboard,
    this.roundLabel,
    this.calibrationTitle,
    this.math = false,
  });

  /// A math round: the share card's mood uses math's bands.
  final bool math;

  /// A round's name when shared ("Matematik turu"); "Serbest tur" without.
  final String? roundLabel;

  /// Shown above the calibration line when it is not the general one
  /// ("Matematik kalibrasyonu").
  final String? calibrationTitle;

  /// Opens today's leaderboard; null hides the button.
  final VoidCallback? onLeaderboard;

  /// Outcome per question, in order.
  final List<QuestionResult> results;

  /// All-time calibration counts.
  final int hits;
  final int answered;

  /// Set for the daily set: the main action becomes "Paylaş" (image card
  /// or Wordle-style text).
  final int? dayIndex;

  bool get _isDaily => dayIndex != null;

  /// The share preview: the day's card, or the round's.
  void _openShare(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ShareSheet(
      card: ShareCardData(
        dayIndex: dayIndex,
        label: roundLabel,
        math: math,
        results: results,
        hits: hits,
        answered: answered,
      ),
    ),
  );

  /// Green when calibrated, amber when off, neutral without enough data.
  Color _calibrationColor(ThemeData theme) {
    final colors = theme.extension<GameColors>()!;
    return switch (calibrationFeedback(hits, answered)) {
      CalibrationFeedback.good => colors.good,
      CalibrationFeedback.notEnoughData => theme.colorScheme.primary,
      _ => colors.partial,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalPoints(results);
    final max = results.length * maxPointsPerQuestion;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                _isDaily ? AppStrings.daySummary : AppStrings.roundSummary,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  CountUp(
                    value: total,
                    duration: const Duration(milliseconds: 1000),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    ' / $max',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _TierRow(results: results),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.track_changes_rounded,
                        color: _calibrationColor(theme),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (calibrationTitle != null)
                              Text(
                                calibrationTitle!,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            Text(
                              calibrationSummary(hits, answered),
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isDaily) ...[
                const SizedBox(height: 8),
                Text(
                  AppStrings.comeBackTomorrow,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              if (_isDaily)
                FilledButton.icon(
                  onPressed: () => _openShare(context),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text(AppStrings.share),
                )
              else ...[
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(SummaryAction.newRound),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(AppStrings.newRound),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openShare(context),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text(AppStrings.share),
                ),
              ],
              if (_isDaily && onLeaderboard != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onLeaderboard,
                  icon: const Icon(Icons.emoji_events_rounded),
                  label: const Text(AppStrings.leaderboard),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.home_rounded),
                label: const Text(AppStrings.backHome),
                onPressed: () => Navigator.of(context).pop(SummaryAction.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coloured squares matching the share card, popping in one by one, with
/// each question's points below.
class _TierRow extends StatelessWidget {
  const _TierRow({required this.results});

  final List<QuestionResult> results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<GameColors>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, r) in results.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              children: [
                // Later squares take longer, so they land one after another.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 350 + 150 * i),
                  curve: Interval(
                    i / (results.length + 1),
                    1,
                    curve: Curves.easeOutBack,
                  ),
                  builder: (context, t, child) =>
                      Transform.scale(scale: t, child: child),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.forTier(r.tier),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${r.points}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Preview of the story card with two ways to share: the image (with the
/// text as caption) or the Wordle-style text alone.
class ShareSheet extends StatefulWidget {
  const ShareSheet({
    super.key,
    required this.card,
    this.render = renderShareCard,
  });

  final ShareCardData card;

  /// Injectable for tests.
  final Future<Uint8List> Function(ShareCardData) render;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  late final Future<Uint8List> _png = widget.render(widget.card);

  String get _text => shareText(
    dayIndex: widget.card.dayIndex,
    label: widget.card.label,
    results: widget.card.results,
    hits: widget.card.hits,
    answered: widget.card.answered,
  );

  String get _fileName {
    final day = widget.card.dayIndex;
    if (day == null) return AppStrings.shareRoundFileName;
    final d = dateOfDay(day);
    String two(int n) => n.toString().padLeft(2, '0');
    return 'kabaca-${d.year}-${two(d.month)}-${two(d.day)}.png';
  }

  Future<void> _share(Uint8List? png) async {
    final navigator = Navigator.of(context);
    await SharePlus.instance.share(
      ShareParams(
        text: _text,
        subject: AppStrings.shareSubject,
        files: png == null
            ? null
            : [XFile.fromData(png, mimeType: 'image/png', name: _fileName)],
      ),
    );
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.5;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FutureBuilder(
          future: _png,
          builder: (context, snapshot) {
            final png = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: height,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: shareCardSize.aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: png == null
                            ? ColoredBox(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: snapshot.hasError
                                    ? null
                                    : const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                              )
                            : Image.memory(png, gaplessPlayback: true),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: png == null ? null : () => _share(png),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text(AppStrings.shareImage),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _share(null),
                  icon: const Icon(Icons.notes_rounded),
                  label: const Text(AppStrings.shareTextOnly),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
