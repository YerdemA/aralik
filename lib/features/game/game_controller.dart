import 'package:flutter/foundation.dart';

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
@immutable
class RoundAnswer {
  const RoundAnswer({
    required this.question,
    required this.guess,
    required this.low,
    required this.high,
    required this.points,
  });

  final Question question;
  final int guess;
  final int low;
  final int high;
  final int points;

  bool get hit => isHit(low, high, question.answer);
  Outcome get outcome => Outcome.of(low, high, question.answer);
  ResultTier get tier => ResultTier.of(points: points, hit: hit);
}

/// State of one round (a list of questions answered in order).
class GameController extends ChangeNotifier {
  GameController(this.questions) : assert(questions.isNotEmpty);

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
    return isYear ? yearInterval(g, _width) : magnitudeInterval(g, _width);
  }

  /// Points if the current interval turns out to contain the answer.
  int get potentialPoints {
    final b = interval;
    return scoreFor(
      kind: question.kind,
      low: b.low,
      high: b.high,
      answer: b.low,
    );
  }

  /// Locks the current interval and returns its outcome.
  RoundAnswer lock() {
    assert(_phase == GamePhase.width);
    assert(_answers.length == _index, 'question already locked');
    final b = interval;
    final answer = RoundAnswer(
      question: question,
      guess: guess!,
      low: b.low,
      high: b.high,
      points: scoreFor(
        kind: question.kind,
        low: b.low,
        high: b.high,
        answer: question.answer,
      ),
    );
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
