import 'package:flutter/foundation.dart';

import '../../core/answer_scale.dart';
import '../../core/interval.dart';
import '../../core/scoring.dart';
import '../../data/question.dart';

enum GamePhase {
  /// Typing the best guess on the number pad.
  guess,

  /// Adjusting the interval width with the slider.
  width,
}

/// A locked interval and its outcome.
///
/// When time ran out before a guess was typed there is no interval:
/// [guess], [low] and [high] are null and the question scores
/// [minPointsPerQuestion].
@immutable
class RoundAnswer {
  const RoundAnswer({
    required this.question,
    required this.guess,
    required this.low,
    required this.high,
    required this.points,
    this.timedOut = false,
  }) : assert(
         (guess == null) == (low == null) && (low == null) == (high == null),
       );

  final Question question;
  final int? guess;
  final int? low;
  final int? high;
  final int points;

  /// Locked by the countdown, not by the player.
  final bool timedOut;

  /// Whether an interval was given (false only for an empty timeout).
  bool get hasInterval => low != null;

  bool get hit => hasInterval && isHit(low!, high!, question.answer);

  /// Null without an interval: nothing to say where the answer fell.
  Outcome? get outcome =>
      hasInterval ? Outcome.of(low!, high!, question.answer) : null;
  ResultTier get tier => ResultTier.of(points: points, hit: hit);
}

/// State of one round (a list of questions answered in order).
class GameController extends ChangeNotifier {
  GameController(this.questions, {this.scaled = true})
    : assert(questions.isNotEmpty);

  /// Whether intervals and points follow each question's scale (the
  /// current rule, answer_scale.dart). False for daily sets of days before
  /// the leaderboard switched rules.
  final bool scaled;

  AnswerScale? get _scale => scaled ? scaleOf(question) : null;

  /// Longest guess the pad accepts (12 digits ≈ 1 trillion).
  static const maxMagnitudeDigits = 12;
  static const maxYearDigits = 4;

  final List<Question> questions;
  final List<RoundAnswer> _answers = [];

  int _index = 0;
  GamePhase _phase = GamePhase.guess;
  String _digits = '';
  double _width = defaultWidth;

  int get index => _index;
  Question get question => questions[_index];
  bool get isYear => question.kind == QuestionKind.year;
  bool get isLast => _index == questions.length - 1;
  GamePhase get phase => _phase;
  double get width => _width;
  List<RoundAnswer> get answers => List.unmodifiable(_answers);
  int get totalPoints => _answers.fold(0, (sum, a) => sum + a.points);
  int get maxPoints => questions.length * maxPointsPerQuestion;

  /// The typed guess, or null while empty.
  int? get guess => _digits.isEmpty ? null : int.parse(_digits);

  bool get canConfirmGuess => (guess ?? 0) > 0;

  int get _maxDigits => isYear ? maxYearDigits : maxMagnitudeDigits;

  /// Appends one or more digits ("0"–"9", or "000").
  void type(String digits) {
    assert(RegExp(r'^\d+$').hasMatch(digits));
    if (_phase != GamePhase.guess) return;
    var next = _digits + digits;
    next = next.replaceFirst(RegExp(r'^0+'), ''); // no leading zeros
    if (next.length > _maxDigits || next == _digits) return;
    _digits = next;
    notifyListeners();
  }

  void backspace() {
    if (_phase != GamePhase.guess || _digits.isEmpty) return;
    _digits = _digits.substring(0, _digits.length - 1);
    notifyListeners();
  }

  void clear() {
    if (_phase != GamePhase.guess || _digits.isEmpty) return;
    _digits = '';
    notifyListeners();
  }

  void confirmGuess() {
    if (!canConfirmGuess) return;
    _phase = GamePhase.width;
    notifyListeners();
  }

  void editGuess() {
    if (_phase != GamePhase.width) return;
    _phase = GamePhase.guess;
    notifyListeners();
  }

  void setWidth(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped == _width) return;
    _width = clamped;
    notifyListeners();
  }

  /// The interval as shown and scored. Only valid in the width phase.
  Bounds get interval {
    final g = guess!;
    final scale = _scale;
    if (scale == null) {
      return isYear ? yearInterval(g, _width) : magnitudeInterval(g, _width);
    }
    return isYear
        ? yearInterval(g, _width, maxHalf: scale.maxYearHalf)
        : magnitudeInterval(g, _width, maxFactor: scale.maxFactor);
  }

  /// Points if the current interval turns out to contain the answer.
  int get potentialPoints {
    final b = interval;
    return scoreFor(
      kind: question.kind,
      low: b.low,
      high: b.high,
      answer: b.low,
      scale: _scale,
    );
  }

  /// Whether the current question is locked (waiting for [next]).
  bool get isLocked => _answers.length > _index;

  /// Locks the current interval and returns its outcome.
  RoundAnswer lock() {
    assert(_phase == GamePhase.width);
    assert(!isLocked, 'question already locked');
    return _add(_scored(timedOut: false));
  }

  /// Locks whatever is on screen when time runs out: the interval, or the
  /// typed guess at the current width. With nothing typed the question
  /// scores [minPointsPerQuestion], so letting time run out never beats
  /// an answer.
  RoundAnswer timeOut() {
    assert(!isLocked, 'question already locked');
    if (canConfirmGuess) return _add(_scored(timedOut: true));
    return _add(
      RoundAnswer(
        question: question,
        guess: null,
        low: null,
        high: null,
        points: minPointsPerQuestion,
        timedOut: true,
      ),
    );
  }

  RoundAnswer _scored({required bool timedOut}) {
    final b = interval;
    return RoundAnswer(
      question: question,
      guess: guess!,
      low: b.low,
      high: b.high,
      points: scoreFor(
        kind: question.kind,
        low: b.low,
        high: b.high,
        answer: question.answer,
        scale: _scale,
      ),
      timedOut: timedOut,
    );
  }

  RoundAnswer _add(RoundAnswer answer) {
    _answers.add(answer);
    notifyListeners();
    return answer;
  }

  /// Moves to the next question after a lock.
  void next() {
    assert(_answers.length == _index + 1, 'lock before moving on');
    if (isLast) return;
    _index++;
    _phase = GamePhase.guess;
    _digits = '';
    _width = defaultWidth;
    notifyListeners();
  }
}
