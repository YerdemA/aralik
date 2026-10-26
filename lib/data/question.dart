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
    );
  }
}
