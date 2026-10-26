import 'dart:io';
import 'dart:math' as math;

import 'package:aralik/core/free_play.dart';
import 'package:aralik/data/distance_questions.dart';
import 'package:aralik/data/place.dart';
import 'package:aralik/data/question.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = Place(id: 'Q1', name: 'Ankara', lat: 0, lon: 0);
const _b = Place(id: 'Q2', name: 'Bdan', lat: 0, lon: 1);
const _c = Place(id: 'Q3', name: 'Cdan', lat: 1, lon: 0);
const _near = Place(id: 'Q4', name: 'Yakın', lat: 0, lon: 0.1); // ~11 km to _a
const _x = Place(id: 'Q10', name: 'Prag', country: 'Çekya', lat: 50, lon: 14);
const _y = Place(
  id: 'Q11',
  name: 'Singapur',
  country: 'Singapur',
  lat: 1,
  lon: 103,
);

DistanceQuestions generator({
  List<Place> turkey = const [_a, _b, _c],
  List<Place> world = const [_x, _y],
}) =>
    DistanceQuestions(PlaceData(dataYear: 2026, turkey: turkey, world: world));

Question bankQuestion(String id) => Question(
  id: id,
  text: '$id?',
  answer: 1,
  unit: 'm',
  kind: QuestionKind.magnitude,
  category: QuestionCategory.geography,
  source: 'https://example.org/$id',
  dataYear: 2026,
);

void main() {
  group('Place', () {
    test('shows the city name only, without a country', () {
      expect(_x.displayName, 'Prag');
      expect(_y.displayName, 'Singapur');
      expect(_a.displayName, 'Ankara');
    });
  });

  group('DistanceQuestions', () {
    test('counts pairs per group', () {
      expect(generator().pairCount, 3 + 1);
    });

    test('builds a sourced magnitude question', () {
      final q = generator().build(_a, _b, category: QuestionCategory.turkey);
      expect(q.id, 'dist:Q1:Q2');
      expect(q.text, 'Ankara ile Bdan arası kuş uçuşu kaç kilometredir?');
      expect(q.answer, 111); // one degree on the equator
      expect(q.unit, 'km');
      expect(q.kind, QuestionKind.magnitude);
      expect(q.source, contains('Q1'));
      expect(q.source, contains('Q2'));
    });

    test('pairs major Turkish cities with world capitals', () {
      const istanbul = Place(
        id: 'Q406',
        name: 'İstanbul',
        lat: 41,
        lon: 29,
        major: true,
      );
      const ankaraAbroad = Place(
        id: 'Q3640',
        name: 'Ankara',
        country: 'Türkiye',
        lat: 39.9,
        lon: 32.8,
      );
      final g = generator(
        turkey: const [istanbul, _b],
        world: const [_x, ankaraAbroad],
      );
      // 1 Turkish pair + 1 world pair + İstanbul × Prag (not × Ankara).
      expect(g.pairCount, 3);
      final ids = {for (var i = 0; i < 200; i++) g.pick(math.Random(i))!.id};
      expect(ids, contains(DistanceQuestions.idFor(istanbul, _x)));
    });

    test('ids do not depend on order', () {
      expect(DistanceQuestions.idFor(_a, _b), DistanceQuestions.idFor(_b, _a));
    });

    test('never pairs a place with itself or a too-close place', () {
      final g = generator(turkey: const [_a, _near, _b], world: const []);
      final rng = math.Random(1);
      for (var i = 0; i < 200; i++) {
        final q = g.pick(rng)!;
        expect(q.id, isNot('dist:Q1:Q4'));
        expect(q.answer, greaterThanOrEqualTo(DistanceQuestions.minDistanceKm));
      }
    });

    test('uses the category of the group', () {
      final rng = math.Random(2);
      final categories = {
        for (var i = 0; i < 100; i++) generator().pick(rng)!.category,
      };
      expect(categories, {QuestionCategory.turkey, QuestionCategory.geography});
    });

    test('returns null when nothing is acceptable', () {
      expect(
        generator().pick(math.Random(3), accept: (_, _, _) => false),
        isNull,
      );
    });
  });

  group('buildFreeRound', () {
    final big = generator(
      turkey: [
        for (var i = 0; i < 20; i++)
          Place(id: 'T$i', name: 'Şehir $i', lat: i.toDouble(), lon: 0),
      ],
    );

    test('makes a full round without repeats or seen questions', () {
      final bank = [for (var i = 0; i < 10; i++) bankQuestion('q$i')];
      final seen = {'q0', 'q1', 'q2'};
      for (var seed = 0; seed < 30; seed++) {
        final round = buildFreeRound(
          pastBank: bank,
          generator: big,
          seen: seen,
          rng: math.Random(seed),
        );
        expect(round, hasLength(5));
        final ids = round.map((q) => q.id).toList();
        expect(ids.toSet(), hasLength(5));
        expect(ids.where(seen.contains), isEmpty);
      }
    });

    test('uses each city at most once per round', () {
      for (var seed = 0; seed < 30; seed++) {
        final round = buildFreeRound(
          pastBank: const [],
          generator: big,
          seen: const {},
          rng: math.Random(seed),
        );
        final cities = [for (final q in round) ...q.id.split(':').skip(1)];
        expect(cities.toSet(), hasLength(cities.length));
      }
    });

    test('mixes in past daily questions', () {
      final bank = [for (var i = 0; i < 50; i++) bankQuestion('q$i')];
      var fromBank = 0;
      for (var seed = 0; seed < 40; seed++) {
        fromBank += buildFreeRound(
          pastBank: bank,
          generator: big,
          seen: const {},
          rng: math.Random(seed),
        ).where((q) => q.id.startsWith('q')).length;
      }
      expect(fromBank, inInclusiveRange(30, 110)); // ~1/3 of 200
    });

    test('falls back to the bank when the generator is exhausted', () {
      final round = buildFreeRound(
        pastBank: [bankQuestion('q1'), bankQuestion('q2')],
        generator: generator(turkey: const [], world: const []),
        seen: const {},
        rng: math.Random(0),
      );
      expect(round.map((q) => q.id).toSet(), {'q1', 'q2'});
    });
  });

  test('bundled places.json parses and gives thousands of pairs', () {
    final data = PlaceData.parse(
      File('assets/data/places.json').readAsStringSync(),
    );
    expect(data.turkey.length, greaterThanOrEqualTo(75));
    expect(data.world.length, greaterThanOrEqualTo(30));
    expect(DistanceQuestions(data).pairCount, greaterThan(4000));
    expect(data.turkey.where((p) => p.major), hasLength(15));
    final ids = [...data.turkey, ...data.world].map((p) => p.id);
    expect(data.world.map((p) => p.id).toSet(), hasLength(data.world.length));
    expect(data.turkey.map((p) => p.id).toSet(), hasLength(data.turkey.length));
    expect(ids.every((id) => RegExp(r'^Q\d+$').hasMatch(id)), isTrue);
  });
}
