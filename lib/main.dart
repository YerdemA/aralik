import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/content_sync.dart';
import 'data/leaderboard.dart';
import 'data/question_repository.dart';
import 'data/settings_store.dart';
import 'data/sound.dart';
import 'data/stats_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final content = ContentSync(prefs);
  final repository = QuestionRepository(remote: content);
  final leaderboard = LeaderboardStore(
    prefs,
    serviceUri: () => content.leaderboardUri,
  );
  // Warm the bank cache. A failure is retried on play.
  repository.load().ignore();
  final settings = SettingsStore(prefs);
  Sounds.enabled = settings.soundOn;
  settings.addListener(() => Sounds.enabled = settings.soundOn);
  Sounds.preload().ignore();
  runApp(
    KabacaApp(
      repository: repository,
      stats: StatsStore(prefs),
      settings: settings,
      leaderboard: leaderboard,
      latestAppBuild: () => content.latestAppBuild,
      scoringV2Day: () => content.scoringV2Day,
    ),
  );

  // Look for new questions in the background; used from the next launch.
  content.sync(accept: repository.acceptsContent).ignore();
}
