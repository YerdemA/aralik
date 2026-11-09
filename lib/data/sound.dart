import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/question_timer.dart';
import '../core/scoring.dart';

/// The app's sound effects (assets/sounds/, Ogg Vorbis made by
/// tools/sounds/make_sounds.py; iOS cannot play Ogg and gets the same
/// sounds as IMA4 CAF files from assets/sounds/ios/).
enum Sfx {
  /// The app opens (the intro screen). Loaded first.
  intro('intro'),

  /// Any enabled button, card or key (widgets/tap_sounds.dart).
  tap('tap'),

  /// A page opens / closes (widgets/tap_sounds.dart).
  page('page'),
  back('back'),

  /// An interval locked.
  lock('lock'),

  /// A hit with ≥70 points (🟩).
  good('good'),

  /// A hit with a wide interval (🟨).
  partial('partial'),

  /// A miss or a timeout (⬛).
  miss('miss'),

  /// Each of the last seconds of the clock.
  tick('tick'),

  /// A daily set or a free-play round finished.
  done('done'),

  /// A duel's first question.
  duelStart('duel_start'),
  duelWin('duel_win'),
  duelLoss('duel_loss'),
  duelDraw('duel_draw');

  const Sfx(this.file);

  /// File name without extension; also the name on the platform side.
  final String file;

  String get asset => assetFor(defaultTargetPlatform);

  /// The file the platform side can play: Ogg on Android, CAF on iOS.
  String assetFor(TargetPlatform platform) => platform == TargetPlatform.iOS
      ? 'assets/sounds/ios/$file.caf'
      : 'assets/sounds/$file.ogg';

  /// The sound of a question's outcome.
  static Sfx of(ResultTier tier) => switch (tier) {
    ResultTier.good => good,
    ResultTier.partial => partial,
    ResultTier.miss => miss,
  };
}

/// Whether the clock just entered a new second of its last
/// [timeWarning] (one tick per second, none at zero).
bool clockTicks(Duration? before, Duration left) =>
    before != null &&
    left > Duration.zero &&
    left <= timeWarning &&
    secondsShown(left) != secondsShown(before);

/// Plays [Sfx] through a SoundPool in MainActivity.kt or AVAudioPlayers in
/// AppDelegate.swift (no package). Silent
/// when [enabled] is off, when the phone is on silent or vibrate, and where
/// there is no platform side (tests).
abstract final class Sounds {
  static const _channel = MethodChannel('com.yerdema.kabaca/sound');

  /// Follows the "Ses efektleri" setting.
  static bool enabled = true;

  /// Every played effect in order; set in tests to listen.
  @visibleForTesting
  static List<Sfx>? played;

  static Future<void>? _loading;
  static final _ready = Completer<void>();

  /// How many effects were asked for so far (for [playTap]).
  static int _plays = 0;
  static DateTime _lastPlayed = DateTime.fromMillisecondsSinceEpoch(0);

  /// Hands every sound to the platform once; later calls reuse the first.
  static Future<void> preload({AssetBundle? bundle}) =>
      _loading ??= _load(bundle ?? rootBundle);

  /// Plays [Sfx.intro] as soon as it is loaded (it is loaded first).
  static void playIntro() {
    if (_ready.isCompleted) {
      play(Sfx.intro);
    } else {
      _ready.future.then((_) => play(Sfx.intro));
    }
  }

  static Future<void> _load(AssetBundle bundle) async {
    try {
      await _loadAll(bundle);
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  static Future<void> _loadAll(AssetBundle bundle) async {
    for (final sfx in Sfx.values) {
      try {
        final data = await bundle.load(sfx.asset);
        await _channel.invokeMethod<bool>('load', {
          'name': sfx.file,
          'bytes': data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
        });
      } on MissingPluginException {
        return; // no platform side
      } on Object catch (error) {
        debugPrint('Sound ${sfx.file} not loaded: $error');
      }
      if (sfx == Sfx.intro && !_ready.isCompleted) _ready.complete();
    }
  }

  /// Fire and forget: a missing sound never disturbs the game.
  static void play(Sfx sfx) {
    if (!enabled) return;
    _plays++;
    _lastPlayed = DateTime.now();
    played?.add(sfx);
    _channel
        .invokeMethod<bool>('play', {'name': sfx.file})
        .then<void>((_) {}, onError: (Object _) {});
  }

  /// The tap sound, a moment later and only if the tap itself played
  /// nothing (a lock, a page): one sound per touch.
  static void playTap() {
    if (!enabled) return;
    final before = _plays;
    Timer(tapDelay, () {
      if (_plays == before) play(Sfx.tap);
    });
  }

  @visibleForTesting
  static const tapDelay = Duration(milliseconds: 40);

  /// Plays [sfx] unless another effect started within [window] (a page
  /// opened right after a result sound stays quiet).
  static void playUnlessRecent(
    Sfx sfx, {
    Duration window = const Duration(milliseconds: 300),
  }) {
    if (DateTime.now().difference(_lastPlayed) < window) return;
    play(sfx);
  }
}
