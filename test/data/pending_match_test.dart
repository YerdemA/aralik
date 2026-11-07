import 'package:aralik/data/pending_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PendingMatchStore store;
  var now = DateTime(2026, 11, 7, 20);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PendingMatchStore(await SharedPreferences.getInstance());
    now = DateTime(2026, 11, 7, 20);
  });

  test('keeps the match while it runs and forgets it once over', () async {
    final keeper = PendingMatchKeeper(
      store,
      kind: PendingKind.duel,
      now: () => now,
    );
    keeper.playing(
      code: 'K7M2P',
      rejoin: 's1',
      name: 'Ayşe',
      window: const Duration(seconds: 60),
    );
    await pumpEventQueue();
    final saved = store.current!;
    expect(saved.kind, PendingKind.duel);
    expect(saved.code, 'K7M2P');
    expect(saved.rejoin, 's1');
    expect(saved.name, 'Ayşe');
    expect(saved.until, now.add(const Duration(seconds: 60)));
    expect(saved.isLive(now.add(const Duration(seconds: 59))), isTrue);
    expect(saved.isLive(now.add(const Duration(seconds: 60))), isFalse);

    // Refreshed every few seconds, not on every event.
    now = now.add(const Duration(seconds: 1));
    keeper.playing(
      code: 'K7M2P',
      rejoin: 's1',
      name: 'Ayşe',
      window: const Duration(seconds: 60),
    );
    await pumpEventQueue();
    expect(store.current!.until, saved.until);
    keeper.playing(
      code: 'K7M2P',
      rejoin: 's1',
      name: 'Ayşe',
      window: const Duration(seconds: 60),
      force: true,
    );
    await pumpEventQueue();
    expect(store.current!.until, now.add(const Duration(seconds: 60)));

    keeper.over();
    await pumpEventQueue();
    expect(store.current, isNull);
  });

  test('another match is not cleared by an old one', () async {
    await store.save(
      PendingMatch(
        kind: PendingKind.tournament,
        code: 'ABCDE',
        rejoin: 'new',
        name: 'Ayşe',
        until: now,
      ),
    );
    await store.clear(rejoin: 'old');
    expect(store.current?.rejoin, 'new');
    await store.clear(rejoin: 'new');
    expect(store.current, isNull);
  });

  test('a tournament is kept for its questions left', () {
    expect(tournamentRejoinWindow(0), const Duration(seconds: 30));
    expect(tournamentRejoinWindow(4), const Duration(seconds: 150));
  });

  test('nothing is kept without a store', () {
    // Tests and screens without one: no crash, nothing saved.
    PendingMatchKeeper(null, kind: PendingKind.duel, now: () => now)
      ..playing(
        code: 'K7M2P',
        rejoin: 's1',
        name: 'Ayşe',
        window: const Duration(seconds: 60),
      )
      ..over();
  });

  test('a broken record reads as none', () async {
    SharedPreferences.setMockInitialValues({'pending_match': '{"kind":1}'});
    final broken = PendingMatchStore(await SharedPreferences.getInstance());
    expect(broken.current, isNull);
    SharedPreferences.setMockInitialValues({'pending_match': 'not json'});
    final garbage = PendingMatchStore(await SharedPreferences.getInstance());
    expect(garbage.current, isNull);
  });
}
