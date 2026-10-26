import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/content_sync.dart';
import 'data/question_repository.dart';
import 'data/stats_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final content = ContentSync(prefs);
  final repository = QuestionRepository(remote: content);
  // Warm the bank cache. A failure is retried on play.
  repository.load().ignore();
  runApp(AralikApp(repository: repository, stats: StatsStore(prefs)));

  // Look for new questions in the background; used from the next launch.
  content.sync(accept: repository.acceptsContent).ignore();
}
