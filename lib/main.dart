import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/ranked_client.dart';
import 'data/content_sync.dart';
import 'data/invite_links.dart';
import 'data/leaderboard.dart';
import 'data/moderation.dart';
import 'data/pending_match.dart';
import 'data/question_repository.dart';
import 'data/settings_store.dart';
import 'data/sound.dart';
import 'data/stats_store.dart';
import 'data/store_link.dart';

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
  // The monthly ranked duel tables and the month-end recap.
  final ranked = RankedService(
    serviceUri: () => leaderboard.serviceUri,
    account: () => leaderboard.account,
    prefs: prefs,
  );
  Sounds.enabled = settings.soundOn;
  settings.addListener(() => Sounds.enabled = settings.soundOn);
  Sounds.preload().ignore();
  // Reporting and blocking other players' names.
  Moderation.instance = Moderation(
    prefs: prefs,
    report: (name, place) => leaderboard.report(name, place.name),
  );
  // Invite links (kabaca.app/d/KOD) the app was opened with.
  InviteLinks.instance.start().ignore();
  runApp(
    KabacaApp(
      repository: repository,
      stats: StatsStore(prefs),
      settings: settings,
      leaderboard: leaderboard,
      ranked: ranked,
      pending: PendingMatchStore(prefs),
      latestAppBuild: () => content.latestAppBuild,
      openStore: () => openStorePage(appStoreId: content.appStoreId),
      scoringV2Day: () => content.scoringV2Day,
      scoringV3Day: () => content.scoringV3Day,
      invites: InviteLinks.instance,
    ),
  );

  // Look for new questions in the background; used from the next launch.
  // The manifest also names the server: on a first launch duels and the
  // leaderboard appear as soon as it arrives.
  Future<void> syncContent() async {
    await content.sync(accept: repository.acceptsContent);
    leaderboard.serviceChanged();
  }

  syncContent().ignore();
  // A first launch without network: look again when the app comes back.
  AppLifecycleListener(
    onResume: () {
      if (!leaderboard.isAvailable) syncContent().ignore();
    },
  );
}
