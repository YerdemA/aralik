import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/features/stats/calibration_chart.dart';
import 'package:aralik/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpStats(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final stats = await StatsStore.open();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: StatsScreen(stats: stats, today: 12),
    ),
  );
}

void main() {
  testWidgets('nothing played yet shows a hint', (tester) async {
    await pumpStats(tester);
    expect(find.text(AppStrings.statsEmpty), findsOneWidget);
  });

  testWidgets('shows days, calibration chart, misses and categories', (
    tester,
  ) async {
    await pumpStats(
      tester,
      prefs: {
        'completed_days': ['10', '11', '12'],
        'daily_results_10': ['100:1', '100:1', '100:1', '0:0', '0:0'],
        'daily_results_11': ['50:1', '50:1', '50:1', '50:1', '50:1'],
        'daily_results_12': ['80:1', '80:1', '80:1', '80:1', '-40:0'],
        'answered': 15,
        'hits': 12,
        'answer_log': [
          for (var i = 0; i < 6; i++) 'history:80:h',
          for (var i = 0; i < 6; i++) 'sports:50:h',
          for (var i = 0; i < 5; i++) 'sports:-20:o',
        ],
      },
    );
    expect(find.text('3'), findsOneWidget); // played days
    expect(find.text(AppStrings.streakDays(3)), findsNWidgets(2));
    expect(find.text('277'), findsOneWidget); // average of 300, 250, 280
    expect(find.text('300'), findsOneWidget); // best day
    expect(find.byType(CalibrationChart), findsOneWidget);
    expect(find.text(AppStrings.missBiasHigh), findsOneWidget);
    expect(find.text(AppStrings.categoryHistory), findsOneWidget);
    expect(find.text(AppStrings.categoryTally('%100', 6)), findsOneWidget);
    expect(find.text(AppStrings.categoryTally('%55', 11)), findsOneWidget);
  });

  testWidgets('too few answers for the chart shows a hint', (tester) async {
    await pumpStats(
      tester,
      prefs: {
        'answered': 3,
        'hits': 3,
        'answer_log': ['geography:90:h', 'geography:90:h', 'geography:90:h'],
      },
    );
    expect(find.byType(CalibrationChart), findsNothing);
    expect(find.text(AppStrings.calibrationChartEmpty(10)), findsOneWidget);
  });
}
