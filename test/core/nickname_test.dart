import 'package:aralik/core/nickname.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tidies spaces', () {
    expect(tidyNickname('  Ali   Veli '), 'Ali Veli');
  });

  test('accepts Turkish letters, digits and separators', () {
    for (final ok in ['Şeyma', 'İğdır.Çiçek', 'kaplan_34', 'Ali Veli', 'a-b']) {
      expect(nicknameProblem(ok), isNull, reason: ok);
    }
    expect(nicknameProblem('a' * 16), isNull);
  });

  test('reports the problem', () {
    expect(nicknameProblem('ab'), NicknameProblem.tooShort);
    expect(nicknameProblem('   '), NicknameProblem.tooShort);
    expect(nicknameProblem('a' * 17), NicknameProblem.tooLong);
    for (final bad in ['_ali', 'ali!', '1234', 'a😀b', 'ali@x']) {
      expect(nicknameProblem(bad), NicknameProblem.badCharacters, reason: bad);
    }
  });
}
