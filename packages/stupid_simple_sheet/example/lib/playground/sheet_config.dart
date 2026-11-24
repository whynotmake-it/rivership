// ignore: deprecated_member_use
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/playground/playground_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';

/// Which route opens the sheet.
enum SheetRouteKind {
  /// coil's sheet, on `StupidSimpleSheetRoute`.
  coil('coil'),

  /// The bare route, with `SheetBackground` for the surface.
  plain('Plain'),

  /// The iOS 26 glass route.
  glass('Glass'),

  /// The iOS 18 Cupertino route.
  cupertino('Cupertino');

  const SheetRouteKind(this.label);

  /// The route's name in the settings.
  final String label;
}

/// A height the sheet snaps to, as a fraction of its full height.
enum SheetStop {
  /// A quarter of the way up.
  quarter(0.25, '25 %', '25 %'),

  /// Halfway up.
  half(0.5, '50 %', '50 %'),

  /// Three quarters of the way up.
  threeQuarter(0.75, '75 %', '75 %'),

  /// All the way up.
  full(1, 'Full', 'full');

  const SheetStop(this.fraction, this.label, this.inSentence);

  /// The snapping point, as `SheetSnappingConfig` takes it.
  final double fraction;

  /// The stop's name in the settings.
  final String label;

  /// The stop's name inside a sentence.
  final String inSentence;

  /// The fraction as it reads in Dart source.
  String get code => fraction == 1 ? '1.0' : '$fraction';
}

/// Which model picks the stop a fling lands on.
enum SnapPhysicsKind {
  /// `FlingSnapPhysics`: a fling goes to the next stop along.
  fling('Fling'),

  /// `FrictionSnapPhysics`: a fling projects to where it would settle.
  friction('Friction');

  const SnapPhysicsKind(this.label);

  /// The model's name in the settings.
  final String label;
}

/// What the sheet shows.
enum SheetContentKind {
  /// Forty rows, for dragging and scroll handoff.
  longList('Long list'),

  /// Two lines, so the sheet hugs its content.
  short('Short'),

  /// A text field, for the keyboard inset.
  textField('Text field'),

  /// A horizontal pager of lists, which takes its own scroll behavior.
  pages('Pages');

  const SheetContentKind(this.label);

  /// The content's name in the settings.
  final String label;
}

/// A spring preset for the sheet's motion.
enum SheetMotionPreset {
  /// `CupertinoMotion.smooth`, the routes' default.
  smooth('Smooth'),

  /// `CupertinoMotion.snappy`.
  snappy('Snappy'),

  /// `CupertinoMotion.bouncy`.
  bouncy('Bouncy');

  const SheetMotionPreset(this.label);

  /// The preset's name in the settings.
  final String label;
}

/// A setting that not every route takes.
enum SheetSetting {
  /// The spring the sheet animates on.
  motion,

  /// Whether the sheet can be dragged.
  draggable,

  /// Whether a tap outside closes the sheet.
  barrierDismissible,

  /// Whether the sheet sits above the keyboard.
  aboveKeyboard,

  /// When the page behind is rasterized.
  snapshot,
}

/// One sheet, configured: what the playground opens and what its snippet
/// shows, so the two can't drift.
@immutable
class SheetConfig {
  /// Creates a configuration. Every default is the package's own, so
  /// [toCode] starts with no parameters at all.
  const SheetConfig({
    this.route = SheetRouteKind.coil,
    this.stops = const {SheetStop.full},
    this.openAt = SheetStop.full,
    this.physics = SnapPhysicsKind.fling,
    this.handoff = SheetDragHandoff.gestureStart,
    this.dismissal = DismissalMode.slide,
    this.draggable = true,
    this.barrierDismissible = true,
    this.confirmBeforeClosing = false,
    this.aboveKeyboard = false,
    this.content = SheetContentKind.longList,
    this.snapshot = RouteSnapshotMode.never,
    this.motion = SheetMotionPreset.smooth,
  });

  /// The route that opens the sheet.
  final SheetRouteKind route;

  /// The heights the sheet snaps to. Never empty.
  final Set<SheetStop> stops;

  /// The stop the sheet opens at, when [stops] still holds it.
  final SheetStop openAt;

  /// Which model picks the stop a fling lands on.
  final SnapPhysicsKind physics;

  /// When a scrolling gesture can hand the drag to the sheet.
  final SheetDragHandoff handoff;

  /// How the sheet leaves the screen.
  final DismissalMode dismissal;

  /// Whether the sheet can be dragged.
  final bool draggable;

  /// Whether a tap outside closes the sheet.
  final bool barrierDismissible;

  /// Whether a dismissal asks before it closes the sheet.
  final bool confirmBeforeClosing;

  /// Whether the sheet sits above the keyboard.
  final bool aboveKeyboard;

  /// What the sheet shows.
  final SheetContentKind content;

  /// When the page behind the sheet is rasterized.
  final RouteSnapshotMode snapshot;

  /// The spring the sheet animates on.
  final SheetMotionPreset motion;

  /// A copy with the given settings changed.
  SheetConfig copyWith({
    SheetRouteKind? route,
    Set<SheetStop>? stops,
    SheetStop? openAt,
    SnapPhysicsKind? physics,
    SheetDragHandoff? handoff,
    DismissalMode? dismissal,
    bool? draggable,
    bool? barrierDismissible,
    bool? confirmBeforeClosing,
    bool? aboveKeyboard,
    SheetContentKind? content,
    RouteSnapshotMode? snapshot,
    SheetMotionPreset? motion,
  }) => SheetConfig(
    route: route ?? this.route,
    stops: stops ?? this.stops,
    openAt: openAt ?? this.openAt,
    physics: physics ?? this.physics,
    handoff: handoff ?? this.handoff,
    dismissal: dismissal ?? this.dismissal,
    draggable: draggable ?? this.draggable,
    barrierDismissible: barrierDismissible ?? this.barrierDismissible,
    confirmBeforeClosing: confirmBeforeClosing ?? this.confirmBeforeClosing,
    aboveKeyboard: aboveKeyboard ?? this.aboveKeyboard,
    content: content ?? this.content,
    snapshot: snapshot ?? this.snapshot,
    motion: motion ?? this.motion,
  );

  /// The stops, lowest first.
  List<SheetStop> get sortedStops =>
      stops.toList()..sort((a, b) => a.fraction.compareTo(b.fraction));

  /// The stop the sheet opens at: [openAt] while it is one of the [stops],
  /// else the lowest one, which is what the package falls back to.
  SheetStop get effectiveOpenAt =>
      stops.contains(openAt) ? openAt : sortedStops.first;

  /// Why [setting] is fixed on this [route], or null when the route takes
  /// it. One sentence, shown under the control.
  String? disabledReason(SheetSetting setting) => switch ((route, setting)) {
    (SheetRouteKind.coil, SheetSetting.motion) =>
      "coil's sheet moves on the theme's motion tokens.",
    (SheetRouteKind.coil, SheetSetting.aboveKeyboard) =>
      "coil's sheet always rides on the keyboard.",
    (
      SheetRouteKind.glass || SheetRouteKind.cupertino,
      SheetSetting.barrierDismissible,
    ) =>
      'These routes close on a tap outside only with a stop below full.',
    _ => null,
  };

  /// Whether this [route] takes [setting].
  bool takes(SheetSetting setting) => disabledReason(setting) == null;

  /// Whether the opened sheet can be dragged.
  bool get effectiveDraggable => !takes(SheetSetting.draggable) || draggable;

  /// Whether a tap outside the opened sheet closes it.
  bool get effectiveBarrierDismissible => takes(SheetSetting.barrierDismissible)
      ? barrierDismissible
      : snappingConfig.hasInbetweenSnaps;

  /// Whether the opened sheet sits above the keyboard.
  bool get effectiveAboveKeyboard =>
      takes(SheetSetting.aboveKeyboard) ? aboveKeyboard : true;

  /// When the page behind the opened sheet is rasterized.
  RouteSnapshotMode get effectiveSnapshot =>
      takes(SheetSetting.snapshot) ? snapshot : RouteSnapshotMode.never;

  /// The spring the opened sheet animates on, or null where the route
  /// brings its own motion.
  Motion? get effectiveMotion => takes(SheetSetting.motion)
      ? switch (motion) {
          SheetMotionPreset.smooth => null,
          SheetMotionPreset.snappy => const CupertinoMotion.snappy(),
          SheetMotionPreset.bouncy => const CupertinoMotion.bouncy(),
        }
      : null;

  /// The snapping configuration the routes take.
  SheetSnappingConfig get snappingConfig => SheetSnappingConfig(
    [for (final stop in sortedStops) stop.fraction],
    initialSnap: effectiveOpenAt == sortedStops.first
        ? null
        : effectiveOpenAt.fraction,
    physics: switch (physics) {
      SnapPhysicsKind.fling => const FlingSnapPhysics(),
      SnapPhysicsKind.friction => const FrictionSnapPhysics(),
    },
  );

  /// Whether the snapping is the package's default: the full height only,
  /// on fling physics.
  bool get _snappingIsDefault =>
      setEquals(stops, const {SheetStop.full}) &&
      physics == SnapPhysicsKind.fling;

  /// The sheet's settings in one muted line, shown at the top of the
  /// sheet: "Stops at 50 % and full · shrink · continuous handoff".
  String get summary {
    final stopsPhrase = switch (sortedStops) {
      [SheetStop.full] => 'Full height',
      final list => 'Stops at ${_list([for (final s in list) s.inSentence])}',
    };
    return [
      stopsPhrase,
      if (sortedStops.length > 1 && effectiveOpenAt != sortedStops.first)
        'opens at ${effectiveOpenAt.inSentence}',
      if (physics == SnapPhysicsKind.friction) 'friction physics',
      if (dismissal == DismissalMode.shrink) 'shrink',
      if (handoff == SheetDragHandoff.continuous) 'continuous handoff',
      if (!effectiveDraggable) 'not draggable',
      if (!effectiveBarrierDismissible) 'stays open on a tap outside',
      if (confirmBeforeClosing) 'asks before closing',
      if (effectiveSnapshot != RouteSnapshotMode.never)
        '${effectiveSnapshot.name} snapshot',
      if (effectiveMotion != null) '${motion.label.toLowerCase()} spring',
    ].join(' · ');
  }

  /// Opens the sheet this configuration describes, exactly as [toCode]
  /// spells it out.
  Future<void> open(BuildContext context) {
    final navigator = Navigator.of(context);
    final cupertinoBackground = CupertinoDynamicColor.resolve(
      CupertinoColors.systemGroupedBackground,
      context,
    );
    final route = switch (this.route) {
      SheetRouteKind.coil => exampleSheetRoute<void>(
        context: context,
        snappingConfig: snappingConfig,
        dragHandoff: handoff,
        dismissalMode: dismissal,
        draggable: draggable,
        backgroundSnapshotMode: snapshot,
        barrierDismissible: barrierDismissible,
        child: CoilPlaygroundSheet(config: this),
      ),
      SheetRouteKind.plain => StupidSimpleSheetRoute<void>(
        snappingConfig: snappingConfig,
        dragHandoff: handoff,
        dismissalMode: dismissal,
        draggable: draggable,
        barrierDismissible: barrierDismissible,
        originateAboveBottomViewInset: aboveKeyboard,
        backgroundSnapshotMode: snapshot,
        motion: effectiveMotion ?? const CupertinoMotion.smooth(),
        child: SheetBackground.withTopMargin(
          // The content carries the page's theme into the route, which a
          // bare route doesn't do for it.
          child: InheritedTheme.capture(
            from: context,
            to: navigator.context,
          ).wrap(CoilPlaygroundSheet(config: this)),
        ),
      ),
      SheetRouteKind.glass => StupidSimpleGlassSheetRoute<void>(
        snappingConfig: snappingConfig,
        dragHandoff: handoff,
        dismissalMode: dismissal,
        draggable: draggable,
        originateAboveBottomViewInset: aboveKeyboard,
        backgroundSnapshotMode: snapshot,
        backgroundColor: cupertinoBackground,
        motion:
            effectiveMotion ??
            const CupertinoMotion.smooth(duration: Duration(milliseconds: 350)),
        child: CupertinoPlaygroundSheet(config: this, glass: true),
      ),
      SheetRouteKind.cupertino => StupidSimpleCupertinoSheetRoute<void>(
        snappingConfig: snappingConfig,
        dragHandoff: handoff,
        dismissalMode: dismissal,
        draggable: draggable,
        originateAboveBottomViewInset: aboveKeyboard,
        backgroundSnapshotMode: snapshot,
        backgroundColor: cupertinoBackground,
        motion:
            effectiveMotion ??
            const CupertinoMotion.smooth(duration: Duration(milliseconds: 350)),
        child: CupertinoPlaygroundSheet(config: this, glass: false),
      ),
    };
    return navigator.push(route);
  }

  /// The code that opens this sheet: only the parameters that aren't the
  /// route's defaults, in real API names.
  String toCode() {
    final args = <String>[
      if (route == SheetRouteKind.coil) 'context: context,',
      if (!_snappingIsDefault) _snappingCode(),
      if (handoff != SheetDragHandoff.gestureStart)
        'dragHandoff: SheetDragHandoff.continuous,',
      if (dismissal != DismissalMode.slide)
        'dismissalMode: DismissalMode.shrink,',
      if (takes(SheetSetting.draggable) && !draggable) 'draggable: false,',
      if (takes(SheetSetting.barrierDismissible) && !barrierDismissible)
        'barrierDismissible: false,',
      if (takes(SheetSetting.aboveKeyboard) && aboveKeyboard)
        'originateAboveBottomViewInset: true,',
      if (effectiveSnapshot != RouteSnapshotMode.never)
        'backgroundSnapshotMode: RouteSnapshotMode.${snapshot.name},',
      if (effectiveMotion != null)
        'motion: const CupertinoMotion.${motion.name}(),',
      'child: ${_childCode()},',
    ];
    final buffer = StringBuffer();
    buffer.writeln('Navigator.of(context).push(');
    buffer.writeln('  $_constructor');
    for (final arg in args) {
      buffer.writeln('    ${_indent(arg, 4)}');
    }
    buffer.writeln('  ),');
    buffer.write(');');
    return buffer.toString();
  }

  String get _constructor => switch (route) {
    SheetRouteKind.coil => 'CoilSheetRoute<void>(',
    SheetRouteKind.plain => 'StupidSimpleSheetRoute<void>(',
    SheetRouteKind.glass => 'StupidSimpleGlassSheetRoute<void>(',
    SheetRouteKind.cupertino => 'StupidSimpleCupertinoSheetRoute<void>(',
  };

  String _snappingCode() {
    final lines = <String>[
      'snappingConfig: const SheetSnappingConfig(',
      '  [${[for (final stop in sortedStops) stop.code].join(', ')}],',
      if (effectiveOpenAt != sortedStops.first)
        '  initialSnap: ${effectiveOpenAt.code},',
      if (physics == SnapPhysicsKind.friction)
        '  physics: FrictionSnapPhysics(),',
      '),',
    ];
    return lines.join('\n');
  }

  /// The route's `child`, as the sheet is actually built.
  String _childCode() {
    final panel = switch (route) {
      SheetRouteKind.coil => 'CoilSheetPanel(child: YourContent())',
      SheetRouteKind.plain =>
        'SheetBackground.withTopMargin(\n'
            '  child: CoilSheetPanel(child: YourContent()),\n'
            ')',
      SheetRouteKind.glass || SheetRouteKind.cupertino => 'YourContent()',
    };
    if (!confirmBeforeClosing) return panel;
    return 'PopScope(\n'
        '  canPop: false,\n'
        '  onPopInvokedWithResult: (didPop, _) => _askBeforeClosing(context),\n'
        '  child: ${_indent(panel, 2)},\n'
        ')';
  }

  /// Joins [items] into "a", "a and b" or "a, b and c".
  static String _list(List<String> items) => switch (items) {
    [] => '',
    [final one] => one,
    [...final rest, final last] => '${rest.join(', ')} and $last',
  };

  /// Indents every line but the first by [spaces].
  static String _indent(String code, int spaces) {
    final lines = code.split('\n');
    return [
      lines.first,
      for (final line in lines.skip(1))
        line.isEmpty ? line : '${' ' * spaces}$line',
    ].join('\n');
  }

  @override
  bool operator ==(Object other) =>
      other is SheetConfig &&
      other.route == route &&
      setEquals(other.stops, stops) &&
      other.openAt == openAt &&
      other.physics == physics &&
      other.handoff == handoff &&
      other.dismissal == dismissal &&
      other.draggable == draggable &&
      other.barrierDismissible == barrierDismissible &&
      other.confirmBeforeClosing == confirmBeforeClosing &&
      other.aboveKeyboard == aboveKeyboard &&
      other.content == content &&
      other.snapshot == snapshot &&
      other.motion == motion;

  @override
  int get hashCode => Object.hash(
    route,
    Object.hashAllUnordered(stops),
    openAt,
    physics,
    handoff,
    dismissal,
    draggable,
    barrierDismissible,
    confirmBeforeClosing,
    aboveKeyboard,
    content,
    snapshot,
    motion,
  );
}
