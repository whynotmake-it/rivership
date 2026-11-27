/// @docImport 'package:coil/thinking.dart';
library;

import 'package:coil/foundation.dart';
import 'package:coil/src/components/thinking/thinking_steps.dart'
    show CoilThinkingStepsTrack;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Overrides for how a [CoilThinkingSteps] looks.
///
/// Unset fields come from [CoilThinkingStepsStyle.fallback], which derives them
/// from the theme. Set a style app-wide or for a subtree with
/// [CoilThemeData.withComponentStyle], or per instance with `style:`.
///
/// [triggerFill], [label] and [expandedLabel] are resolved with
/// [WidgetState.hovered], [WidgetState.focused], [WidgetState.pressed] and
/// [WidgetState.disabled].
class CoilThinkingStepsStyle
    extends CoilComponentStyle<CoilThinkingStepsStyle> {
  /// Creates a style.
  const CoilThinkingStepsStyle({
    this.triggerFill,
    this.triggerPadding,
    this.label,
    this.expandedLabel,
    this.textStyle,
    this.titleStyle,
    this.detailStyle,
    this.glyphColor,
    this.connectorColor,
    this.connectorWidth,
    this.connectorGap,
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
    this.motions,
  });

  /// The defaults from the theme's tokens.
  ///
  /// Pointer triggers rest at [CoilColors.mutedForeground]; touch triggers and
  /// [highContrast] ones rest at [CoilColors.foreground].
  factory CoilThinkingStepsStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics, {
    bool highContrast = false,
  }) {
    final c = theme.colors;
    final text = theme.typography.resolve(metrics.tier, metrics.size);
    final rest = metrics.tier == CoilTier.touch || highContrast
        ? c.foreground
        : c.mutedForeground;
    // Badges don't grow on touch (DESIGN.md §14.1 Badge).
    final badge = theme.typography.resolve(CoilTier.pointer, metrics.size);
    final padX = metrics.controlPaddingX;
    return CoilThinkingStepsStyle(
      // A mouse press keeps the hover look; a touch press fills.
      triggerFill: WidgetStateProperty.fromMap({
        WidgetState.hovered: c.hover,
        WidgetState.pressed: c.active,
        WidgetState.any: c.hover.withValues(alpha: 0),
      }),
      triggerPadding: EdgeInsets.symmetric(
        horizontal: padX,
        vertical: metrics.controlPaddingY(text.body),
      ),
      label: WidgetStateProperty.fromMap({
        WidgetState.hovered | WidgetState.focused: c.foreground,
        WidgetState.any: rest,
      }),
      expandedLabel: WidgetStatePropertyAll(c.foreground),
      textStyle: text.body,
      titleStyle: text.body.copyWith(
        color: c.foreground,
        fontWeight: text.emphasis,
      ),
      detailStyle: text.body.copyWith(color: c.mutedForeground),
      glyphColor: c.mutedForeground,
      // A hairline at 60 % of `border`, so the rail reads as structure,
      // not as a rule between steps.
      connectorColor: c.border.withValues(alpha: c.border.a * 0.6),
      connectorWidth: 1,
      connectorGap: 4,
      // High contrast pushes `accent` toward the text color, so badges
      // switch to a quiet fill with a visible outline there.
      sourceFill: highContrast ? c.muted : c.accent,
      sourceBorder: highContrast ? c.border : null,
      sourceTextStyle: badge.caption.copyWith(color: c.foreground),
      radius: theme.shape.radii(metrics.tier).item,
      maxWidth: 320,
      panelPadding: EdgeInsetsDirectional.fromSTEB(padX, 4, padX, 12),
      stepPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      detailGap: 4,
      sectionGap: 8,
      sourceGap: 6,
      sourceMinHeight: 24,
      sourcePadding: const EdgeInsets.symmetric(horizontal: 10),
      imageMaxWidth: 200,
      dotSize: 6,
      focusRingOffset: theme.focusRing.offset,
    );
  }

  /// The trigger's fill: hover on pointer, press on touch.
  final WidgetStateProperty<Color?>? triggerFill;

  /// The space around the trigger's label and chevron.
  final EdgeInsetsGeometry? triggerPadding;

  /// The trigger's label and chevron color while collapsed.
  final WidgetStateProperty<Color?>? label;

  /// The trigger's label and chevron color while expanded.
  final WidgetStateProperty<Color?>? expandedLabel;

  /// The trigger label's style.
  ///
  /// Its color comes from [label].
  final TextStyle? textStyle;

  /// A step's title.
  final TextStyle? titleStyle;

  /// A step's detail text.
  final TextStyle? detailStyle;

  /// A step's leading glyph or dot.
  final Color? glyphColor;

  /// The connector: the rail running vertically between consecutive steps'
  /// glyphs.
  final Color? connectorColor;

  /// How thick the connector is.
  final double? connectorWidth;

  /// The space between a step's glyph and the top of its connector.
  final double? connectorGap;

  /// The fill of a source badge.
  final Color? sourceFill;

  /// The outline of a source badge, if any.
  final Color? sourceBorder;

  /// The text of a source badge.
  final TextStyle? sourceTextStyle;

  /// The corner radius of the trigger fill, source badges and images.
  final double? radius;

  /// The widest the component grows.
  ///
  /// A narrower parent still wins.
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

  /// Springs for the component's animated parts, keyed by
  /// [CoilThinkingStepsTrack]s:
  /// `{CoilThinkingStepsTrack.stepHeight: const Motion.smoothSpring()}`.
  ///
  /// A component's own `motions:` win over these; these win over the motion
  /// tokens. [merge] combines the maps key by key.
  final Map<CoilThinkingStepsTrack<Object>, Motion>? motions;

  @override
  CoilThinkingStepsStyle merge(CoilThinkingStepsStyle? other) => other == null
      ? this
      : CoilThinkingStepsStyle(
          triggerFill: CoilComponentStyle.mergeStates(
            triggerFill,
            other.triggerFill,
          ),
          triggerPadding: other.triggerPadding ?? triggerPadding,
          label: CoilComponentStyle.mergeStates(label, other.label),
          expandedLabel: CoilComponentStyle.mergeStates(
            expandedLabel,
            other.expandedLabel,
          ),
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          detailStyle:
              detailStyle?.merge(other.detailStyle) ?? other.detailStyle,
          glyphColor: other.glyphColor ?? glyphColor,
          connectorColor: other.connectorColor ?? connectorColor,
          connectorWidth: other.connectorWidth ?? connectorWidth,
          connectorGap: other.connectorGap ?? connectorGap,
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
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [
    triggerFill,
    triggerPadding,
    label,
    expandedLabel,
    textStyle,
    titleStyle,
    detailStyle,
    glyphColor,
    connectorColor,
    connectorWidth,
    connectorGap,
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
    motions,
  ];
}
