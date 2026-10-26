import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Fetches a URL as text; throws on any failure.
typedef HttpGet = Future<String> Function(Uri uri);

/// Downloaded content that replaces the bundled assets once validated.
abstract interface class RemoteContent {
  /// questions.json text, or null if nothing was downloaded yet.
  String? get questionsJson;

  /// places.json text, or null if nothing was downloaded yet.
  String? get placesJson;

  /// schedule.json text, or null if nothing was downloaded yet.
  String? get scheduleJson;
}

/// One downloaded release: the files are only valid together, because the
/// schedule refers to questions of the bank.
typedef ContentFiles = ({String questions, String places, String schedule});

enum SyncResult { skipped, upToDate, updated, rejected, failed }

/// Keeps the question bank fresh without an app update.
///
/// The content lives as static files on GitHub Pages (`docs/content/`, see
/// tools/publish_content.py). At most every [checkInterval] the app reads
/// the small manifest; when its version is newer it downloads the files,
/// lets the caller validate them and stores them in shared_preferences.
/// They are used from the next launch on, so a running game never changes
/// under the player. Offline, nothing happens.
class ContentSync implements RemoteContent {
  ContentSync(
    this._prefs, {
    HttpGet? httpGet,
    Uri? baseUri,
    DateTime Function()? clock,
  }) : _get = httpGet ?? defaultHttpGet,
       _base = baseUri ?? defaultBaseUri,
       _now = clock ?? DateTime.now;

  static final defaultBaseUri = Uri.parse(
    'https://yerdema.github.io/aralik/content/',
  );
  static const checkInterval = Duration(hours: 6);

  static const _versionKey = 'content_version';
  static const _checkedKey = 'content_checked_at';
  static const _questionsKey = 'content_questions';
  static const _placesKey = 'content_places';
  static const _scheduleKey = 'content_schedule';

  final SharedPreferences _prefs;
  final HttpGet _get;
  final Uri _base;
  final DateTime Function() _now;

  @override
  String? get questionsJson => _prefs.getString(_questionsKey);

  @override
  String? get placesJson => _prefs.getString(_placesKey);

  @override
  String? get scheduleJson => _prefs.getString(_scheduleKey);

  int get version => _prefs.getInt(_versionKey) ?? 0;

  /// Checks for new content. [accept] decides whether the downloaded files
  /// may replace the current ones; they are stored all together or not at
  /// all.
  Future<SyncResult> sync({
    required FutureOr<bool> Function(ContentFiles files) accept,
    bool force = false,
  }) async {
    final now = _now();
    final last = _prefs.getInt(_checkedKey);
    if (!force &&
        last != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)) <
            checkInterval) {
      return SyncResult.skipped;
    }
    try {
      final manifest = jsonDecode(await _get(_base.resolve('manifest.json')));
      final remoteVersion = manifest['version'] as int;
      await _prefs.setInt(_checkedKey, now.millisecondsSinceEpoch);
      if (remoteVersion <= version) return SyncResult.upToDate;

      final questions = await _get(
        _base.resolve(manifest['questions'] as String),
      );
      final places = await _get(_base.resolve(manifest['places'] as String));
      final schedule = await _get(
        _base.resolve(manifest['schedule'] as String),
      );
      final files = (questions: questions, places: places, schedule: schedule);
      if (!await accept(files)) return SyncResult.rejected;
      await _prefs.setString(_questionsKey, questions);
      await _prefs.setString(_placesKey, places);
      await _prefs.setString(_scheduleKey, schedule);
      await _prefs.setInt(_versionKey, remoteVersion);
      return SyncResult.updated;
    } catch (_) {
      return SyncResult.failed; // offline, timeout, bad JSON: try later
    }
  }
}

/// Plain GET with short timeouts, UTF-8 body. No package needed.
Future<String> defaultHttpGet(Uri uri) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..userAgent = 'Kabaca-Android';
  try {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 30));
  } finally {
    client.close(force: true);
  }
}
