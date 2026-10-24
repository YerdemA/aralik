import 'package:flutter/material.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';

class AralikApp extends StatelessWidget {
  const AralikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
