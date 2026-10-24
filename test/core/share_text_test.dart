import 'package:aralik/core/daily.dart';
import 'package:aralik/core/interval.dart';
import 'package:aralik/core/number_format.dart';
import 'package:aralik/core/share_text.dart';
import 'package:aralik/widgets/calibration_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dailyShareText', () {
    test('matches the Wordle-style card', () {
      expect(
        dailyShareText(
          dayIndex: 41,
          points: [93, 75, 40, 0, 72],
          hits: 80,
          answered: 100,
        ),
        'Aralık #42 · 280/500\n🟩🟩🟨⬛🟩\nKalibrasyon %80',
      );
    });

    test('omits calibration with too few answers', () {
      expect(
        dailyShareText(
          dayIndex: 0,
          points: [100, 0, 0, 0, 10],
          hits: 2,
          answered: 5,
        ),
        'Aralık #1 · 110/500\n🟩⬛⬛⬛🟨',
      );
    });

    test('says "deneme" before the epoch', () {
      expect(
        dailyShareText(
          dayIndex: -3,
          points: [0, 0, 0, 0, 0],
          hits: 0,
          answered: 5,
        ),
        startsWith('Aralık (deneme) · 0/500'),
      );
    });
  });

  group('currentStreak', () {
    test('counts back from today', () {
      expect(currentStreak({3, 4, 5}, 5), 3);
    });

    test('stays alive until today is played', () {
      expect(currentStreak({3, 4}, 5), 2);
    });

    test('breaks on a missed day', () {
      expect(currentStreak({1, 2, 4}, 5), 1);
      expect(currentStreak({1, 2}, 5), 0);
      expect(currentStreak({}, 5), 0);
    });

    test('works before the epoch', () {
      expect(currentStreak({-2, -1}, -1), 2);
    });
  });

  test('formatPercent', () {
    expect(formatPercent(0.8), '%80');
    expect(formatPercent(0.625), '%63');
    expect(formatPercent(1), '%100');
    expect(formatPercent(0), '%0');
  });

  group('calibrationSummary', () {
    test('asks for more games first', () {
      expect(calibrationSummary(3, 3), contains('Birkaç gün oyna'));
    });

    test('shows the rate with feedback', () {
      expect(calibrationSummary(62, 100), '%62 · Aralıkların fazla dar.');
      expect(calibrationSummary(10, 10), '%100 · Daha cesur ol.');
      expect(calibrationSummary(9, 10), '%90 · Harika, tam kıvamında.');
    });
  });

  group('barPositions', () {
    test('keeps everything inside the bar', () {
      for (final (low, high, answer) in [
        (4500, 5500, 5137),
        (100, 200, 5000),
        (5000, 9000, 10),
        (7, 7, 7),
      ]) {
        final p = barPositions(
          isYear: false,
          low: low,
          high: high,
          answer: answer,
        );
        for (final v in [p.low, p.high, p.answer]) {
          expect(v, inInclusiveRange(0, 1), reason: '$low $high $answer');
        }
        expect(p.low, lessThanOrEqualTo(p.high));
      }
    });

    test('puts a hit inside the band and a miss outside', () {
      final hit = barPositions(
        isYear: true,
        low: 1915,
        high: 1925,
        answer: 1923,
      );
      expect(hit.answer, inInclusiveRange(hit.low, hit.high));
      final miss = barPositions(
        isYear: true,
        low: 1900,
        high: 1910,
        answer: 1923,
      );
      expect(miss.answer, greaterThan(miss.high));
    });

    test('uses a log axis for magnitudes', () {
      // ×10 on each side of 1.000 → the guess sits in the middle.
      final p = barPositions(
        isYear: false,
        low: 100,
        high: 10000,
        answer: 1000,
      );
      expect(p.answer, closeTo((p.low + p.high) / 2, 1e-9));
    });
  });

  test('questionsPerDay matches the 5-square card', () {
    expect(questionsPerDay, 5);
  });
}
