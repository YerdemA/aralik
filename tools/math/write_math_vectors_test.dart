// Writes server/leaderboard/test/math_vectors.json: math question ids and
// their answers as the app makes them, for the duel server's port
// (server/leaderboard/src/math.js) to check against. Run after changing a
// generator:
//
//   flutter test tools/math/write_math_vectors_test.dart
//
// test/core/math/math_vectors_test.dart fails while the file is stale.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../test/core/math/math_vectors.dart';

void main() {
  test('write math vectors', () {
    File(mathVectorsPath).writeAsStringSync(
      '${const JsonEncoder.withIndent(' ').convert(mathVectors())}\n',
    );
  });
}
