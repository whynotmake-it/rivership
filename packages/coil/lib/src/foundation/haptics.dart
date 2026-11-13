import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The moments coil gives haptic feedback for.
enum CoilHapticEvent {
  /// A toggle flips (switch, checkbox) or a segment changes.
  toggle,

  /// A row is picked in a sheet.
  pick,

  /// A long press opens a menu.
  longPress,

  /// A copy action succeeded.
  copy,

  /// A sheet snaps to a detent.
  detent,
}

/// A haptic the platform can play.
enum CoilHaptic {
  /// [HapticFeedback.selectionClick].
  selectionClick,

  /// [HapticFeedback.lightImpact].
  lightImpact,

  /// [HapticFeedback.mediumImpact].
  mediumImpact,

  /// [HapticFeedback.heavyImpact].
  heavyImpact,

  /// [Feedback.forLongPress]: Android's long-press buzz and its
  /// accessibility event.
  longPress,
}

/// Which haptic each [CoilHapticEvent] plays; null plays nothing.
///
/// Set it on [CoilThemeData.haptics]. Left null there, coil uses
/// [CoilHaptics.platform], the conventions of the platform it runs on.
/// [CoilHaptics.none] turns haptics off. Components play them with
/// [CoilHaptics.play].
@immutable
class CoilHaptics with Diagnosticable {
  /// Creates a mapping. Unset events play nothing.
  const CoilHaptics({
    this.toggle,
    this.pick,
    this.longPress,
    this.copy,
    this.detent,
  });

  /// The conventions of [platform]:
  ///
  /// | Event | iOS | Android | Others |
  /// |---|---|---|---|
  /// | toggle, pick | selectionClick | none | none |
  /// | longPress | mediumImpact | longPress | none |
  /// | copy | selectionClick | selectionClick | none |
  /// | detent | lightImpact | none | none |
  factory CoilHaptics.platform(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS => const CoilHaptics(
      toggle: CoilHaptic.selectionClick,
      pick: CoilHaptic.selectionClick,
      longPress: CoilHaptic.mediumImpact,
      copy: CoilHaptic.selectionClick,
      detent: CoilHaptic.lightImpact,
    ),
    TargetPlatform.android => const CoilHaptics(
      longPress: CoilHaptic.longPress,
      copy: CoilHaptic.selectionClick,
    ),
    _ => none,
  };

  /// No haptics.
  static const none = CoilHaptics();

  /// For toggles and segment changes.
  final CoilHaptic? toggle;

  /// For a pick in a sheet.
  final CoilHaptic? pick;

  /// For a menu opened by long press.
  final CoilHaptic? longPress;

  /// For a successful copy.
  final CoilHaptic? copy;

  /// For a sheet snapping to a detent.
  final CoilHaptic? detent;

  /// The haptic for [event].
  CoilHaptic? operator [](CoilHapticEvent event) => switch (event) {
    CoilHapticEvent.toggle => toggle,
    CoilHapticEvent.pick => pick,
    CoilHapticEvent.longPress => longPress,
    CoilHapticEvent.copy => copy,
    CoilHapticEvent.detent => detent,
  };

  /// The mapping at [context]: the theme's, else the platform's. None on
  /// the web, which has no haptics API.
  // A lookup, like Theme.of.
  // ignore: prefer_constructors_over_static_methods
  static CoilHaptics of(BuildContext context) =>
      CoilTheme.of(context).haptics ??
      (kIsWeb ? none : CoilHaptics.platform(defaultTargetPlatform));

  /// Plays [event]'s haptic at [context], if it has one.
  static Future<void> play(BuildContext context, CoilHapticEvent event) =>
      switch (of(context)[event]) {
        null => Future.value(),
        CoilHaptic.selectionClick => HapticFeedback.selectionClick(),
        CoilHaptic.lightImpact => HapticFeedback.lightImpact(),
        CoilHaptic.mediumImpact => HapticFeedback.mediumImpact(),
        CoilHaptic.heavyImpact => HapticFeedback.heavyImpact(),
        CoilHaptic.longPress => Feedback.forLongPress(context),
      };

  /// A copy with the given events remapped. To silence one, build a new
  /// mapping without it.
  CoilHaptics copyWith({
    CoilHaptic? toggle,
    CoilHaptic? pick,
    CoilHaptic? longPress,
    CoilHaptic? copy,
    CoilHaptic? detent,
  }) => CoilHaptics(
    toggle: toggle ?? this.toggle,
    pick: pick ?? this.pick,
    longPress: longPress ?? this.longPress,
    copy: copy ?? this.copy,
    detent: detent ?? this.detent,
  );

  @override
  bool operator ==(Object other) =>
      other is CoilHaptics &&
      other.toggle == toggle &&
      other.pick == pick &&
      other.longPress == longPress &&
      other.copy == copy &&
      other.detent == detent;

  @override
  int get hashCode => Object.hash(toggle, pick, longPress, copy, detent);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    for (final event in CoilHapticEvent.values) {
      properties.add(EnumProperty(event.name, this[event], defaultValue: null));
    }
  }
}
