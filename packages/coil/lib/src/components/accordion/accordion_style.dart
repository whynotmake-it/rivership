import 'package:coil/foundation.dart';
import 'package:coil/src/components/accordion/accordion_item.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Overrides for how a `CoilAccordion` looks. Unset fields come from
/// [CoilAccordionStyle.fallback], which derives them from the theme. Set a
/// style app-wide or for a subtree with `CoilThemeData.withComponentStyle`,
/// or per instance with `style:`.
///
/// [triggerFill], [label] and [expandedLabel] are resolved with
/// [WidgetState.hovered], [WidgetState.focused], [WidgetState.pressed] and
/// [WidgetState.disabled].
class CoilAccordionStyle extends CoilComponentStyle<CoilAccordionStyle> {
  /// Creates a style.
  const CoilAccordionStyle({
    this.triggerFill,
    this.highlight,
    this.openTint,
    this.label,
    this.expandedLabel,
    this.textStyle,
    this.panelTextStyle,
    this.panelPadding,
    this.radius,
    this.groupWidth,
    this.focusRingOffset,
    this.motions,
  });

  /// The defaults from the theme's tokens. Pointer triggers rest at
  /// `mutedForeground`; touch triggers and [highContrast] ones rest at
  /// `foreground`. In the [CoilAccordionVariant.group] variant the shared
  /// highlight shows hover, so the trigger fills only for a touch press.
  factory CoilAccordionStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics, {
    bool highContrast = false,
    CoilAccordionVariant variant = CoilAccordionVariant.plain,
  }) {
    final c = theme.colors;
    final clear = c.hover.withValues(alpha: 0);
    final rest = metrics.tier == CoilTier.touch || highContrast
        ? c.foreground
        : c.mutedForeground;
    final padX = metrics.controlPaddingX;
    final text = theme.typography.resolve(metrics.tier, metrics.size);
    return CoilAccordionStyle(
      // A mouse press keeps the hover look; a touch press fills.
      triggerFill: WidgetStateProperty.fromMap({
        WidgetState.hovered: switch (variant) {
          CoilAccordionVariant.plain => c.hover,
          CoilAccordionVariant.group => clear,
        },
        WidgetState.pressed: c.active,
        WidgetState.any: clear,
      }),
      highlight: c.hover,
      openTint: c.hover,
      label: WidgetStateProperty.fromMap({
        WidgetState.hovered | WidgetState.focused: c.foreground,
        WidgetState.any: rest,
      }),
      expandedLabel: WidgetStatePropertyAll(c.foreground),
      textStyle: text.body,
      panelTextStyle: text.body.copyWith(color: c.mutedForeground),
      panelPadding: EdgeInsetsDirectional.fromSTEB(padX, 0, padX, 12),
      radius: theme.shape.radii(metrics.tier).item,
      groupWidth: 288,
      focusRingOffset: theme.focusRing.offset,
    );
  }

  /// The trigger's own fill: the hover fill of the plain variant, and the
  /// press fill on touch.
  final WidgetStateProperty<Color?>? triggerFill;

  /// The gliding hover highlight of the group variant.
  final Color? highlight;

  /// The tint behind open items in the group variant.
  final Color? openTint;

  /// The label, glyph and chevron color of a closed item.
  final WidgetStateProperty<Color?>? label;

  /// The label, glyph and chevron color of an open item.
  final WidgetStateProperty<Color?>? expandedLabel;

  /// The trigger label's style. Its color comes from [label].
  final TextStyle? textStyle;

  /// The default text style of a panel.
  final TextStyle? panelTextStyle;

  /// The space around a panel's content.
  final EdgeInsetsGeometry? panelPadding;

  /// The corner radius of fills, tints and the highlight.
  final double? radius;

  /// The widest the group variant grows. A narrower parent still wins.
  final double? groupWidth;

  /// How far outside a trigger its focus ring sits.
  final double? focusRingOffset;

  /// Springs for the accordion's animated parts, keyed by
  /// [CoilAccordionTrack]s: `{CoilAccordionTrack.height: const
  /// Motion.bouncySpring()}`. An accordion's own `motions:` win over these;
  /// these win over the motion tokens. [merge] combines the maps key by key.
  final Map<CoilAccordionTrack<Object>, Motion>? motions;

  @override
  CoilAccordionStyle merge(CoilAccordionStyle? other) => other == null
      ? this
      : CoilAccordionStyle(
          triggerFill: CoilComponentStyle.mergeStates(
            triggerFill,
            other.triggerFill,
          ),
          highlight: other.highlight ?? highlight,
          openTint: other.openTint ?? openTint,
          label: CoilComponentStyle.mergeStates(label, other.label),
          expandedLabel: CoilComponentStyle.mergeStates(
            expandedLabel,
            other.expandedLabel,
          ),
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          panelTextStyle:
              panelTextStyle?.merge(other.panelTextStyle) ??
              other.panelTextStyle,
          panelPadding: other.panelPadding ?? panelPadding,
          radius: other.radius ?? radius,
          groupWidth: other.groupWidth ?? groupWidth,
          focusRingOffset: other.focusRingOffset ?? focusRingOffset,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [
    triggerFill,
    highlight,
    openTint,
    label,
    expandedLabel,
    textStyle,
    panelTextStyle,
    panelPadding,
    radius,
    groupWidth,
    focusRingOffset,
    motions,
  ];
}
