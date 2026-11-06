import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/question_timer.dart';
import '../core/scoring.dart';

/// The app's sound effects (assets/sounds/, made by
/// tools/sounds/make_sounds.py).
enum Sfx {
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

  String get asset => 'assets/sounds/$file.wav';

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

/// Plays [Sfx] through a SoundPool in MainActivity.kt (no package). Silent
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

  /// Hands every sound to the platform once; later calls reuse the first.
  static Future<void> preload({AssetBundle? bundle}) =>
      _loading ??= _load(bundle ?? rootBundle);

  static Future<void> _load(AssetBundle bundle) async {
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
    }
  }

  /// Fire and forget: a missing sound never disturbs the game.
  static void play(Sfx sfx) {
    if (!enabled) return;
    played?.add(sfx);
    _channel
        .invokeMethod<bool>('play', {'name': sfx.file})
        .then<void>((_) {}, onError: (Object _) {});
  }
}
