import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The moments coil gives haptic feedback for (DESIGN.md §8.6).
enum CoilHapticEvent {
  /// A toggle flips (switch, checkbox) or a segment changes.
  toggle,

  /// A row is picked in a sheet.
  pick,

  /// A copy action succeeded (InputCopy).
  copy,

  /// A sheet snapped to a detent.
  detent,
}

/// Plays the platform's haptic for a [CoilHapticEvent], or nothing where
/// the platform has no convention for it (DESIGN.md §8.6):
///
/// | Event | iOS | Android | Desktop |
/// |---|---|---|---|
/// | toggle, pick | selectionClick | none | none |
/// | copy | selectionClick | selectionClick | none |
/// | detent | lightImpact | none | none |
///
/// Components call this instead of [HapticFeedback], so the mapping lives in
/// one place.
abstract final class CoilHaptics {
  /// Plays [event]'s haptic on the current platform.
  static Future<void> play(CoilHapticEvent event) async {
    if (kIsWeb) return;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final android = defaultTargetPlatform == TargetPlatform.android;
    switch (event) {
      case CoilHapticEvent.toggle:
      case CoilHapticEvent.pick:
        if (ios) await HapticFeedback.selectionClick();
      case CoilHapticEvent.copy:
        if (ios || android) await HapticFeedback.selectionClick();
      case CoilHapticEvent.detent:
        if (ios) await HapticFeedback.lightImpact();
    }
  }
}
