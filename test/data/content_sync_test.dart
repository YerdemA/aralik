import 'dart:convert';

import 'package:aralik/data/content_sync.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object> q(String id) => {
  'id': id,
  'text': '$id?',
  'answer': 1,
  'unit': 'm',
  'kind': 'magnitude',
  'category': 'coğrafya',
  'source': 'https://example.org/$id',
  'data_year': 2026,
};

String bank(List<String> ids) => jsonEncode([for (final id in ids) q(id)]);

const places =
    '{"data_year":2026,'
    '"tr":[{"id":"Q1","name":"A","lat":0,"lon":0},{"id":"Q2","name":"B","lat":0,"lon":1}],'
    '"world":[{"id":"Q3","name":"C","country":"X","lat":1,"lon":0},'
    '{"id":"Q4","name":"D","country":"Y","lat":2,"lon":0}]}';

/// Serves the bundled assets from memory.
class _Bundle extends AssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(files[key]!)));
}

void main() {
  late SharedPreferences prefs;
  late Map<String, String> server;
  late List<Uri> requests;
  var now = DateTime(2026, 11, 1, 12);

  Future<String> fakeGet(Uri uri) async {
    requests.add(uri);
    final body = server[uri.pathSegments.last];
    if (body == null) throw Exception('404');
    return body;
  }

  QuestionRepository repository() => QuestionRepository(
    bundle: _Bundle({
      QuestionRepository.questionsAssetPath: bank(['q1', 'q2']),
      QuestionRepository.placesAssetPath: places,
    }),
    remote: ContentSync(prefs, httpGet: fakeGet, clock: () => now),
  );

  Future<SyncResult> sync({bool force = false}) {
    final repo = repository();
    return (repo.remote! as ContentSync).sync(
      acceptQuestions: repo.acceptsQuestions,
      acceptPlaces: repo.acceptsPlaces,
      force: force,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    requests = [];
    now = DateTime(2026, 11, 1, 12);
    server = {
      'manifest.json': jsonEncode({
        'version': 2,
        'questions': 'questions.json',
        'places': 'places.json',
      }),
      'questions.json': bank(['q1', 'q2', 'q3']),
      'places.json': places,
    };
  });

  test('downloads a newer bank and uses it on the next load', () async {
    expect(await sync(), SyncResult.updated);
    final bankIds = (await repository().load()).map((q) => q.id);
    expect(bankIds, ['q1', 'q2', 'q3']);
  });

  test('checks at most every 6 hours', () async {
    expect(await sync(), SyncResult.updated);
    requests.clear();
    now = now.add(const Duration(hours: 1));
    expect(await sync(), SyncResult.skipped);
    expect(requests, isEmpty);
    now = now.add(const Duration(hours: 6));
    expect(await sync(), SyncResult.upToDate);
    expect(requests.map((u) => u.pathSegments.last), ['manifest.json']);
  });

  test('rejects a bank that reorders or drops bundled questions', () async {
    server['questions.json'] = bank(['q2', 'q1', 'q3']);
    expect(await sync(), SyncResult.rejected);
    expect((await repository().load()).map((q) => q.id), ['q1', 'q2']);

    server['questions.json'] = bank(['q1']);
    expect(await sync(force: true), SyncResult.rejected);
  });

  test('rejects broken downloads and keeps working offline', () async {
    server['questions.json'] = '[{"id": "q1"}]';
    expect(await sync(), SyncResult.rejected);

    server.clear();
    expect(await sync(force: true), SyncResult.failed);
    expect((await repository().load()).map((q) => q.id), ['q1', 'q2']);
  });

  test('ignores a corrupt cache and falls back to the bundled bank', () async {
    await prefs.setString('content_questions', 'not json');
    expect((await repository().load()).map((q) => q.id), ['q1', 'q2']);
  });

  test('extendsBank', () {
    final base = parseQuestions(bank(['a', 'b']));
    expect(extendsBank(base, parseQuestions(bank(['a', 'b']))), isTrue);
    expect(extendsBank(base, parseQuestions(bank(['a', 'b', 'c']))), isTrue);
    expect(extendsBank(base, parseQuestions(bank(['a']))), isFalse);
    expect(extendsBank(base, parseQuestions(bank(['b', 'a', 'c']))), isFalse);
    expect(extendsBank(base, parseQuestions(bank(['a', 'b', 'a']))), isFalse);
  });
}
