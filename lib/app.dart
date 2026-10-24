import 'package:flutter/material.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'data/question_repository.dart';
import 'data/stats_store.dart';
import 'features/home/home_screen.dart';

class AralikApp extends StatelessWidget {
  const AralikApp({super.key, required this.repository, required this.stats});

  final QuestionRepository repository;
  final StatsStore stats;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: HomeScreen(repository: repository, stats: stats),
    );
  }
}
