import 'dart:math' as math;

import 'package:aralik/core/free_play.dart';
import 'package:aralik/data/question.dart';
import 'package:flutter_test/flutter_test.dart';

Question question(String id) => Question(
  id: id,
  text: '$id?',
  answer: 1,
  unit: 'km',
  kind: QuestionKind.magnitude,
  category: QuestionCategory.geography,
  source: 'https://example.org/$id',
  dataYear: 2026,
);

/// A generator with endless questions `<prefix>0`, `<prefix>1`, …
QuestionGenerator endless(String prefix) {
  var n = 0;
  return (rng, accept) {
    for (var tries = 0; tries < 100; tries++) {
      final q = question('$prefix${n++}');
      if (accept(q)) return q;
    }
    return null;
  };
}

QuestionGenerator empty() =>
    (rng, accept) => null;

List<Question> bank(int n) => [for (var i = 0; i < n; i++) question('q$i')];

void main() {
  int generatedIn(List<Question> round) =>
      round.where((q) => !q.id.startsWith('q')).length;

  test('a full round without repeats or seen questions', () {
    final seen = {'q0', 'q1', 'q2', 'dist:0'};
    for (var seed = 0; seed < 30; seed++) {
      final round = buildFreeRound(
        bankPool: bank(10),
        generators: [endless('dist:')],
        seen: seen,
        rng: math.Random(seed),
      );
      final ids = round.map((q) => q.id).toList();
      expect(ids, hasLength(5));
      expect(ids.toSet(), hasLength(5));
      expect(ids.where(seen.contains), isEmpty);
    }
  });

  test('at most one question per generator', () {
    for (var seed = 0; seed < 30; seed++) {
      final round = buildFreeRound(
        bankPool: bank(50),
        generators: [endless('dist:')],
        seen: const {},
        rng: math.Random(seed),
      );
      expect(round.where((q) => q.id.startsWith('dist:')), hasLength(1));
      expect(round, hasLength(5));
    }
  });

  test('at most two generated questions in total', () {
    final round = buildFreeRound(
      bankPool: bank(50),
      generators: [endless('a:'), endless('b:'), endless('c:')],
      seen: const {},
      rng: math.Random(1),
    );
    expect(generatedIn(round), maxGeneratedPerRound);
    expect(round, hasLength(5));
  });

  test('a short bank pool makes a short round, not more generated', () {
    final round = buildFreeRound(
      bankPool: bank(2),
      generators: [endless('dist:')],
      seen: const {},
      rng: math.Random(0),
    );
    expect(round, hasLength(3));
    expect(generatedIn(round), 1);
  });

  test('works without generators and is empty when nothing is left', () {
    final round = buildFreeRound(
      bankPool: bank(3),
      generators: [empty()],
      seen: const {},
      rng: math.Random(0),
    );
    expect(round.map((q) => q.id).toSet(), {'q0', 'q1', 'q2'});
    expect(
      buildFreeRound(
        bankPool: bank(3),
        generators: [empty()],
        seen: {'q0', 'q1', 'q2'},
        rng: math.Random(0),
      ),
      isEmpty,
    );
  });

  test('generated questions do not always come last', () {
    final positions = <int>{
      for (var seed = 0; seed < 30; seed++)
        buildFreeRound(
          bankPool: bank(20),
          generators: [endless('dist:')],
          seen: const {},
          rng: math.Random(seed),
        ).indexWhere((q) => q.id.startsWith('dist:')),
    };
    expect(positions.length, greaterThan(2));
  });
}
