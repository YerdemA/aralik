import 'package:flutter/material.dart';

import 'app.dart';
import 'data/question_repository.dart';
import 'data/stats_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = QuestionRepository();
  // Warm the bank cache while preferences load. A failure is retried on play.
  repository.load().ignore();
  final stats = await StatsStore.open();
  runApp(AralikApp(repository: repository, stats: stats));
}
