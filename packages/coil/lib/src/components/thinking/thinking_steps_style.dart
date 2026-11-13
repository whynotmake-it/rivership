import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilThinkingSteps` looks. Unset fields come from
/// [CoilThinkingStepsStyle.fallback], which derives them from the theme.
/// Set a style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [triggerFill], [label] and [expandedLabel] are resolved with
/// [WidgetState.hovered], [WidgetState.focused], [WidgetState.pressed] and
/// [WidgetState.disabled].
class CoilThinkingStepsStyle
    extends CoilComponentStyle<CoilThinkingStepsStyle> {
  /// Creates a style.
  const CoilThinkingStepsStyle({
    this.triggerFill,
    this.label,
    this.expandedLabel,
    this.textStyle,
    this.titleStyle,
    this.detailStyle,
    this.glyphColor,
    this.sourceFill,
    this.sourceBorder,
    this.sourceTextStyle,
    this.radius,
    this.maxWidth,
    this.panelPadding,
    this.stepPadding,
    this.detailGap,
    this.sectionGap,
    this.sourceGap,
    this.sourceMinHeight,
    this.sourcePadding,
    this.imageMaxWidth,
    this.dotSize,
    this.focusRingOffset,
  });

  /// The defaults from the theme's tokens. Pointer triggers rest at
  /// `mutedForeground`; touch triggers and [highContrast] ones rest at
  /// `foreground`.
  factory CoilThinkingStepsStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics, {
    bool highContrast = false,
  }) {
    final c = theme.colors;
    final type = theme.typography;
    final rest = metrics.tier == CoilTier.touch || highContrast
        ? c.foreground
        : c.mutedForeground;
    // Badges don't grow on touch (DESIGN.md §14.1 Badge).
    final badge = CoilMetrics.resolve(CoilTier.pointer, metrics.size);
    final padX = metrics.controlPaddingX;
    return CoilThinkingStepsStyle(
      // A mouse press keeps the hover look; a touch press fills.
      triggerFill: WidgetStateProperty.fromMap({
        WidgetState.hovered: c.hover,
        WidgetState.pressed: c.active,
        WidgetState.any: c.hover.withValues(alpha: 0),
      }),
      label: WidgetStateProperty.fromMap({
        WidgetState.hovered | WidgetState.focused: c.foreground,
        WidgetState.any: rest,
      }),
      expandedLabel: WidgetStatePropertyAll(c.foreground),
      textStyle: type.style(metrics.body),
      titleStyle: type.style(metrics.body, color: c.foreground),
      detailStyle: type.style(metrics.caption, color: c.mutedForeground),
      glyphColor: c.mutedForeground,
      // High contrast pushes `accent` toward the text color, so badges
      // switch to a quiet fill with a visible outline there.
      sourceFill: highContrast ? c.muted : c.accent,
      sourceBorder: highContrast ? c.border : null,
      sourceTextStyle: type.style(badge.caption, color: c.foreground),
      radius: theme.shape.radii(metrics.tier).item,
      maxWidth: 320,
      panelPadding: EdgeInsetsDirectional.fromSTEB(padX, 0, padX, 12),
      stepPadding: const EdgeInsets.symmetric(vertical: 6),
      detailGap: 2,
      sectionGap: 6,
      sourceGap: 6,
      sourceMinHeight: 24,
      sourcePadding: const EdgeInsets.symmetric(horizontal: 10),
      imageMaxWidth: 200,
      dotSize: 6,
      focusRingOffset: 2,
    );
  }

  /// The trigger's fill: hover on pointer, press on touch.
  final WidgetStateProperty<Color?>? triggerFill;

  /// The trigger's label and chevron color while collapsed.
  final WidgetStateProperty<Color?>? label;

  /// The trigger's label and chevron color while expanded.
  final WidgetStateProperty<Color?>? expandedLabel;

  /// The trigger label's style. Its color comes from [label].
  final TextStyle? textStyle;

  /// A step's title.
  final TextStyle? titleStyle;

  /// A step's detail line.
  final TextStyle? detailStyle;

  /// A step's leading glyph or dot.
  final Color? glyphColor;

  /// The fill of a source badge.
  final Color? sourceFill;

  /// The outline of a source badge, if any.
  final Color? sourceBorder;

  /// The text of a source badge.
  final TextStyle? sourceTextStyle;

  /// The corner radius of the trigger fill, source badges and images.
  final double? radius;

  /// The widest the component grows. A narrower parent still wins.
  final double? maxWidth;

  /// The space around the list of steps.
  final EdgeInsetsGeometry? panelPadding;

  /// The space around each step.
  final EdgeInsetsGeometry? stepPadding;

  /// The space between a step's title and its detail.
  final double? detailGap;

  /// The space above a step's sources and its image.
  final double? sectionGap;

  /// The space between source badges, across and down.
  final double? sourceGap;

  /// The smallest height of a source badge.
  final double? sourceMinHeight;

  /// The space beside a source badge's text.
  final EdgeInsetsGeometry? sourcePadding;

  /// The widest a step's image grows.
  final double? imageMaxWidth;

  /// The size of the dot shown for a step with no leading glyph.
  final double? dotSize;

  /// How far outside the trigger its focus ring sits.
  final double? focusRingOffset;

  @override
  CoilThinkingStepsStyle merge(CoilThinkingStepsStyle? other) => other == null
      ? this
      : CoilThinkingStepsStyle(
          triggerFill: other.triggerFill ?? triggerFill,
          label: other.label ?? label,
          expandedLabel: other.expandedLabel ?? expandedLabel,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          detailStyle:
              detailStyle?.merge(other.detailStyle) ?? other.detailStyle,
          glyphColor: other.glyphColor ?? glyphColor,
          sourceFill: other.sourceFill ?? sourceFill,
          sourceBorder: other.sourceBorder ?? sourceBorder,
          sourceTextStyle:
              sourceTextStyle?.merge(other.sourceTextStyle) ??
              other.sourceTextStyle,
          radius: other.radius ?? radius,
          maxWidth: other.maxWidth ?? maxWidth,
          panelPadding: other.panelPadding ?? panelPadding,
          stepPadding: other.stepPadding ?? stepPadding,
          detailGap: other.detailGap ?? detailGap,
          sectionGap: other.sectionGap ?? sectionGap,
          sourceGap: other.sourceGap ?? sourceGap,
          sourceMinHeight: other.sourceMinHeight ?? sourceMinHeight,
          sourcePadding: other.sourcePadding ?? sourcePadding,
          imageMaxWidth: other.imageMaxWidth ?? imageMaxWidth,
          dotSize: other.dotSize ?? dotSize,
          focusRingOffset: other.focusRingOffset ?? focusRingOffset,
        );

  @override
  List<Object?> get props => [
    triggerFill,
    label,
    expandedLabel,
    textStyle,
    titleStyle,
    detailStyle,
    glyphColor,
    sourceFill,
    sourceBorder,
    sourceTextStyle,
    radius,
    maxWidth,
    panelPadding,
    stepPadding,
    detailGap,
    sectionGap,
    sourceGap,
    sourceMinHeight,
    sourcePadding,
    imageMaxWidth,
    dotSize,
    focusRingOffset,
  ];
}
