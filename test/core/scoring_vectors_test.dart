import 'dart:convert';
import 'dart:io';

import 'package:aralik/core/answer_scale.dart';
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
      final kind = v['kind'] == 'year'
          ? QuestionKind.year
          : QuestionKind.magnitude;
      AnswerScale? scale;
      if (v['refined'] == true) {
        scale = refinedScaleOf(
          Question.fromJson({
            'id': 'v',
            'text': 'v',
            'answer': v['answer'],
            'unit': v['unit'] ?? '',
            'kind': v['kind'],
            'category': v['category'],
            'source': 's',
            'data_year': 2026,
            'scale': v['scale'],
          }),
        );
      } else if (v['scaled'] == true) {
        scale = scaleFor(
          kind,
          QuestionCategory.fromJson(v['category'] as String),
          v['answer'] as num,
          unit: v['unit'] as String? ?? '',
        );
      }
      if (scale != null) {
        expect(
          scale.maxFactor,
          (v['maxFactor'] as num).toDouble(),
          reason: '$v',
        );
        expect(scale.maxYearHalf, v['maxYearHalf'], reason: '$v');
        expect(scale.linearHalf, v['linearHalf'] ?? 0, reason: '$v');
      }
      expect(
        scoreFor(
          kind: kind,
          low: v['low'] as num,
          high: v['high'] as num,
          answer: v['answer'] as num,
          scale: scale,
        ),
        v['points'],
        reason: '$v',
      );
    }
  });
}
