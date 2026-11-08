import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'math_vectors.dart';

void main() {
  test('the duel server checks the answers the app makes now', () {
    final file = File(mathVectorsPath);
    final stored = jsonDecode(file.readAsStringSync()) as List;
    final now = mathVectors();
    expect(
      stored.length,
      now.length,
      reason: 'run tools/math/write_math_vectors_test.dart',
    );
    for (var i = 0; i < now.length; i++) {
      final s = stored[i] as Map<String, dynamic>;
      expect(
        (s['id'], s['answer'], s['unit']),
        (now[i]['id'], now[i]['answer'], now[i]['unit']),
        reason: 'stale: run tools/math/write_math_vectors_test.dart',
      );
    }
  });
}
