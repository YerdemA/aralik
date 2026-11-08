import 'package:aralik/core/math/math_problem.dart';

/// Shared with the duel server: server/leaderboard/test/math.test.js.
const mathVectorsPath = 'server/leaderboard/test/math_vectors.json';

/// Seeds spread over 32 bits, the same for every topic and level.
List<int> mathVectorSeeds() => [
  for (var k = 0; k < 40; k++) (k * 2654435761 + 12345) & 0xFFFFFFFF,
];

/// Every topic × level × seed with its answer and unit.
List<Map<String, Object>> mathVectors() => [
  for (final topic in MathTopic.values)
    for (var level = 1; level <= 3; level++)
      for (final seed in mathVectorSeeds())
        () {
          final p = generateMath(topic, level, seed);
          return {'id': p.id, 'answer': p.answer, 'unit': p.unit};
        }(),
];
