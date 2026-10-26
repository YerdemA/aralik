import 'dart:math' as math;

import '../data/question.dart';
import 'daily.dart';

/// Picks a generated question that [accept] allows, or null when it has
/// none left (e.g. `DistanceQuestions.pick`).
typedef QuestionGenerator = Question? Function(
  math.Random rng,
  bool Function(Question q) accept,
);

/// Generated questions per round, all generators together.
const int maxGeneratedPerRound = 2;

/// Questions per round from one generator (so at most one distance
/// question).
const int maxPerGenerator = 1;

/// Builds one free-play round of [size] questions the player has never
/// answered ([seen] holds every answered id).
///
/// Mostly bank questions from [bankPool] (those outside the upcoming
/// schedule), plus at most [maxPerGenerator] question from each of
/// [generators] and [maxGeneratedPerRound] in total. The round is shorter
/// than [size] only when the bank pool runs out; it is empty when nothing
/// is left at all.
List<Question> buildFreeRound({
  required List<Question> bankPool,
  required List<QuestionGenerator> generators,
  required Set<String> seen,
  required math.Random rng,
  int size = questionsPerDay,
}) {
  final generated = <Question>[];
  final usedIds = <String>{};
  for (final generate in [...generators]..shuffle(rng)) {
    if (generated.length >= maxGeneratedPerRound || generated.length >= size) {
      break;
    }
    for (var n = 0; n < maxPerGenerator; n++) {
      final q = generate(
        rng,
        (q) => !seen.contains(q.id) && !usedIds.contains(q.id),
      );
      if (q == null) break;
      usedIds.add(q.id);
      generated.add(q);
    }
  }

  final unseenBank = [
    for (final q in bankPool)
      if (!seen.contains(q.id) && !usedIds.contains(q.id)) q,
  ]..shuffle(rng);
  final fromBank = unseenBank.take(size - generated.length);
  return [...fromBank, ...generated]..shuffle(rng);
}
