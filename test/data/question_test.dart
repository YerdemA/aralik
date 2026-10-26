import 'package:aralik/data/question.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> sample({Map<String, dynamic> override = const {}}) => {
  'id': 'q0142',
  'text': 'Ağrı Dağı kaç metre yüksekliktedir?',
  'answer': 5137,
  'unit': 'm',
  'kind': 'magnitude',
  'category': 'coğrafya',
  'source': 'https://www.wikidata.org/wiki/Q72303',
  'data_year': 2026,
  'fun_fact': 'Konum: Ağrı.',
  ...override,
};

void main() {
  group('Question.fromJson', () {
    test('reads every field', () {
      final q = Question.fromJson(sample());
      expect(q.id, 'q0142');
      expect(q.text, 'Ağrı Dağı kaç metre yüksekliktedir?');
      expect(q.answer, 5137);
      expect(q.unit, 'm');
      expect(q.kind, QuestionKind.magnitude);
      expect(q.category, QuestionCategory.geography);
      expect(q.source, 'https://www.wikidata.org/wiki/Q72303');
      expect(q.dataYear, 2026);
      expect(q.funFact, 'Konum: Ağrı.');
    });

    test('accepts decimal answers and a missing fun fact', () {
      final json = sample(override: {'answer': 62.6})..remove('fun_fact');
      final q = Question.fromJson(json);
      expect(q.answer, 62.6);
      expect(q.funFact, isNull);
    });

    test('optional fields are null when missing', () {
      final q = Question.fromJson(sample());
      expect(q.difficulty, isNull);
      expect(q.anchor, isNull);
      expect(q.dataset, isNull);
    });

    test('reads difficulty, anchor and dataset', () {
      final q = Question.fromJson(
        sample(
          override: {
            'difficulty': 2,
            'dataset': 'mountains_tr',
            'anchor': {
              'text': 'Erciyes Dağı',
              'value': 3917,
              'unit': 'm',
              'source': 'https://www.wikidata.org/wiki/Q193547',
            },
          },
        ),
      );
      expect(q.difficulty, 2);
      expect(q.dataset, 'mountains_tr');
      expect(q.anchor!.text, 'Erciyes Dağı');
      expect(q.anchor!.value, 3917);
      expect(q.anchor!.unit, 'm');
      expect(q.anchor!.source, 'https://www.wikidata.org/wiki/Q193547');
    });

    test('reads year questions', () {
      final q = Question.fromJson(
        sample(override: {'kind': 'year', 'answer': 1889, 'unit': ''}),
      );
      expect(q.kind, QuestionKind.year);
    });

    test('an unknown category falls back to "other"', () {
      final q = Question.fromJson(sample(override: {'category': 'müzik'}));
      expect(q.category, QuestionCategory.other);
    });

    test('maps every category', () {
      for (final c in QuestionCategory.values) {
        final q = Question.fromJson(
          sample(override: {'category': c.jsonValue}),
        );
        expect(q.category, c);
      }
    });

    test('rejects invalid data', () {
      for (final override in <Map<String, dynamic>>[
        {'id': null},
        {'answer': '5137'},
        {'answer': 0},
        {'kind': 'distance'},
        {'kind': 'year', 'answer': 1889.5},
        {'data_year': '2026'},
        {'fun_fact': 3},
        {'difficulty': 0},
        {'difficulty': 4},
        {'difficulty': '2'},
        {'dataset': 7},
        {'anchor': 'Erciyes'},
        {
          'anchor': {'text': 'Erciyes', 'value': 3917, 'unit': 'm'},
        },
        {
          'anchor': {
            'text': 'Erciyes',
            'value': '3917',
            'unit': 'm',
            'source': 'x',
          },
        },
      ]) {
        expect(
          () => Question.fromJson(sample(override: override)),
          throwsFormatException,
          reason: '$override',
        );
      }
    });
  });

  group('parseQuestions', () {
    test('rejects a non-list root', () {
      expect(() => parseQuestions('{}'), throwsFormatException);
      expect(() => parseQuestions('[1]'), throwsFormatException);
    });

    test('returns an unmodifiable list', () {
      final list = parseQuestions('[]');
      expect(
        () => list.add(Question.fromJson(sample())),
        throwsUnsupportedError,
      );
    });
  });

  group('QuestionRepository', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('loads and caches the bundled bank', () async {
      final repository = QuestionRepository();
      final bank = await repository.load();
      expect(bank.length, greaterThanOrEqualTo(150));
      expect(identical(await repository.load(), bank), isTrue);
      expect(bank.map((q) => q.id).toSet(), hasLength(bank.length));
    });

    test('the bundled schedule fits the bundled bank', () async {
      final repository = QuestionRepository();
      final bank = await repository.load();
      final schedule = await repository.schedule();
      expect(schedule.length, greaterThanOrEqualTo(30));
      expect(scheduleFitsBank(schedule, bank), isTrue);
      for (var day = 0; day < schedule.length; day++) {
        expect(await repository.dailySet(day), hasLength(5), reason: '$day');
      }
    });

    test('free play stays clear of the next 60 days', () async {
      final repository = QuestionRepository();
      final schedule = await repository.schedule();
      for (final today in [-6, 0, 10]) {
        final pool = (await repository.freePlayPool(today)).map((q) => q.id);
        final upcoming = schedule.upcomingIds(today);
        expect(pool.where(upcoming.contains), isEmpty, reason: '$today');
        expect(pool, isNotEmpty, reason: '$today');
      }
    });

    test('can retry after a failed load', () async {
      final bundle = _FlakyBundle();
      final repository = QuestionRepository(bundle: bundle);
      await expectLater(repository.load(), throwsA(isA<FlutterError>()));
      expect(await repository.load(), isEmpty);
    });
  });
}

/// Fails the first load, then serves an empty bank.
class _FlakyBundle extends AssetBundle {
  var _calls = 0;

  @override
  Future<ByteData> load(String key) async {
    if (_calls++ == 0) throw FlutterError('Asset not found: $key');
    return ByteData.sublistView(Uint8List.fromList('[]'.codeUnits));
  }
}
