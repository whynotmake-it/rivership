import 'package:coil/src/foundation/typography.dart';
import 'package:flutter/foundation.dart';

/// The input a size set is designed for.
///
/// The tier latches by platform (desktop OS → [pointer], phone/tablet →
/// [touch]) unless a `CoilAdaptiveScope` or the theme pins it. It only picks
/// sizes: whether something hovers or presses is decided by the kind of each
/// pointer event, so a mouse on an iPad still hovers.
enum CoilTier {
  /// Designed for a mouse, trackpad and keyboard: 36 px controls.
  pointer,

  /// Touch screens. Raises every hit target to 44 px while keeping the
  /// proportions of the desktop look.
  touch;

  /// The tier conventionally used on [platform].
  static CoilTier forPlatform(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS ||
    TargetPlatform.android ||
    TargetPlatform.fuchsia => CoilTier.touch,
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => CoilTier.pointer,
  };
}

/// The two steps of the size ladder shared by every control.
enum CoilSize {
  /// The default step.
  regular,

  /// One step down for dense surfaces: filter bars, toolbars, sidebars.
  compact,
}

/// Switch geometry for one size step.
@immutable
class CoilSwitchMetrics {
  /// Creates switch metrics.
  const CoilSwitchMetrics({
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
      other is CoilSwitchMetrics &&
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

/// Every size token for one tier and size step.
///
/// Pointer values start from Fluid Functionalism's `sizeMap`. Touch raises
/// the control height to 44 (regular) and every hit target to at least 44,
/// with type and glyphs a step larger so the proportions read the same.
/// Heights are minimums: controls grow with the text scale.
@immutable
class CoilMetrics {
  /// Creates metrics. Prefer a copy of a default (`CoilMetrics.touch`).
  const CoilMetrics({
    required this.tier,
    required this.size,
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
    required this.popupInset,
    this.triggerMinWidth = 160,
  });

  /// Pointer, regular: 36 px controls.
  static const pointer = CoilMetrics(
    tier: CoilTier.pointer,
    size: CoilSize.regular,
    controlHeight: 36,
    minHitTarget: 0,
    controlPaddingX: 12,
    itemPaddingX: 8,
    gap: 8,
    iconSize: 16,
    body: CoilTypeStep(13, 20),
    field: CoilTypeStep(13, 20),
    caption: CoilTypeStep(12, 16),
    buttonPaddingX: 16,
    buttonIconPaddingX: 12,
    buttonGap: 6,
    switchMetrics: CoilSwitchMetrics(
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
    popupInset: 4,
  );

  /// Pointer, compact: 28 px controls.
  static const pointerCompact = CoilMetrics(
    tier: CoilTier.pointer,
    size: CoilSize.compact,
    controlHeight: 28,
    minHitTarget: 0,
    controlPaddingX: 10,
    itemPaddingX: 6,
    gap: 4,
    iconSize: 14,
    body: CoilTypeStep(12, 18),
    field: CoilTypeStep(12, 18),
    caption: CoilTypeStep(11, 14),
    buttonPaddingX: 12,
    buttonIconPaddingX: 8,
    buttonGap: 4,
    switchMetrics: CoilSwitchMetrics(
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
    popupInset: 4,
  );

  /// Touch, regular: 44 px controls.
  ///
  /// Body and field text go to 16/22: the pointer tier's text-to-height
  /// ratio (13 in 36) at 44, and 16 keeps iOS from zooming into a focused
  /// field. Control padding (16) equals popup inset + row padding (6 + 10),
  /// so a popover's row text lines up with its trigger's. See
  /// research/08-touch-tier.md.
  static const touch = CoilMetrics(
    tier: CoilTier.touch,
    size: CoilSize.regular,
    controlHeight: 44,
    minHitTarget: 44,
    controlPaddingX: 16,
    itemPaddingX: 10,
    gap: 12,
    iconSize: 20,
    body: CoilTypeStep(16, 22),
    field: CoilTypeStep(16, 22),
    caption: CoilTypeStep(13, 18),
    buttonPaddingX: 20,
    buttonIconPaddingX: 16,
    buttonGap: 8,
    switchMetrics: CoilSwitchMetrics(
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
    popupInset: 6,
  );

  /// Touch, compact: the desktop regular look (36 px) inside a 44 px hit
  /// target.
  static const touchCompact = CoilMetrics(
    tier: CoilTier.touch,
    size: CoilSize.compact,
    controlHeight: 36,
    minHitTarget: 44,
    controlPaddingX: 12,
    itemPaddingX: 6,
    gap: 8,
    iconSize: 16,
    body: CoilTypeStep(14, 20),
    field: CoilTypeStep(16, 20),
    caption: CoilTypeStep(12, 16),
    buttonPaddingX: 16,
    buttonIconPaddingX: 12,
    buttonGap: 6,
    switchMetrics: CoilSwitchMetrics(
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
    popupInset: 6,
  );

  /// coil's default metrics for [tier] and [size]. Components read the
  /// theme's instead (`CoilTheme.metricsOf`), which an app can change.
  static CoilMetrics resolve(CoilTier tier, CoilSize size) =>
      switch ((tier, size)) {
        (CoilTier.pointer, CoilSize.regular) => pointer,
        (CoilTier.pointer, CoilSize.compact) => pointerCompact,
        (CoilTier.touch, CoilSize.regular) => touch,
        (CoilTier.touch, CoilSize.compact) => touchCompact,
      };

  /// The opacity of a disabled control.
  double get disabledOpacity => 0.5;

  /// The opacity of a disabled row in a list or group: a little fainter on
  /// touch, where rows rest at full strength.
  double get disabledRowOpacity => tier == CoilTier.touch ? 0.4 : 0.5;

  /// The tier these sizes are for.
  final CoilTier tier;

  /// The size step these metrics are for.
  final CoilSize size;

  /// Bounded control height: buttons, inputs, tabs, and list rows.
  final double controlHeight;

  /// The vertical padding that puts a [text] line box in a [controlHeight]
  /// control: `(controlHeight − lineHeight) / 2`, e.g. 8 + 20 + 8 = 36. The
  /// control uses [controlHeight] as a minimum, so it grows with the text
  /// scale instead of clipping or shifting the label.
  double controlPaddingY(CoilTypeStep text) =>
      (controlHeight - text.lineHeight) / 2;

  /// The smallest a tappable area may be. Controls whose visual is smaller
  /// (a checkbox, a compact button on touch) pad their hit area out to this.
  /// 0 on the pointer tier.
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
  final CoilTypeStep body;

  /// Text inside editable fields.
  final CoilTypeStep field;

  /// Caption text.
  final CoilTypeStep caption;

  /// Button horizontal padding next to a label.
  final double buttonPaddingX;

  /// Button horizontal padding next to an icon (4 px closer to the edge).
  final double buttonIconPaddingX;

  /// Gap between a button's icon and label.
  final double buttonGap;

  /// Switch geometry.
  final CoilSwitchMetrics switchMetrics;

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

  /// Padding of a popup (popover or sheet list) around its rows. A popup's
  /// radius is the item radius plus this, so the corners stay concentric.
  final double popupInset;

  /// The narrowest a select trigger gets.
  final double triggerMinWidth;

  /// A copy with the given values replaced.
  CoilMetrics copyWith({
    CoilTier? tier,
    CoilSize? size,
    double? controlHeight,
    double? minHitTarget,
    double? controlPaddingX,
    double? itemPaddingX,
    double? gap,
    double? iconSize,
    CoilTypeStep? body,
    CoilTypeStep? field,
    CoilTypeStep? caption,
    double? buttonPaddingX,
    double? buttonIconPaddingX,
    double? buttonGap,
    CoilSwitchMetrics? switchMetrics,
    double? switchRowPaddingY,
    double? checkboxSize,
    double? checkboxRadius,
    double? checkboxGlyphSize,
    double? segmentPadding,
    double? popupInset,
    double? triggerMinWidth,
  }) => CoilMetrics(
    tier: tier ?? this.tier,
    size: size ?? this.size,
    controlHeight: controlHeight ?? this.controlHeight,
    minHitTarget: minHitTarget ?? this.minHitTarget,
    controlPaddingX: controlPaddingX ?? this.controlPaddingX,
    itemPaddingX: itemPaddingX ?? this.itemPaddingX,
    gap: gap ?? this.gap,
    iconSize: iconSize ?? this.iconSize,
    body: body ?? this.body,
    field: field ?? this.field,
    caption: caption ?? this.caption,
    buttonPaddingX: buttonPaddingX ?? this.buttonPaddingX,
    buttonIconPaddingX: buttonIconPaddingX ?? this.buttonIconPaddingX,
    buttonGap: buttonGap ?? this.buttonGap,
    switchMetrics: switchMetrics ?? this.switchMetrics,
    switchRowPaddingY: switchRowPaddingY ?? this.switchRowPaddingY,
    checkboxSize: checkboxSize ?? this.checkboxSize,
    checkboxRadius: checkboxRadius ?? this.checkboxRadius,
    checkboxGlyphSize: checkboxGlyphSize ?? this.checkboxGlyphSize,
    segmentPadding: segmentPadding ?? this.segmentPadding,
    popupInset: popupInset ?? this.popupInset,
    triggerMinWidth: triggerMinWidth ?? this.triggerMinWidth,
  );

  List<Object> get _props => [
    tier,
    size,
    controlHeight,
    minHitTarget,
    controlPaddingX,
    itemPaddingX,
    gap,
    iconSize,
    body,
    field,
    caption,
    buttonPaddingX,
    buttonIconPaddingX,
    buttonGap,
    switchMetrics,
    switchRowPaddingY,
    checkboxSize,
    checkboxRadius,
    checkboxGlyphSize,
    segmentPadding,
    popupInset,
    triggerMinWidth,
  ];

  @override
  bool operator ==(Object other) =>
      other is CoilMetrics && listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

/// The four metric sets coil resolves from, one per tier and size step:
/// a theme field, so apps can change sizes at runtime.
///
/// ```dart
/// CoilThemeData(
///   metrics: const CoilMetricsTable().copyWith(
///     touch: CoilMetrics.touch.copyWith(controlHeight: 48),
///   ),
/// )
/// ```
@immutable
class CoilMetricsTable {
  /// Creates a table; unset entries keep coil's defaults.
  const CoilMetricsTable({
    this.pointer = CoilMetrics.pointer,
    this.pointerCompact = CoilMetrics.pointerCompact,
    this.touch = CoilMetrics.touch,
    this.touchCompact = CoilMetrics.touchCompact,
  });

  /// Pointer tier, regular size.
  final CoilMetrics pointer;

  /// Pointer tier, compact size.
  final CoilMetrics pointerCompact;

  /// Touch tier, regular size.
  final CoilMetrics touch;

  /// Touch tier, compact size.
  final CoilMetrics touchCompact;

  /// The metrics for [tier] and [size].
  CoilMetrics resolve(CoilTier tier, CoilSize size) => switch ((tier, size)) {
    (CoilTier.pointer, CoilSize.regular) => pointer,
    (CoilTier.pointer, CoilSize.compact) => pointerCompact,
    (CoilTier.touch, CoilSize.regular) => touch,
    (CoilTier.touch, CoilSize.compact) => touchCompact,
  };

  /// A copy with the given entries replaced.
  CoilMetricsTable copyWith({
    CoilMetrics? pointer,
    CoilMetrics? pointerCompact,
    CoilMetrics? touch,
    CoilMetrics? touchCompact,
  }) => CoilMetricsTable(
    pointer: pointer ?? this.pointer,
    pointerCompact: pointerCompact ?? this.pointerCompact,
    touch: touch ?? this.touch,
    touchCompact: touchCompact ?? this.touchCompact,
  );

  @override
  bool operator ==(Object other) =>
      other is CoilMetricsTable &&
      other.pointer == pointer &&
      other.pointerCompact == pointerCompact &&
      other.touch == touch &&
      other.touchCompact == touchCompact;

  @override
  int get hashCode => Object.hash(pointer, pointerCompact, touch, touchCompact);
}
