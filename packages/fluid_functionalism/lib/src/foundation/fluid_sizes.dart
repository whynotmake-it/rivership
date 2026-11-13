import 'package:fluid_functionalism/fluid_functionalism.dart'
    show FluidThemeData;
import 'package:fluid_functionalism/src/foundation/fluid_theme.dart'
    show FluidThemeData;
import 'package:fluid_functionalism/src/foundation/fluid_typography.dart';
import 'package:flutter/widgets.dart';

/// The input tier a size set is designed for.
enum FluidTier {
  /// Pointer and keyboard. Matches the web: 36 px controls.
  desktop,

  /// Touch screens. Raises every hit target to 44 px while keeping the
  /// proportions of the desktop look.
  touch;

  /// The tier conventionally used on [platform].
  static FluidTier forPlatform(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS ||
    TargetPlatform.android ||
    TargetPlatform.fuchsia => FluidTier.touch,
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => FluidTier.desktop,
  };
}

/// The two steps of the size ladder shared by every control
/// (`lib/size-context.tsx`).
enum FluidDensity {
  /// The default step.
  regular,

  /// One step down for dense surfaces: filter bars, toolbars, sidebars.
  compact,
}

/// Switch geometry for one size step.
@immutable
class FluidSwitchMetrics {
  /// Creates switch metrics.
  const FluidSwitchMetrics({
    required this.trackWidth,
    required this.trackHeight,
    required this.thumbSize,
    required this.pillExtend,
    required this.pressExtend,
    required this.pressShrink,
    this.thumbInset = 2,
  });

  /// Track width.
  final double trackWidth;

  /// Track height.
  final double trackHeight;

  /// Thumb diameter at rest.
  final double thumbSize;

  /// How much wider the thumb gets on hover (it becomes a pill).
  final double pillExtend;

  /// How much wider the thumb gets while pressed.
  final double pressExtend;

  /// How much shorter the thumb gets while pressed.
  final double pressShrink;

  /// Gap between the thumb and the track edge.
  final double thumbInset;

  @override
  bool operator ==(Object other) =>
      other is FluidSwitchMetrics &&
      other.trackWidth == trackWidth &&
      other.trackHeight == trackHeight &&
      other.thumbSize == thumbSize &&
      other.pillExtend == pillExtend &&
      other.pressExtend == pressExtend &&
      other.pressShrink == pressShrink &&
      other.thumbInset == thumbInset;

  @override
  int get hashCode => Object.hash(
    trackWidth,
    trackHeight,
    thumbSize,
    pillExtend,
    pressExtend,
    pressShrink,
    thumbInset,
  );
}

/// Every size token for one tier and density.
///
/// Desktop values are the web's `sizeMap` and component metrics. Touch
/// values are this port's: the control height goes to 44 (regular) and
/// every hit target is at least 44, with type and glyphs scaled up a step so
/// the proportions read the same.
@immutable
class FluidSizes {
  /// Creates a size set. Prefer [FluidSizes.resolve].
  const FluidSizes({
    required this.tier,
    required this.density,
    required this.controlHeight,
    required this.minHitTarget,
    required this.controlPaddingX,
    required this.itemPaddingX,
    required this.gap,
    required this.iconSize,
    required this.body,
    required this.field,
    required this.caption,
    required this.buttonPaddingX,
    required this.buttonIconPaddingX,
    required this.buttonGap,
    required this.switchMetrics,
    required this.switchRowPaddingY,
    required this.checkboxSize,
    required this.checkboxRadius,
    required this.checkboxGlyphSize,
    required this.segmentPadding,
  });

  /// Desktop, regular: the web's `default` step (36 px).
  static const desktop = FluidSizes(
    tier: FluidTier.desktop,
    density: FluidDensity.regular,
    controlHeight: 36,
    minHitTarget: 0,
    controlPaddingX: 12,
    itemPaddingX: 8,
    gap: 8,
    iconSize: 16,
    body: FluidTypeStep(13, 20),
    field: FluidTypeStep(13, 20),
    caption: FluidTypeStep(12, 16),
    buttonPaddingX: 16,
    buttonIconPaddingX: 12,
    buttonGap: 6,
    switchMetrics: FluidSwitchMetrics(
      trackWidth: 34,
      trackHeight: 20,
      thumbSize: 16,
      pillExtend: 2,
      pressExtend: 4,
      pressShrink: 4,
    ),
    switchRowPaddingY: 8,
    checkboxSize: 16,
    checkboxRadius: 5,
    checkboxGlyphSize: 18,
    segmentPadding: 4,
  );

  /// Desktop, compact: the web's `compact` step (28 px).
  static const desktopCompact = FluidSizes(
    tier: FluidTier.desktop,
    density: FluidDensity.compact,
    controlHeight: 28,
    minHitTarget: 0,
    controlPaddingX: 10,
    itemPaddingX: 6,
    gap: 4,
    iconSize: 14,
    body: FluidTypeStep(12, 18),
    field: FluidTypeStep(12, 18),
    caption: FluidTypeStep(11, 14),
    buttonPaddingX: 12,
    buttonIconPaddingX: 8,
    buttonGap: 4,
    switchMetrics: FluidSwitchMetrics(
      trackWidth: 28,
      trackHeight: 16,
      thumbSize: 12,
      pillExtend: 2,
      pressExtend: 3,
      pressShrink: 3,
    ),
    switchRowPaddingY: 4,
    checkboxSize: 14,
    checkboxRadius: 4,
    checkboxGlyphSize: 16,
    segmentPadding: 2,
  );

  /// Touch, regular: 44 px controls.
  ///
  /// Text goes to 15/22 (fields to 16, which also keeps iOS from zooming
  /// into a focused field, as the web's `pointer-coarse:text-[16px]` does).
  static const touch = FluidSizes(
    tier: FluidTier.touch,
    density: FluidDensity.regular,
    controlHeight: 44,
    minHitTarget: 44,
    controlPaddingX: 14,
    itemPaddingX: 10,
    gap: 10,
    iconSize: 18,
    body: FluidTypeStep(15, 22),
    field: FluidTypeStep(16, 22),
    caption: FluidTypeStep(13, 18),
    buttonPaddingX: 20,
    buttonIconPaddingX: 16,
    buttonGap: 8,
    switchMetrics: FluidSwitchMetrics(
      trackWidth: 44,
      trackHeight: 26,
      thumbSize: 22,
      pillExtend: 3,
      pressExtend: 5,
      pressShrink: 5,
    ),
    switchRowPaddingY: 9,
    checkboxSize: 20,
    checkboxRadius: 6,
    checkboxGlyphSize: 22,
    segmentPadding: 4,
  );

  /// Touch, compact: the desktop regular look (36 px) inside a 44 px hit
  /// target.
  static const touchCompact = FluidSizes(
    tier: FluidTier.touch,
    density: FluidDensity.compact,
    controlHeight: 36,
    minHitTarget: 44,
    controlPaddingX: 12,
    itemPaddingX: 8,
    gap: 8,
    iconSize: 16,
    body: FluidTypeStep(14, 20),
    field: FluidTypeStep(16, 20),
    caption: FluidTypeStep(12, 16),
    buttonPaddingX: 16,
    buttonIconPaddingX: 12,
    buttonGap: 6,
    switchMetrics: FluidSwitchMetrics(
      trackWidth: 36,
      trackHeight: 22,
      thumbSize: 18,
      pillExtend: 2,
      pressExtend: 4,
      pressShrink: 4,
    ),
    switchRowPaddingY: 4,
    checkboxSize: 18,
    checkboxRadius: 5,
    checkboxGlyphSize: 20,
    segmentPadding: 2,
  );

  /// The size set for [tier] and [density].
  static FluidSizes resolve(FluidTier tier, FluidDensity density) =>
      switch ((tier, density)) {
        (FluidTier.desktop, FluidDensity.regular) => desktop,
        (FluidTier.desktop, FluidDensity.compact) => desktopCompact,
        (FluidTier.touch, FluidDensity.regular) => touch,
        (FluidTier.touch, FluidDensity.compact) => touchCompact,
      };

  /// The tier these sizes are for.
  final FluidTier tier;

  /// The density these sizes are for.
  final FluidDensity density;

  /// Bounded control height: buttons, inputs, tabs, and list rows.
  final double controlHeight;

  /// The smallest a tappable area may be. Controls whose visual is smaller
  /// (a checkbox, a compact button on touch) pad their hit area out to this.
  /// 0 on desktop.
  final double minHitTarget;

  /// Horizontal padding of bounded controls (inputs, tabs, switch rows).
  final double controlPaddingX;

  /// Horizontal padding of list and menu rows.
  final double itemPaddingX;

  /// Gap between a glyph and its label, and between neighboring controls.
  final double gap;

  /// Leading and trailing icon size inside controls.
  final double iconSize;

  /// Body text inside controls.
  final FluidTypeStep body;

  /// Text inside editable fields.
  final FluidTypeStep field;

  /// Caption text.
  final FluidTypeStep caption;

  /// Button horizontal padding next to a label.
  final double buttonPaddingX;

  /// Button horizontal padding next to an icon (4 px closer to the edge).
  final double buttonIconPaddingX;

  /// Gap between a button's icon and label.
  final double buttonGap;

  /// Switch geometry.
  final FluidSwitchMetrics switchMetrics;

  /// Vertical padding of a labeled switch row.
  final double switchRowPaddingY;

  /// Checkbox square size.
  final double checkboxSize;

  /// Checkbox corner radius.
  final double checkboxRadius;

  /// Size of the check glyph, which overhangs the box slightly.
  final double checkboxGlyphSize;

  /// Padding of a segmented list around its items.
  final double segmentPadding;

  @override
  bool operator ==(Object other) =>
      other is FluidSizes && other.tier == tier && other.density == density;

  @override
  int get hashCode => Object.hash(tier, density);
}

/// Pins a subtree to a size [tier] and/or [density].
///
/// The web's `SizeProvider`. Unset values inherit from the nearest ancestor
/// scope, then from the [FluidThemeData]'s tier and regular density.
class FluidSizeScope extends InheritedWidget {
  /// Creates a size scope.
  const FluidSizeScope({
    required super.child,
    super.key,
    this.tier,
    this.density,
  });

  /// The tier for this subtree, or null to inherit.
  final FluidTier? tier;

  /// The density for this subtree, or null to inherit.
  final FluidDensity? density;

  /// The nearest scope's tier, if any.
  static FluidTier? maybeTierOf(BuildContext context) {
    for (final scope in _scopes(context)) {
      if (scope.tier != null) return scope.tier;
    }
    return null;
  }

  /// The nearest scope's density, if any.
  static FluidDensity? maybeDensityOf(BuildContext context) {
    for (final scope in _scopes(context)) {
      if (scope.density != null) return scope.density;
    }
    return null;
  }

  static Iterable<FluidSizeScope> _scopes(BuildContext context) sync* {
    var element = context
        .getElementForInheritedWidgetOfExactType<FluidSizeScope>();
    while (element != null) {
      context.dependOnInheritedElement(element);
      final scope = element.widget as FluidSizeScope;
      yield scope;
      Element? parent;
      element.visitAncestorElements((ancestor) {
        parent = ancestor;
        return false;
      });
      element = parent
          ?.getElementForInheritedWidgetOfExactType<FluidSizeScope>();
    }
  }

  @override
  bool updateShouldNotify(FluidSizeScope oldWidget) =>
      oldWidget.tier != tier || oldWidget.density != density;
}
