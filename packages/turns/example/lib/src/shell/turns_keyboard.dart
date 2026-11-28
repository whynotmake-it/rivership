import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Height of the on-screen keyboard over the bottom of the view.
///
/// The demos lift their composer by this much so it stays above the keyboard,
/// and the transcript keeps the same amount clear below its last message.
double keyboardInsetOf(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom;

/// Closes the on-screen keyboard after a message is sent on a phone or tablet,
/// so the reply gets the whole screen.
///
/// On desktop the composer keeps its focus, so the next message can be typed
/// straight away.
void dismissKeyboardOnMobile() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia:
      FocusManager.instance.primaryFocus?.unfocus();
    case TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows:
      break;
  }
}
