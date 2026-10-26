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
/// only appends. Ids must stay unique: the schedule and the player's seen
/// questions refer to them.
bool extendsBank(List<Question> base, List<Question> candidate) {
  if (candidate.length < base.length) return false;
  for (var i = 0; i < base.length; i++) {
    if (candidate[i].id != base[i].id) return false;
  }
  return candidate.map((q) => q.id).toSet().length == candidate.length;
}

/// Whether every id of [schedule] is a question of [bank].
bool scheduleFitsBank(Schedule schedule, List<Question> bank) =>
    bank.map((q) => q.id).toSet().containsAll(schedule.ids);

/// Loads the question bank, the daily schedule and place data once and
/// keeps them in memory. Downloaded content ([remote]) wins when it is a
/// valid extension of the bundled assets.
class QuestionRepository {
  QuestionRepository({AssetBundle? bundle, this.remote})
    : _bundle = bundle ?? rootBundle;

  static const questionsAssetPath = 'assets/questions/questions.json';
  static const placesAssetPath = 'assets/data/places.json';
  static const scheduleAssetPath = 'assets/questions/schedule.json';

  final AssetBundle _bundle;
  final RemoteContent? remote;
  Future<List<Question>>? _bundledCache;
  Future<List<Question>>? _cache;
  Future<Schedule>? _bundledScheduleCache;
  Future<Schedule>? _scheduleCache;
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

  /// The schedule shipped with the app.
  Future<Schedule> bundledSchedule() {
    return _bundledScheduleCache ??= _bundle
        .loadString(scheduleAssetPath)
        .then(Schedule.parse)
        .catchError((Object error, StackTrace stackTrace) {
          _bundledScheduleCache = null; // allow a retry
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  /// The schedule in use. A downloaded one must extend the bundled one and
  /// refer only to questions of the bank in use.
  Future<Schedule> schedule() {
    return _scheduleCache ??=
        Future(() async {
          final bundled = await bundledSchedule();
          final downloaded = _tryParse(remote?.scheduleJson, Schedule.parse);
          return downloaded != null &&
                  downloaded.extendsSchedule(bundled) &&
                  scheduleFitsBank(downloaded, await load())
              ? downloaded
              : bundled;
        }).catchError((Object error, StackTrace stackTrace) {
          _scheduleCache = null; // allow a retry
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

  /// Validator for [ContentSync]. All three files must parse; the bank and
  /// the schedule must extend the bundled ones, the schedule may only name
  /// questions of the new bank, and the places must be usable.
  Future<bool> acceptsContent(ContentFiles files) async {
    final bank = _tryParse(files.questions, parseQuestions);
    final schedule = _tryParse(files.schedule, Schedule.parse);
    final places = _tryParse(files.places, PlaceData.parse);
    return bank != null &&
        schedule != null &&
        places != null &&
        extendsBank(await bundledBank(), bank) &&
        schedule.extendsSchedule(await bundledSchedule()) &&
        scheduleFitsBank(schedule, bank) &&
        _isUsable(places);
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

  /// The five questions of [dayIndex], in schedule order.
  Future<List<Question>> dailySet(int dayIndex) async {
    final byId = {for (final q in await load()) q.id: q};
    return [for (final id in (await schedule()).idsFor(dayIndex)) ?byId[id]];
  }

  /// Bank questions free play may use on [todayIndex]: everything outside
  /// the next [freePlayHorizonDays] days of the schedule (past days and
  /// questions never scheduled included), so upcoming sets are not spoiled.
  Future<List<Question>> freePlayPool(int todayIndex) async {
    final upcoming = (await schedule()).upcomingIds(todayIndex);
    return [
      for (final q in await load())
        if (!upcoming.contains(q.id)) q,
    ];
  }
}
