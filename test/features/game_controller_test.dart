import 'package:aralik/data/question.dart';
import 'package:aralik/features/game/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Question q(
  String id,
  num answer, {
  QuestionKind kind = QuestionKind.magnitude,
}) => Question(
  id: id,
  text: '$id?',
  answer: answer,
  unit: kind == QuestionKind.year ? '' : 'm',
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
    expect(game.potentialPoints, 93);

    final first = game.lock();
    expect(first.hit, isTrue);
    expect(first.points, 93);
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
    expect(second.points, 0);
    expect(game.isLast, isTrue);
    expect(game.totalPoints, 93);
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
}
