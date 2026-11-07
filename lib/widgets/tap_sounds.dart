import 'package:flutter/material.dart';

import '../data/sound.dart';

/// Ink splashes that play [Sfx.tap] when a tap is confirmed.
///
/// Every enabled Material tappable (buttons, InkWell cards, list tiles,
/// the number pad keys) draws its splash through the theme's
/// `splashFactory`, and confirms it exactly when the tap lands; a disabled
/// widget draws none and a scroll cancels it. So one theme setting gives
/// every tap its click, with no widget opting in.
///
/// [Sounds.playTap] waits a moment and stays quiet when the tap itself
/// played something (a lock, a page opening): one sound per touch.
class TapSoundSplash extends InkSparkle {
  TapSoundSplash({
    required super.controller,
    required super.referenceBox,
    required super.color,
    required super.position,
    required super.textDirection,
    super.containedInkWell,
    super.rectCallback,
    super.borderRadius,
    super.customBorder,
    super.radius,
    super.onRemoved,
  });

  static const InteractiveInkFeatureFactory splashFactory = _Factory();

  @override
  void confirm() {
    Sounds.playTap();
    super.confirm();
  }
}

class _Factory extends InteractiveInkFeatureFactory {
  const _Factory();

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) => TapSoundSplash(
    controller: controller,
    referenceBox: referenceBox,
    color: color,
    position: position,
    textDirection: textDirection,
    containedInkWell: containedInkWell,
    rectCallback: rectCallback,
    borderRadius: borderRadius,
    customBorder: customBorder,
    radius: radius,
    onRemoved: onRemoved,
  );
}

/// Plays [Sfx.page] when a page opens and [Sfx.back] when one closes.
/// Dialogs and sheets stay quiet (their buttons click), and so does a page
/// change right after another sound (a result, the end of a round).
class PageSounds extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute != null) {
      Sounds.playUnlessRecent(Sfx.page);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) Sounds.playUnlessRecent(Sfx.back);
  }
}
