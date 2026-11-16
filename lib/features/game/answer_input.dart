import 'package:flutter/material.dart';

import '../../core/number_format.dart';
import '../../core/question_timer.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/question.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/number_pad.dart';
import 'game_controller.dart';

// The answer input shared by the round screen and the duel: question card,
// countdown, guess pad and width slider.

/// "12 sn" with a ring that empties; turns to the error colour near the end.
class Countdown extends StatelessWidget {
  const Countdown({super.key, required this.left, required this.limit});

  final Duration left;
  final Duration limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final urgent = left <= timeWarning;
    final color = urgent ? scheme.error : scheme.primary;
    final seconds = secondsShown(left);
    return Semantics(
      label: AppStrings.secondsLeft(seconds),
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 18,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: left.inMilliseconds / limit.inMilliseconds),
                duration: const Duration(milliseconds: 200),
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 3,
                  color: color,
                  backgroundColor: color.withValues(alpha: .2),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppStrings.secondsLeft(seconds),
              style: theme.textTheme.titleMedium?.copyWith(
                color: urgent ? scheme.error : scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryChip(category: question.category),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                question.text,
                key: ValueKey(question.id),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded frame for the big number; lights up once there is a value.
class _Display extends StatelessWidget {
  const _Display({
    required this.active,
    required this.child,
    this.compact = false,
  });

  final bool active;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 8 : 14),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).cardTheme.color
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: child,
    );
  }
}

String _formatGuess(GameController game, int value) =>
    game.isYear ? formatYear(value) : formatNumber(value);

/// Everything in [GuessStep] but the pad, in dp (label, display, gaps,
/// button), with a little to spare.
const double _guessOthers = 196;

/// The same in the compact form.
const double _compactGuessOthers = 180;

/// Keys of the compact pad are at most this tall, and at least 42: with
/// the 3 dp gap on each side still a 48 dp target.
const double _compactKeyHeight = 52;
const double _compactMinKeyHeight = 42;

class GuessStep extends StatelessWidget {
  const GuessStep({
    super.key,
    required this.game,
    this.padKey,
    this.compact = false,
    this.above,
    this.aboveHeight = 0,
  });

  final GameController game;

  /// Duels and tournaments (2026-11-16): a smaller display and a tighter
  /// pad, close together, leaving room above for the quick reactions.
  final bool compact;

  /// Right above the input, [aboveHeight] tall (the quick reactions).
  final Widget? above;
  final double aboveHeight;

  /// Marks the number pad for the first-question tour.
  final GlobalKey? padKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guess = game.guess;
    final unit = game.question.unit;
    // A long question above (and the duel's two-line bar) leaves less
    // room: the keys get shorter instead of the button falling off.
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          ?above,
          Text(
            AppStrings.yourGuess,
            style: theme.textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: compact ? 6 : 8),
          _Display(
            active: guess != null,
            compact: compact,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                guess == null
                    ? AppStrings.typeYourGuess
                    : [
                        _formatGuess(game, guess),
                        if (unit.isNotEmpty) unit,
                      ].join(' '),
                style: guess == null
                    ? (compact
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.headlineMedium)
                          ?.copyWith(
                            color: theme.colorScheme.outline,
                            height: 1.6,
                          )
                    : compact
                    ? theme.textTheme.displaySmall
                    : theme.textTheme.displayMedium,
              ),
            ),
          ),
          if (compact) const SizedBox(height: 10) else const Spacer(),
          NumberPad(
            key: padKey,
            showTripleZero: !game.isYear && !game.isPercent,
            onDigits: game.type,
            onBackspace: game.backspace,
            onClear: game.clear,
            gap: compact ? 3 : 4,
            keyHeight: NumberPad.keyHeightFor(
              box.maxHeight,
              others:
                  (compact ? _compactGuessOthers : _guessOthers) + aboveHeight,
              max: compact ? _compactKeyHeight : NumberPad.fullKeyHeight,
              min: compact ? _compactMinKeyHeight : NumberPad.minKeyHeight,
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
          FilledButton.icon(
            onPressed: game.canConfirmGuess ? game.confirmGuess : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text(AppStrings.next),
          ),
        ],
      ),
    );
  }
}

class WidthStep extends StatelessWidget {
  const WidthStep({
    super.key,
    required this.game,
    required this.onLock,
    this.rangeKey,
    this.lockKey,
    this.compact = false,
    this.above,
  });

  /// Right above the interval (the quick reactions).
  final Widget? above;

  final GameController game;
  final VoidCallback onLock;

  /// Duels and tournaments: smaller gaps and display (see [GuessStep]).
  final bool compact;

  /// Mark the interval and the lock button for the first-question tour.
  final GlobalKey? rangeKey;
  final GlobalKey? lockKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bounds = game.interval;
    final range = formatRange(
      bounds.low,
      bounds.high,
      unit: game.question.unit,
      isYear: game.isYear,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: game.editGuess,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 24),
            label: Text(
              '${AppStrings.editGuess}: ${_formatGuess(game, game.guess!)}',
            ),
          ),
        ),
        const Spacer(),
        ?above,
        Text(
          AppStrings.intervalLabel,
          style: theme.textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: compact ? 6 : 8),
        _Display(
          active: true,
          compact: compact,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              range,
              style: compact
                  ? theme.textTheme.displaySmall
                  : theme.textTheme.displayMedium,
            ),
          ),
        ),
        SizedBox(height: compact ? 8 : 14),
        Center(child: _PotentialPill(points: game.potentialPoints)),
        const Spacer(),
        Slider(
          key: rangeKey,
          value: game.width,
          onChanged: game.setWidth,
          semanticFormatterCallback: (_) => range,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.narrower, style: theme.textTheme.labelMedium),
              Text(AppStrings.wider, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
        SizedBox(height: compact ? 12 : 24),
        FilledButton.icon(
          key: lockKey,
          onPressed: onLock,
          icon: const Icon(Icons.lock_outline),
          label: const Text(AppStrings.lock),
        ),
      ],
    );
  }
}

/// "İsabet edersen 85 puan", tinted like the result square it would earn.
class _PotentialPill extends StatelessWidget {
  const _PotentialPill({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.extension<GameColors>()!.forTier(
      ResultTier.of(points: points, hit: true),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 20, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              AppStrings.potentialPoints(points),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
