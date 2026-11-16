import 'package:aralik/core/reaction.dart';
import 'package:aralik/core/scoring.dart';
import 'package:aralik/data/sound.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every effect has a small Ogg asset', () async {
    for (final sfx in Sfx.values) {
      final data = await rootBundle.load(sfx.asset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, 4);
      expect(String.fromCharCodes(bytes), 'OggS', reason: sfx.asset);
      expect(data.lengthInBytes, lessThan(24 * 1024), reason: sfx.asset);
    }
  });

  test('every effect has a small CAF asset for iOS', () async {
    for (final sfx in Sfx.values) {
      final asset = sfx.assetFor(TargetPlatform.iOS);
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, 4);
      expect(String.fromCharCodes(bytes), 'caff', reason: asset);
      expect(data.lengthInBytes, lessThan(40 * 1024), reason: asset);
    }
  });

  test('each outcome has its sound', () {
    expect(Sfx.of(ResultTier.good), Sfx.good);
    expect(Sfx.of(ResultTier.partial), Sfx.partial);
    expect(Sfx.of(ResultTier.miss), Sfx.miss);
  });

  test('each face has its own voice; the messages share a bloop', () {
    expect(Sfx.ofReaction(Reaction.angry), Sfx.reactAngry);
    expect(Sfx.ofReaction(Reaction.laugh), Sfx.reactLaugh);
    expect(Sfx.ofReaction(Reaction.sad), Sfx.reactSad);
    expect(Sfx.ofReaction(Reaction.wow), Sfx.reactWow);
    for (final r in Reaction.values.where((r) => !r.isFace)) {
      expect(Sfx.ofReaction(r), Sfx.reactMessage);
    }
  });

  test('the clock ticks once per second in its last five', () {
    Duration ms(int n) => Duration(milliseconds: n);
    expect(clockTicks(null, ms(4800)), isFalse);
    expect(clockTicks(ms(5200), ms(4800)), isTrue); // 6 → 5
    expect(clockTicks(ms(4800), ms(4600)), isFalse); // still 5
    expect(clockTicks(ms(4100), ms(3900)), isTrue); // 5 → 4
    expect(clockTicks(ms(6200), ms(5900)), isFalse); // 7 → 6
    expect(clockTicks(ms(200), Duration.zero), isFalse); // the lock sounds
  });

  test('plays nothing when turned off, and survives no platform', () async {
    final played = Sounds.played = [];
    addTearDown(() {
      Sounds.played = null;
      Sounds.enabled = true;
    });
    Sounds.play(Sfx.lock);
    Sounds.enabled = false;
    Sounds.play(Sfx.miss);
    expect(played, [Sfx.lock]);
    await Sounds.preload();
  });
}
