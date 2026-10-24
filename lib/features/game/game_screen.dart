import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/number_format.dart';
import '../../core/strings.dart';
import '../../data/question.dart';
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
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _game.question.text,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
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
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            guess == null
                ? AppStrings.typeYourGuess
                : [
                    _formatGuess(game, guess),
                    if (unit.isNotEmpty) unit,
                  ].join(' '),
            style: theme.textTheme.displayMedium?.copyWith(
              color: guess == null ? theme.colorScheme.outline : null,
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
        FilledButton(
          onPressed: game.canConfirmGuess ? game.confirmGuess : null,
          child: const Text(AppStrings.next),
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
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(range, style: theme.textTheme.displayMedium),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.potentialPoints(game.potentialPoints),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
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
