import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/daily.dart';
import 'content_sync.dart';
import 'distance_questions.dart';
import 'place.dart';
import 'question.dart';

/// Parses questions.json. Throws [FormatException] on invalid data.
List<Question> parseQuestions(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw const FormatException('questions.json must be a list');
  }
  return List.unmodifiable([
    for (final item in decoded)
      if (item is Map<String, dynamic>)
        Question.fromJson(item)
      else
        throw FormatException('Question must be an object: $item'),
  ]);
}

/// Whether [candidate] keeps every question of [base] in the same order and
/// only appends. Daily sets index into the bank, so anything else would give
/// different players different questions on the same day.
bool extendsBank(List<Question> base, List<Question> candidate) {
  if (candidate.length < base.length) return false;
  for (var i = 0; i < base.length; i++) {
    if (candidate[i].id != base[i].id) return false;
  }
  return candidate.map((q) => q.id).toSet().length == candidate.length;
}

/// Loads the question bank and place data once and keeps them in memory.
/// Downloaded content ([remote]) wins when it is a valid extension of the
/// bundled assets.
class QuestionRepository {
  QuestionRepository({AssetBundle? bundle, this.remote})
    : _bundle = bundle ?? rootBundle;

  static const questionsAssetPath = 'assets/questions/questions.json';
  static const placesAssetPath = 'assets/data/places.json';

  final AssetBundle _bundle;
  final RemoteContent? remote;
  Future<List<Question>>? _bundledCache;
  Future<List<Question>>? _cache;
  Future<DistanceQuestions>? _distanceCache;

  /// The bank shipped with the app.
  Future<List<Question>> bundledBank() {
    return _bundledCache ??= _bundle
        .loadString(questionsAssetPath)
        .then(parseQuestions)
        .catchError((Object error, StackTrace stackTrace) {
          _bundledCache = null; // allow a retry
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  /// The bank in use, in file order. Parsed on first call, then cached.
  Future<List<Question>> load() {
    return _cache ??= bundledBank()
        .then((bundled) {
          final downloaded = _tryParse(remote?.questionsJson, parseQuestions);
          return downloaded != null && extendsBank(bundled, downloaded)
              ? downloaded
              : bundled;
        })
        .catchError((Object error, StackTrace stackTrace) {
          _cache = null; // allow a retry
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  /// Generator for on-device distance questions. Loaded once.
  Future<DistanceQuestions> distanceQuestions() {
    return _distanceCache ??=
        Future(() async {
          final downloaded = _tryParse(remote?.placesJson, PlaceData.parse);
          if (downloaded != null && _isUsable(downloaded)) {
            return DistanceQuestions(downloaded);
          }
          return DistanceQuestions(
            PlaceData.parse(await _bundle.loadString(placesAssetPath)),
          );
        }).catchError((Object error, StackTrace stackTrace) {
          _distanceCache = null; // allow a retry
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  /// Validator for [ContentSync]: a downloaded bank must parse and extend
  /// the bundled one.
  Future<bool> acceptsQuestions(String json) async {
    final candidate = _tryParse(json, parseQuestions);
    return candidate != null && extendsBank(await bundledBank(), candidate);
  }

  /// Validator for [ContentSync]: downloaded places must parse and be usable.
  bool acceptsPlaces(String json) {
    final candidate = _tryParse(json, PlaceData.parse);
    return candidate != null && _isUsable(candidate);
  }

  static bool _isUsable(PlaceData data) =>
      data.turkey.length >= 2 && data.world.length >= 2;

  static T? _tryParse<T>(String? json, T Function(String) parse) {
    if (json == null) return null;
    try {
      return parse(json);
    } catch (_) {
      return null; // corrupt download: fall back to the bundled asset
    }
  }

  /// The five questions of [dayIndex].
  Future<List<Question>> dailySet(int dayIndex) async {
    final bank = await load();
    return [for (final i in dailyIndices(dayIndex, bank.length)) bank[i]];
  }

  /// Questions of past days, for free play.
  Future<List<Question>> practicePool(int todayIndex) async {
    final bank = await load();
    return [for (final i in practiceIndices(todayIndex, bank.length)) bank[i]];
  }
}
