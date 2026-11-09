import 'package:flutter/widgets.dart';

/// Where the share sheet points from: the widget of [context] on screen.
/// iPadOS shows the sheet as a popover and needs it; elsewhere it is
/// ignored. Null when the widget has no size yet.
Rect? shareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
