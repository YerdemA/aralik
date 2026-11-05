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
  const _Display({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

class GuessStep extends StatelessWidget {
  const GuessStep({super.key, required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guess = game.guess;
    final unit = game.question.unit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          AppStrings.yourGuess,
          style: theme.textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        _Display(
          active: guess != null,
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
                  ? theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      height: 1.6,
                    )
                  : theme.textTheme.displayMedium,
            ),
          ),
        ),
        const Spacer(),
        NumberPad(
          showTripleZero: !game.isYear,
          onDigits: game.type,
          onBackspace: game.backspace,
          onClear: game.clear,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: game.canConfirmGuess ? game.confirmGuess : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text(AppStrings.next),
        ),
      ],
    );
  }
}

class WidthStep extends StatelessWidget {
  const WidthStep({super.key, required this.game, required this.onLock});

  final GameController game;
  final VoidCallback onLock;

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
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              '${AppStrings.editGuess}: ${_formatGuess(game, game.guess!)}',
            ),
          ),
        ),
        const Spacer(),
        Text(
          AppStrings.intervalLabel,
          style: theme.textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        _Display(
          active: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(range, style: theme.textTheme.displayMedium),
          ),
        ),
        const SizedBox(height: 14),
        Center(child: _PotentialPill(points: game.potentialPoints)),
        const Spacer(),
        Slider(
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
        const SizedBox(height: 24),
        FilledButton.icon(
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
