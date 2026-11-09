import 'package:flutter/foundation.dart';

/// How the answer is entered and scored.
enum QuestionKind {
  /// Positive quantity (population, km, m). Log-scale interval.
  magnitude,

  /// Calendar year. ±years interval.
  year,
}

enum QuestionCategory {
  geography('coğrafya'),
  history('tarih'),
  turkey('türkiye'),
  science('bilim'),
  sports('spor'),
  everyday('gündelik'),
  animals('hayvanlar'),
  companies('şirketler'),
  ottoman('osmanlı'),
  architecture('mimari'),
  art('sanat'),

  // Questions one can reason towards without knowing the answer
  // (2026-11-09). No magnitude factor of their own (answer_scale.dart), so
  // an older app that shows them as "Diğer" scores them the same.
  body('vücut'),
  food('mutfak'),
  transport('ulaşım'),
  space('uzay'),

  /// Math mode's generated questions (lib/core/math/); never in the bank.
  math('matematik'),

  /// Fallback for a category this app version does not know yet (added by
  /// a content update). The question stays playable and is shown under
  /// "Diğer" until an app update brings the real category. Never written
  /// to questions.json.
  other('diğer');

  const QuestionCategory(this.jsonValue);

  /// Value used in questions.json.
  final String jsonValue;

  static QuestionCategory fromJson(String value) =>
      values.firstWhere((c) => c.jsonValue == value, orElse: () => other);
}

/// A sourced reference value that can help the player find the scale,
/// e.g. "Erciyes Dağı" 3917 m.
@immutable
class Anchor {
  const Anchor({
    required this.text,
    required this.value,
    required this.unit,
    required this.source,
  });

  final String text;
  final num value;
  final String unit;

  /// Link to the data source, like a question's.
  final String source;

  factory Anchor.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw FormatException('anchor must be an object, got $json');
    }
    final text = json['text'], value = json['value'];
    final unit = json['unit'], source = json['source'];
    if (text is! String || value is! num || unit is! String) {
      throw FormatException('anchor needs text, value and unit: $json');
    }
    if (source is! String || source.isEmpty) {
      throw FormatException('anchor needs a source: $json');
    }
    return Anchor(text: text, value: value, unit: unit, source: source);
  }
}

/// A magnitude question's own slider scale (`"scale"` in the bank, written
/// by tools/apply_scales.py from tools/scales.json; 2026-11-09, rule v3):
/// either linear, guess ± up to [half] units (ages, grams in 100 g), or
/// log, ÷[factor] … ×[factor] (narrower than the category's). Read only
/// under the refined rule (answer_scale.dart); never for years or
/// percentages. Must match `questionScale` in server/leaderboard/src/scoring.js.
class QuestionScale {
  const QuestionScale.linear(int this.half) : factor = null;
  const QuestionScale.log(double this.factor) : half = null;

  final int? half;
  final double? factor;

  static const maxHalf = 1000;
  static const maxFactor = 20.0;

  /// The scale in [json], or null when it is missing or not valid (an
  /// invalid one is ignored, as on the server).
  static QuestionScale? fromJson(Object? json) {
    if (json is! Map || json.length != 1) return null;
    final half = json['half'], factor = json['factor'];
    if (half is int && half >= 1 && half <= maxHalf) {
      return QuestionScale.linear(half);
    }
    if (factor is num && factor > 1 && factor <= maxFactor) {
      return QuestionScale.log(factor.toDouble());
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is QuestionScale && other.half == half && other.factor == factor;

  @override
  int get hashCode => Object.hash(half, factor);
}

/// One question from assets/questions/questions.json.
class Question {
  const Question({
    required this.id,
    required this.text,
    required this.answer,
    required this.unit,
    required this.kind,
    required this.category,
    required this.source,
    required this.dataYear,
    this.funFact,
    this.difficulty,
    this.anchor,
    this.dataset,
    this.retired = false,
    this.scale,
  });

  static const minDifficulty = 1;
  static const maxDifficulty = 3;

  final String id;
  final String text;
  final num answer;

  /// Display unit such as `m`, `km`, `kişi`; empty for years.
  final String unit;
  final QuestionKind kind;
  final QuestionCategory category;

  /// Link to the data source; every answer has one.
  final String source;
  final int dataYear;
  final String? funFact;

  /// Estimated difficulty: 1 easy, 2 medium, 3 hard. Null if unknown
  /// (e.g. generated questions).
  final int? difficulty;

  /// Optional reference value shown as a hint.
  final Anchor? anchor;

  /// Source data set (e.g. `battles`), used to vary the daily set.
  final String? dataset;

  /// Withdrawn from play (wrong or unsourced answer). The bank is append-only,
  /// so a bad question keeps its id and is only left out of free play and
  /// duels; it is never in the daily schedule.
  final bool retired;

  /// Its own slider scale under the refined rule, or null for the
  /// category's (see [QuestionScale]).
  final QuestionScale? scale;

  /// Throws [FormatException] on missing or mistyped fields.
  factory Question.fromJson(Map<String, dynamic> json) {
    T field<T>(String key) {
      final value = json[key];
      if (value is T) return value;
      throw FormatException(
        'Question ${json['id'] ?? '?'}: "$key" must be $T, got $value',
      );
    }

    final kindName = field<String>('kind');
    final kind = QuestionKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => throw FormatException('Unknown kind: $kindName'),
    );
    final answer = field<num>('answer');
    if (kind == QuestionKind.magnitude && answer <= 0) {
      throw FormatException('Question ${json['id']}: magnitude must be > 0');
    }
    if (kind == QuestionKind.year && answer is! int) {
      throw FormatException('Question ${json['id']}: year must be an integer');
    }
    final difficulty = field<int?>('difficulty');
    if (difficulty != null &&
        (difficulty < minDifficulty || difficulty > maxDifficulty)) {
      throw FormatException(
        'Question ${json['id']}: difficulty must be 1–3, got $difficulty',
      );
    }
    final anchorJson = json['anchor'];

    return Question(
      id: field<String>('id'),
      text: field<String>('text'),
      answer: answer,
      unit: field<String>('unit'),
      kind: kind,
      category: QuestionCategory.fromJson(field<String>('category')),
      source: field<String>('source'),
      dataYear: field<int>('data_year'),
      funFact: field<String?>('fun_fact'),
      difficulty: difficulty,
      anchor: anchorJson == null ? null : Anchor.fromJson(anchorJson),
      dataset: field<String?>('dataset'),
      retired: field<bool?>('retired') ?? false,
      scale: kind == QuestionKind.magnitude
          ? QuestionScale.fromJson(json['scale'])
          : null,
    );
  }
}
