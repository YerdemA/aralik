import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'data/question_repository.dart';
import 'data/settings_store.dart';
import 'data/stats_store.dart';
import 'features/home/home_screen.dart';
import 'features/intro/intro_screen.dart';

class KabacaApp extends StatelessWidget {
  const KabacaApp({
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
        // Status bar icons follow the theme (dark icons on the light
        // theme); the intro sets its own light icons on navy.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: child!,
        ),
        home: IntroScreen(
          next: HomeScreen(
            repository: repository,
            stats: stats,
            settings: settings,
          ),
        ),
      ),
    );
  }
}
