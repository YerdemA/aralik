import 'dart:convert';

import 'package:aralik/core/mascot_look.dart';
import 'package:aralik/core/reaction.dart';
import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/features/duel/duel_screen.dart';
import 'package:aralik/widgets/reactions.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/duel_client_test.dart' show FakeChannel;

void main() {
  group('Reaction', () {
    test('the same eight ids as the server (src/reactions.js)', () {
      expect(Reaction.values.map((r) => r.id), [
        'angry', 'laugh', 'sad', 'wow', //
        'easy', 'close', 'lucky', 'congrats',
      ]);
      expect(Reaction.values.where((r) => r.isFace), hasLength(4));
      expect(Reaction.congrats.label, 'Tebrikler!');
      expect(Reaction.lucky.label, 'Çalışmadığım yerden!');
    });

    test('sends {t: react, r: id}', () {
      expect(jsonDecode(Reaction.laugh.message), {'t': 'react', 'r': 'laugh'});
    });

    test('parses a duel and a tournament reaction, nothing else', () {
      expect(parseReaction('{"t":"react","seat":1,"r":"sad"}'), (
        from: 1,
        reaction: Reaction.sad,
      ));
      expect(parseReaction('{"t":"react","id":7,"r":"easy"}'), (
        from: 7,
        reaction: Reaction.easy,
      ));
      expect(parseReaction('{"t":"react","seat":1,"r":"hello"}'), isNull);
      expect(parseReaction('{"t":"react","r":"sad"}'), isNull);
      expect(parseReaction('{"t":"lock","i":0}'), isNull);
      expect(parseReaction('{"t":"react",'), isNull);
    });
  });

  Future<void> pumpButton(WidgetTester tester, List<Reaction> picked) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Stack(
              children: [
                ReactionDock(
                  child: ReactionButton(
                    look: MascotLook.philosopher,
                    onSelected: picked.add,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  testWidgets('a tap opens the panel; a tap on a message sends it', (
    tester,
  ) async {
    final picked = <Reaction>[];
    await pumpButton(tester, picked);
    await tester.tap(find.bySemanticsLabel(AppStrings.reactionButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.reactionCongrats), findsOneWidget);
    await tester.tap(find.text(AppStrings.reactionCongrats));
    await tester.pumpAndSettle();
    expect(picked, [Reaction.congrats]);
    expect(find.text(AppStrings.reactionCongrats), findsNothing);

    // Resting: a second tap does nothing until the cooldown is over.
    await tester.tap(find.bySemanticsLabel(AppStrings.reactionButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.reactionEasy), findsNothing);
    await tester.pump(reactionCooldown);
    await tester.tap(find.bySemanticsLabel(AppStrings.reactionButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.reactionEasy), findsOneWidget);
  });

  testWidgets('hold, slide onto a reaction and let go', (tester) async {
    final picked = <Reaction>[];
    await pumpButton(tester, picked);
    final button = tester.getCenter(
      find.bySemanticsLabel(AppStrings.reactionButton),
    );
    final gesture = await tester.startGesture(button);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    final target = tester.getCenter(find.text(AppStrings.reactionClose));
    await gesture.moveTo(target);
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(picked, [Reaction.close]);
    expect(find.text(AppStrings.reactionClose), findsNothing);
  });

  testWidgets('a face moves for a while, then rests', (tester) async {
    for (final r in Reaction.values.where((r) => r.isFace)) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ReactionMotion(
              key: ValueKey(r),
              reaction: r,
              child: const SizedBox.square(dimension: 40),
            ),
          ),
        ),
      );
      final start = tester.getRect(find.byType(SizedBox).last);
      await tester.pump();
      await tester.pump(ReactionMotion.periodOf(r) * 0.3);
      final moved = find.descendant(
        of: find.byType(ReactionMotion),
        matching: find.byType(Transform),
      );
      expect(moved, findsWidgets, reason: r.id);
      // Not a loop: it settles, back where it began.
      await tester.pumpAndSettle();
      expect(moved, findsNothing, reason: r.id);
      expect(tester.getRect(find.byType(SizedBox).last), start);
    }
  });

  testWidgets('letting go outside the panel sends nothing', (tester) async {
    final picked = <Reaction>[];
    await pumpButton(tester, picked);
    final button = tester.getCenter(
      find.bySemanticsLabel(AppStrings.reactionButton),
    );
    final gesture = await tester.startGesture(button);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    await gesture.moveTo(const Offset(20, 700));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(find.text(AppStrings.reactionClose), findsNothing);
  });

  testWidgets('in a duel: sends a reaction and shows the opponent\'s', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final repository = QuestionRepository();
    final bank = await tester.runAsync(repository.load);
    final channel = FakeChannel();
    final service = DuelService(
      serviceUri: () => Uri.parse('https://lb.example/'),
      connect: (_) async => channel,
    );
    void say(Map<String, Object?> m) => channel.incoming.add(jsonEncode(m));
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelScreen(
          service: service,
          repository: repository,
          stats: stats,
          code: 'K7M2P',
          name: 'Ayşe',
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle();
    say({
      't': 'start',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': [bank!.first.id],
      'questionMs': 15000,
    });
    say({'t': 'question', 'i': 0, 'ms': 15000});
    await settle();

    say({'t': 'react', 'seat': 1, 'r': 'congrats'});
    await settle();
    expect(find.text(AppStrings.reactionCongrats), findsOneWidget);
    await tester.pump(reactionShown);
    await settle();
    expect(find.text(AppStrings.reactionCongrats), findsNothing);

    await tester.tap(find.bySemanticsLabel(AppStrings.reactionButton));
    await settle();
    await tester.tap(find.text(AppStrings.reactionEasy));
    await settle();
    expect(channel.sent, contains(Reaction.easy.message));
    // This player's own reaction shows too.
    expect(find.text(AppStrings.reactionEasy), findsOneWidget);
    await tester.pump(reactionShown);
    await settle();
  });
}
