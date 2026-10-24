import 'dart:math' as math;

import '../core/geo.dart';
import '../core/strings.dart';
import 'place.dart';
import 'question.dart';

/// On-device "kuş uçuşu" questions between two cities of the same group
/// (Turkish province capitals, or world capitals). Thousands of pairs from a
/// few KB of sourced coordinates; the answer is computed, never typed in.
class DistanceQuestions {
  DistanceQuestions(this.data);

  /// Pairs closer than this make trivial questions and are skipped.
  static const double minDistanceKm = 30;

  final PlaceData data;

  static int _pairs(int n) => n * (n - 1) ~/ 2;

  int get pairCount => _pairs(data.turkey.length) + _pairs(data.world.length);

  /// Stable id, independent of the order of the two places.
  static String idFor(Place a, Place b) {
    final ids = [a.id, b.id]..sort();
    return 'dist:${ids[0]}:${ids[1]}';
  }

  Question build(Place from, Place to, {required QuestionCategory category}) {
    final km = greatCircleKm(from.lat, from.lon, to.lat, to.lon);
    return Question(
      id: idFor(from, to),
      text: AppStrings.distanceQuestion(from.displayName, to.displayName),
      answer: km.round(),
      unit: AppStrings.kilometres,
      kind: QuestionKind.magnitude,
      category: category,
      source: '${from.source}, ${to.source}',
      dataYear: data.dataYear,
      funFact: AppStrings.distanceFunFact,
    );
  }

  /// A random pair question that [accept] allows, or null when none was
  /// found in [maxAttempts] tries (practically only when almost every pair
  /// has been seen).
  Question? pick(
    math.Random rng, {
    bool Function(Question question, Place from, Place to)? accept,
    int maxAttempts = 200,
  }) {
    final turkeyPairs = _pairs(data.turkey.length);
    if (pairCount == 0) return null;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      // Weight the groups by their pair counts, so every pair is equally likely.
      final inTurkey = rng.nextInt(pairCount) < turkeyPairs;
      final group = inTurkey ? data.turkey : data.world;
      final i = rng.nextInt(group.length);
      final j = rng.nextInt(group.length - 1);
      final from = group[i];
      final to = group[j >= i ? j + 1 : j];
      if (greatCircleKm(from.lat, from.lon, to.lat, to.lon) < minDistanceKm) {
        continue;
      }
      final question = build(
        from,
        to,
        category: inTurkey
            ? QuestionCategory.turkey
            : QuestionCategory.geography,
      );
      if (accept == null || accept(question, from, to)) return question;
    }
    return null;
  }
}
