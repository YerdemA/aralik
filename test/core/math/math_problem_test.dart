import 'package:aralik/core/math/math_problem.dart';
import 'package:aralik/core/math/seeded_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeededRandom', () {
    test('gives the same numbers as the JavaScript mulberry32', () {
      // node: the reference in seeded_random.dart, first five per seed.
      const vectors = {
        1: [2693262067, 11749833, 2265367787, 4213581821, 4159151403],
        12345: [4207900869, 1317490944, 2079646450, 3513001552, 2187978186],
        4294967295: [3850105811, 813802916, 3073704848, 4054706436, 3630262831],
      };
      for (final MapEntry(key: seed, value: expected) in vectors.entries) {
        final r = SeededRandom(seed);
        expect([for (var i = 0; i < 5; i++) r.nextUint32()], expected);
      }
    });

    test('ranges stay inside their bounds', () {
      final r = SeededRandom(7);
      for (var i = 0; i < 1000; i++) {
        expect(r.between(12, 99), inInclusiveRange(12, 99));
        expect(r.stepped(5, 95, 5) % 5, 0);
      }
    });
  });

  group('helpers', () {
    test('known values', () {
      expect(factorial(10), 3628800);
      expect(choose(49, 6), 13983816);
      expect(choose(52, 5), 2598960);
      expect(choose(30, 2), 435);
      expect(fibonacci(1), 1);
      expect(fibonacci(12), 144);
      expect(fibonacci(50), 12586269025);
      expect(primeCount(100), 25);
      expect(primeCount(1000), 168);
      expect(primeCount(1000000), 78498);
      expect(powerDigits(2, 100), 31);
      expect(factorialDigits(20), 19); // 2.432.902.008.176.640.000
      expect(sharedBirthday(23), closeTo(0.5073, 0.0001));
      expect(roundTo(2.45, 1), 2.5);
      expect(superscript(16), '¹⁶');
    });
  });

  group('generators', () {
    const seeds = 200;

    test('every topic and level: positive, bounded, stated, repeatable', () {
      for (final topic in MathTopic.values) {
        for (var level = 1; level <= 3; level++) {
          for (var seed = 0; seed < seeds; seed++) {
            final p = generateMath(topic, level, seed * 7919);
            final where = '${p.id}: ${p.text}';
            expect(p.answer, greaterThan(0), reason: where);
            expect(p.answer.isFinite, isTrue, reason: where);
            expect(p.answer, lessThan(1e12), reason: where);
            if (p.isPercent) {
              expect(p.answer, inInclusiveRange(1, 99.5), reason: where);
            }
            expect(p.text, isNot(contains(r'$')), reason: where);
            expect(p.text, contains('?'), reason: where);
            expect(p.working, isNotEmpty, reason: where);
            expect(p.difficulty, level);
            // The id makes the same question again.
            final again = mathProblemFromId(p.id)!;
            expect(
              (again.text, again.answer, again.unit),
              (p.text, p.answer, p.unit),
            );
          }
        }
      }
    });

    test('a few answers by hand', () {
      // Whatever the seed, the answer follows from the numbers in the text.
      for (var seed = 0; seed < 50; seed++) {
        final m = generateMath(MathTopic.multiply, 1, seed);
        final factors = RegExp(r'\d+')
            .allMatches(m.text)
            .map((x) => int.parse(x[0]!))
            .toList();
        expect(m.answer, factors[0] * factors[1]);

        final f = generateMath(MathTopic.factorial, 2, seed);
        final n = int.parse(RegExp(r'^(\d+)!').firstMatch(f.text)![1]!);
        expect(f.answer, factorial(n));
      }
    });

    test('ids that are not math questions are refused', () {
      expect(mathProblemFromId('q0001'), isNull);
      expect(mathProblemFromId('math:yok:1:5'), isNull);
      expect(mathProblemFromId('math:carpma:4:5'), isNull);
      expect(mathProblemFromId('math:carpma:1:x'), isNull);
      expect(mathProblemFromId('dist:Q1:Q2'), isNull);
    });
  });

  group('mathRound', () {
    test('easy to hard, five different topics, the same for the same seed', () {
      for (var seed = 0; seed < 100; seed++) {
        final round = mathRound(seed);
        expect(round.map((p) => p.difficulty), [1, 1, 2, 2, 3]);
        expect(round.map((p) => p.topic).toSet(), hasLength(5));
        expect(mathRound(seed).map((p) => p.id), round.map((p) => p.id));
      }
    });
  });
}
