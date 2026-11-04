import 'dart:convert';
import 'dart:io';

import 'package:aralik/core/scoring.dart';
import 'package:aralik/data/question.dart';
import 'package:flutter_test/flutter_test.dart';

/// The leaderboard server recomputes scores in JavaScript
/// (server/leaderboard/src/scoring.js). Both sides check these vectors, so
/// a change to the formula here fails until the server follows.
void main() {
  test('scoring matches the leaderboard server vectors', () {
    final vectors = jsonDecode(
      File('server/leaderboard/test/scoring_vectors.json').readAsStringSync(),
    ) as List;
    expect(vectors, isNotEmpty);
    for (final v in vectors.cast<Map<String, dynamic>>()) {
      expect(
        scoreFor(
          kind: v['kind'] == 'year'
              ? QuestionKind.year
              : QuestionKind.magnitude,
          low: v['low'] as num,
          high: v['high'] as num,
          answer: v['answer'] as num,
        ),
        v['points'],
        reason: '$v',
      );
    }
  });
}
