import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/daily.dart';
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

/// Loads the question bank once and keeps it in memory.
class QuestionRepository {
  QuestionRepository({AssetBundle? bundle, this.assetPath = defaultAssetPath})
    : _bundle = bundle ?? rootBundle;

  static const defaultAssetPath = 'assets/questions/questions.json';
  static const placesAssetPath = 'assets/data/places.json';

  final AssetBundle _bundle;
  final String assetPath;
  Future<List<Question>>? _cache;
  Future<DistanceQuestions>? _distanceCache;

  /// Generator for on-device distance questions. Loaded once.
  Future<DistanceQuestions> distanceQuestions() {
    return _distanceCache ??= _bundle
        .loadString(placesAssetPath)
        .then((source) => DistanceQuestions(PlaceData.parse(source)))
        .catchError((Object error, StackTrace stackTrace) {
          _distanceCache = null; // allow a retry
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  /// The whole bank in file order. Parsed on first call, then cached.
  Future<List<Question>> load() {
    return _cache ??= _bundle
        .loadString(assetPath)
        .then(parseQuestions)
        .catchError((Object error, StackTrace stackTrace) {
          _cache = null; // allow a retry
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  /// The five questions of [dayIndex].
  Future<List<Question>> dailySet(int dayIndex) async {
    final bank = await load();
    return [for (final i in dailyIndices(dayIndex, bank.length)) bank[i]];
  }

  /// Questions of past days, for practice mode.
  Future<List<Question>> practicePool(int todayIndex) async {
    final bank = await load();
    return [for (final i in practiceIndices(todayIndex, bank.length)) bank[i]];
  }
}
