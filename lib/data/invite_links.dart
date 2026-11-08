import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/invite_link.dart';

/// Invite links (https://kabaca.app/d/KOD, /t/KOD) the app was opened with,
/// from MainActivity.kt: the one that started it, and those that arrive
/// while it runs. The home screen takes each one ([take]) and opens the
/// room's screen. No package: a small channel.
class InviteLinks extends ChangeNotifier {
  InviteLinks._();

  static final instance = InviteLinks._();

  static const _channel = MethodChannel('com.yerdema.kabaca/links');

  Invite? _pending;
  bool _started = false;

  /// The invite waiting to be opened, if any.
  Invite? get pending => _pending;

  /// Starts listening; asks for the link the app was started with.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') receive(call.arguments as String?);
    });
    try {
      receive(await _channel.invokeMethod<String>('initial'));
    } on Object {
      // No Android side (tests, other platforms): no links.
    }
  }

  /// Keeps [link] if it is an invite.
  @visibleForTesting
  void receive(String? link) {
    final invite = link == null ? null : parseInvite(link);
    if (invite == null) return;
    _pending = invite;
    notifyListeners();
  }

  /// The waiting invite, which is then forgotten.
  Invite? take() {
    final invite = _pending;
    _pending = null;
    return invite;
  }
}
