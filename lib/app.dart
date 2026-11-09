import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'data/invite_links.dart';
import 'data/leaderboard.dart';
import 'data/pending_match.dart';
import 'data/question_repository.dart';
import 'data/settings_store.dart';
import 'data/stats_store.dart';
import 'data/store_link.dart';
import 'features/home/home_screen.dart';
import 'features/intro/intro_screen.dart';
import 'widgets/tap_sounds.dart';

class KabacaApp extends StatelessWidget {
  const KabacaApp({
    super.key,
    required this.repository,
    required this.stats,
    required this.settings,
    this.leaderboard,
    this.pending,
    this.latestAppBuild,
    this.openStore,
    this.scoringV2Day,
    this.invites,
  });

  /// Invite links the app was opened with; null in tests.
  final InviteLinks? invites;

  /// A duel or tournament left mid-way, to go back to; null in tests.
  final PendingMatchStore? pending;

  /// First day of the scaled scoring rule (content manifest), or null.
  final int? Function()? scoringV2Day;

  final QuestionRepository repository;
  final StatsStore stats;
  final SettingsStore settings;

  /// Null hides the leaderboard (tests).
  final LeaderboardStore? leaderboard;

  /// The newest build in the store (content manifest), or null.
  final int? Function()? latestAppBuild;

  /// Opens the app's store page; null uses [openStorePage] as it is.
  final Future<bool> Function()? openStore;

  static final _pageSounds = PageSounds();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        // Every tap on an enabled button, card or key clicks softly.
        theme: AppTheme.light.copyWith(
          splashFactory: TapSoundSplash.splashFactory,
        ),
        darkTheme: AppTheme.dark.copyWith(
          splashFactory: TapSoundSplash.splashFactory,
        ),
        themeMode: settings.themeMode,
        navigatorObservers: [_pageSounds],
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
            leaderboard: leaderboard,
            pending: pending,
            latestAppBuild: latestAppBuild,
            openStore: openStore ?? openStorePage,
            scoringV2Day: scoringV2Day,
            invites: invites,
          ),
        ),
      ),
    );
  }
}
