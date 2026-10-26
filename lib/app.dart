import 'package:flutter/material.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'data/question_repository.dart';
import 'data/settings_store.dart';
import 'data/stats_store.dart';
import 'features/home/home_screen.dart';

class AralikApp extends StatelessWidget {
  const AralikApp({
    super.key,
    required this.repository,
    required this.stats,
    required this.settings,
  });

  final QuestionRepository repository;
  final StatsStore stats;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.themeMode,
        home: HomeScreen(
          repository: repository,
          stats: stats,
          settings: settings,
        ),
      ),
    );
  }
}
