import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/number_format.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/question.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/number_pad.dart';
import '../result/result_screen.dart';
import 'game_controller.dart';

/// Plays [questions] in order: guess → width → lock → result, per question.
/// Pops with the list of [RoundAnswer]s when the round is finished.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.questions,
    this.onLocked,
    this.alreadyAnswered = 0,
  });

  final List<Question> questions;

  /// Questions of the same set answered in an earlier session; only shifts
  /// the "Soru 3 / 5" counter when a daily set is resumed.
  final int alreadyAnswered;

  /// Called right after each lock, e.g. to persist stats.
  final ValueChanged<RoundAnswer>? onLocked;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _game = GameController(widget.questions);

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  Future<void> _lock() async {
    HapticFeedback.mediumImpact();
    final answer = _game.lock();
    widget.onLocked?.call(answer);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(answer: answer, isLast: _game.isLast),
      ),
    );
    if (!mounted) return;
    if (_game.isLast) {
      Navigator.of(context).pop(_game.answers);
    } else {
      _game.next();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _game,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            AppStrings.questionProgress(
              widget.alreadyAnswered + _game.index + 1,
              widget.alreadyAnswered + _game.questions.length,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: AppStrings.quit,
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(12),
            child: _Progress(
              done: widget.alreadyAnswered + _game.answers.length,
              total: widget.alreadyAnswered + _game.questions.length,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuestionCard(question: _game.question),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _game.phase == GamePhase.guess
                        ? _GuessStep(key: const ValueKey('guess'), game: _game)
                        : _WidthStep(
                            key: const ValueKey('width'),
                            game: _game,
                            onLock: _lock,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One segment per question; locked ones fill in.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i < done
                      ? scheme.tertiary
                      : i == done
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

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

class _GuessStep extends StatelessWidget {
  const _GuessStep({super.key, required this.game});

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

class _WidthStep extends StatelessWidget {
  const _WidthStep({super.key, required this.game, required this.onLock});

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
