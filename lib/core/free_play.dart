import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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
  final fromBank = pickVaried(
    unseenBank,
    size - generated.length,
    already: generated,
    limits: RoundLimits.of(size),
  );
  return [...fromBank, ...generated]..shuffle(rng);
}

/// Categories that ask what one knows rather than what one can estimate.
const Set<QuestionCategory> historyCategories = {
  QuestionCategory.history,
  QuestionCategory.ottoman,
};

/// At most this many history and year questions in a round (2026-11-09):
/// one history and two year questions in every five. Players without the
/// knowledge cannot reason towards a year, and long runs of them bored
/// testers. The server picks duels and tournaments with the same rule
/// (server/leaderboard/src/duel.js, `roundLimits`), and
/// tools/build_schedule.py builds new days with it.
@immutable
class RoundLimits {
  const RoundLimits({required this.history, required this.years});

  factory RoundLimits.of(int size) {
    final fives = math.max(1, (size / 5).ceil());
    return RoundLimits(history: fives, years: 2 * fives);
  }

  final int history;
  final int years;
}

/// The first [count] of [candidates] (already in random order) that keep
/// the round within [limits], counting [already] chosen questions too. When
/// too few fit, the round is filled up with the others: a short round is
/// worse than one more year question.
List<Question> pickVaried(
  List<Question> candidates,
  int count, {
  List<Question> already = const [],
  required RoundLimits limits,
}) {
  final picked = <Question>[];
  final skipped = <Question>[];
  var historyCount = already
      .where((q) => historyCategories.contains(q.category))
      .length;
  var yearCount = already.where((q) => q.kind == QuestionKind.year).length;
  for (final q in candidates) {
    if (picked.length >= count) break;
    final isHistory = historyCategories.contains(q.category);
    final isYear = q.kind == QuestionKind.year;
    if ((isHistory && historyCount >= limits.history) ||
        (isYear && yearCount >= limits.years)) {
      skipped.add(q);
      continue;
    }
    picked.add(q);
    if (isHistory) historyCount++;
    if (isYear) yearCount++;
  }
  for (final q in skipped) {
    if (picked.length >= count) break;
    picked.add(q);
  }
  return picked;
}
