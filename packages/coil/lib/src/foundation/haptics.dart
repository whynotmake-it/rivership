import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The moments Coil gives haptic feedback for.
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

  /// A drawer is dragged past its halfway point, or opens or closes
  /// without a drag.
  drawer,

  /// A stepped slider's value moves to another step.
  step,
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
/// Set it on [CoilThemeData.haptics]. Left null there, Coil uses
/// [CoilHaptics.platform], the conventions of the platform it runs on.
/// [CoilHaptics.none] turns haptics off. Components play them with
/// [CoilHaptics.play].
@immutable
class CoilHaptics with Diagnosticable {
  /// Creates a mapping; unset events play nothing.
  const CoilHaptics({
    this.toggle,
    this.pick,
    this.longPress,
    this.copy,
    this.detent,
    this.drawer,
    this.step,
  });

  /// The conventions of [platform]:
  ///
  /// | Event | iOS | Android | Others |
  /// |---|---|---|---|
  /// | toggle, pick | selectionClick | none | none |
  /// | longPress | mediumImpact | longPress | none |
  /// | copy | selectionClick | selectionClick | none |
  /// | detent | lightImpact | none | none |
  /// | drawer | selectionClick | none | none |
  /// | step | selectionClick | selectionClick | none |
  factory CoilHaptics.platform(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS => const CoilHaptics(
      toggle: CoilHaptic.selectionClick,
      pick: CoilHaptic.selectionClick,
      longPress: CoilHaptic.mediumImpact,
      copy: CoilHaptic.selectionClick,
      detent: CoilHaptic.lightImpact,
      drawer: CoilHaptic.selectionClick,
      step: CoilHaptic.selectionClick,
    ),
    TargetPlatform.android => const CoilHaptics(
      longPress: CoilHaptic.longPress,
      copy: CoilHaptic.selectionClick,
      step: CoilHaptic.selectionClick,
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

  /// For a drawer crossing its halfway point while dragged, and for one
  /// that opens or closes without a drag.
  final CoilHaptic? drawer;

  /// For a stepped slider's value moving to another step.
  final CoilHaptic? step;

  /// The haptic for [event].
  CoilHaptic? operator [](CoilHapticEvent event) => switch (event) {
    CoilHapticEvent.toggle => toggle,
    CoilHapticEvent.pick => pick,
    CoilHapticEvent.longPress => longPress,
    CoilHapticEvent.copy => copy,
    CoilHapticEvent.detent => detent,
    CoilHapticEvent.drawer => drawer,
    CoilHapticEvent.step => step,
  };

  /// The mapping at [context]: the theme's, else the platform's.
  ///
  /// Returns [none] on the web, which has no haptics API.
  // A lookup, like Theme.of.
  // ignore: prefer_constructors_over_static_methods
  static CoilHaptics of(BuildContext context) =>
      CoilTheme.of(context).haptics ??
      (kIsWeb ? none : CoilHaptics.platform(CoilTheme.platformOf(context)));

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

  /// Returns a copy with the given events remapped.
  ///
  /// To silence one, build a new mapping without it.
  CoilHaptics copyWith({
    CoilHaptic? toggle,
    CoilHaptic? pick,
    CoilHaptic? longPress,
    CoilHaptic? copy,
    CoilHaptic? detent,
    CoilHaptic? drawer,
    CoilHaptic? step,
  }) => CoilHaptics(
    toggle: toggle ?? this.toggle,
    pick: pick ?? this.pick,
    longPress: longPress ?? this.longPress,
    copy: copy ?? this.copy,
    detent: detent ?? this.detent,
    drawer: drawer ?? this.drawer,
    step: step ?? this.step,
  );

  @override
  bool operator ==(Object other) =>
      other is CoilHaptics &&
      other.toggle == toggle &&
      other.pick == pick &&
      other.longPress == longPress &&
      other.copy == copy &&
      other.detent == detent &&
      other.drawer == drawer &&
      other.step == step;

  @override
  int get hashCode =>
      Object.hash(toggle, pick, longPress, copy, detent, drawer, step);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    for (final event in CoilHapticEvent.values) {
      properties.add(EnumProperty(event.name, this[event], defaultValue: null));
    }
  }
}
