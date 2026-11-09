import 'package:aralik/core/nickname.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('a name changes once every three days; the first choice is free', () {
    final now = DateTime(2026, 11, 7, 12);
    expect(nextNameChange(null, now), isNull);
    expect(
      nextNameChange(DateTime(2026, 11, 6, 12), now),
      DateTime(2026, 11, 9, 12),
    );
    expect(nextNameChange(DateTime(2026, 11, 4, 12), now), isNull);
    expect(nextNameChange(DateTime(2026, 11, 4, 13), now), isNotNull);
  });

  test(
    'the store counts changes, not the first choice or an adopted name',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsStore(await SharedPreferences.getInstance());
      final now = DateTime(2026, 11, 7);
      await settings.setUserName('Ayşe', now: now);
      expect(settings.nameChangedAt, isNull);
      await settings.adoptUserName('Kaplan');
      expect(settings.userName, 'Kaplan');
      expect(settings.nameChangedAt, isNull);
      await settings.setUserName('Kaplan', now: now);
      expect(settings.nameChangedAt, isNull);
      await settings.setUserName('Bora', now: now);
      expect(settings.nameChangedAt, now);
      expect(settings.nextNameChange(now), DateTime(2026, 11, 10));
      await settings.freeNameChange();
      expect(settings.nextNameChange(now), isNull);
    },
  );

  test('names compare like the server: Turkish case, no separators', () {
    expect(nameKey('  Işık_Ali '), nameKey('ışıkali'));
    expect(nameKey('İREM'), 'irem');
    expect(nameKey('Ka.p-lan'), 'kaplan');
    expect(nameKey('Aslan'), isNot(nameKey('Pars')));
  });
}
