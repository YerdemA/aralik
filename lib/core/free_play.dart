import 'dart:math' as math;

import '../data/distance_questions.dart';
import '../data/question.dart';
import 'daily.dart';

/// Share of free-play questions taken from past daily sets; the rest are
/// generated on device.
const double bankShare = 1 / 3;

/// Builds one free-play round of [size] questions the player has never
/// answered ([seen] holds every answered id).
///
/// Mixes unseen questions of past daily sets ([pastBank], so upcoming days
/// are never spoiled) with generated distance questions. A city appears at
/// most once per round. May return fewer than [size] questions only when
/// both sources are exhausted.
List<Question> buildFreeRound({
  required List<Question> pastBank,
  required DistanceQuestions generator,
  required Set<String> seen,
  required math.Random rng,
  int size = questionsPerDay,
}) {
  final unseenBank = [
    for (final q in pastBank)
      if (!seen.contains(q.id)) q,
  ]..shuffle(rng);

  final round = <Question>[];
  final usedIds = <String>{};
  final usedPlaces = <String>{};

  Question? fromGenerator() => generator.pick(
    rng,
    accept: (q, from, to) =>
        !seen.contains(q.id) &&
        !usedIds.contains(q.id) &&
        !usedPlaces.contains(from.id) &&
        !usedPlaces.contains(to.id),
  );

  while (round.length < size) {
    final preferBank = unseenBank.isNotEmpty && rng.nextDouble() < bankShare;
    Question? next;
    if (preferBank) {
      next = unseenBank.removeLast();
    } else {
      next = fromGenerator();
      if (next != null) {
        // ids look like dist:Q1:Q2
        usedPlaces.addAll(next.id.split(':').skip(1));
      } else if (unseenBank.isNotEmpty) {
        next = unseenBank.removeLast();
      }
    }
    if (next == null) break;
    usedIds.add(next.id);
    round.add(next);
  }
  return round;
}
