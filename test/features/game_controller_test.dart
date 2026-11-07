import 'package:aralik/core/scoring.dart';
import 'package:aralik/data/question.dart';
import 'package:aralik/features/game/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Question q(
  String id,
  num answer, {
  QuestionKind kind = QuestionKind.magnitude,
  String? unit,
}) => Question(
  id: id,
  text: '$id?',
  answer: answer,
  unit: unit ?? (kind == QuestionKind.year ? '' : 'm'),
  kind: kind,
  category: QuestionCategory.geography,
  source: 'https://example.org/$id',
  dataYear: 2026,
);

void main() {
  late GameController game;

  setUp(() {
    game = GameController([
      q('a', 5137),
      q('b', 1923, kind: QuestionKind.year),
    ]);
  });

  test('typing builds the guess without leading zeros', () {
    expect(game.guess, isNull);
    expect(game.canConfirmGuess, isFalse);
    game.type('0');
    expect(game.guess, isNull);
    game.type('5');
    game.type('000');
    expect(game.guess, 5000);
    game.backspace();
    expect(game.guess, 500);
    game.clear();
    expect(game.guess, isNull);
  });

  test('limits the number of digits', () {
    for (var i = 0; i < 20; i++) {
      game.type('9');
    }
    expect(game.guess.toString().length, GameController.maxMagnitudeDigits);
  });

  test('plays a full round', () {
    game.type('5000');
    game.confirmGuess();
    expect(game.phase, GamePhase.width);

    game.setWidth(0.0413926851582); // ×1,1 → 4.500 – 5.500
    expect(game.interval, (low: 4500, high: 5500));
    expect(game.potentialPoints, 97);

    final first = game.lock();
    expect(first.hit, isTrue);
    expect(first.points, 97);
    expect(game.isLast, isFalse);

    game.next();
    expect(game.question.id, 'b');
    expect(game.phase, GamePhase.guess);
    expect(game.guess, isNull);

    game.type('1900');
    game.confirmGuess();
    game.setWidth(0); // 1900 – 1900
    final second = game.lock();
    expect(second.hit, isFalse);
    expect(second.points, minPointsPerQuestion); // 23 years off
    expect(game.isLast, isTrue);
    expect(game.totalPoints, 97 + minPointsPerQuestion);
    expect(game.answers, hasLength(2));
  });

  test('year guesses accept at most four digits and no 000 key effect', () {
    game.type('5');
    game.confirmGuess();
    game.lock();
    game.next();
    game.type('19234');
    expect(game.guess, isNull); // 5 digits rejected at once
    game.type('1923');
    game.type('4');
    expect(game.guess, 1923);
  });

  test('editing the guess returns to the pad', () {
    game.type('42');
    game.confirmGuess();
    game.editGuess();
    expect(game.phase, GamePhase.guess);
    game.type('0');
    expect(game.guess, 420);
  });

  group('timeOut', () {
    test('locks the interval on screen', () {
      game.type('5000');
      game.confirmGuess();
      game.setWidth(0.3);
      final expected = game.interval;
      final a = game.timeOut();
      expect(a.timedOut, isTrue);
      expect(a.hasInterval, isTrue);
      expect((a.low, a.high), (expected.low, expected.high));
      expect(a.hit, isTrue);
      expect(a.outcome, Outcome.hit);
      expect(game.isLocked, isTrue);
    });

    test('locks a typed guess at the default width', () {
      game.type('5000');
      final a = game.timeOut();
      expect(a.guess, 5000);
      expect(a.hasInterval, isTrue);
      expect(a.points, greaterThan(0));
    });

    test('without a guess scores the floor and has no outcome', () {
      final a = game.timeOut();
      expect(a.timedOut, isTrue);
      expect(a.hasInterval, isFalse);
      expect(a.guess, isNull);
      expect(a.hit, isFalse);
      expect(a.outcome, isNull);
      expect(a.points, minPointsPerQuestion);
      expect(a.tier, ResultTier.miss);
      game.next();
      expect(game.index, 1);
      expect(game.isLocked, isFalse);
    });

    test('an empty timeout never beats a far miss', () {
      game.type('1');
      game.confirmGuess();
      game.setWidth(0);
      final farMiss = game.lock();
      game.next();
      final empty = game.timeOut();
      expect(empty.points, lessThanOrEqualTo(farMiss.points));
    });
  });

  test('a percentage guess stays ≤ 100 and its interval within 1…100', () {
    final pct = GameController([q('p', 74.6, unit: '%')]);
    expect(pct.isPercent, isTrue);
    pct.type('9');
    pct.type('0');
    pct.type('0'); // 900 > 100: ignored
    expect(pct.guess, 90);
    pct.confirmGuess();
    pct.setWidth(1);
    expect(pct.interval, (low: 70, high: 100));
    pct.setWidth(0.5);
    expect(pct.interval, (low: 80, high: 100));
  });
}
