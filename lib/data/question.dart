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
  everyday('gündelik');

  const QuestionCategory(this.jsonValue);

  /// Value used in questions.json.
  final String jsonValue;

  static QuestionCategory fromJson(String value) => values.firstWhere(
    (c) => c.jsonValue == value,
    orElse: () => throw FormatException('Unknown category: $value'),
  );
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
  });

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
    );
  }
}
