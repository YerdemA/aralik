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

    test('reads year questions', () {
      final q = Question.fromJson(
        sample(override: {'kind': 'year', 'answer': 1889, 'unit': ''}),
      );
      expect(q.kind, QuestionKind.year);
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
        {'category': 'müzik'},
        {'data_year': '2026'},
        {'fun_fact': 3},
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

    test('serves daily sets and practice pools', () async {
      final repository = QuestionRepository();
      final bank = await repository.load();
      final day0 = await repository.dailySet(0);
      expect(day0.map((q) => q.id), bank.take(5).map((q) => q.id));
      expect(await repository.practicePool(0), isEmpty);
      expect(await repository.practicePool(2), hasLength(10));
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
