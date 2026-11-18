import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/src/components/input/input.dart' show CoilInputTrack;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Overrides for how a `CoilInput` looks, single-line or multi-line. Unset
/// fields come from [CoilInputStyle.fallback]. Set a style app-wide or for a
/// subtree with `CoilThemeData.withComponentStyle`, or per instance with
/// `style:`.
///
/// [fill] and [border] resolve [WidgetState.hovered], [WidgetState.focused]
/// and [WidgetState.error].
class CoilInputStyle extends CoilComponentStyle<CoilInputStyle> {
  /// Creates a style.
  const CoilInputStyle({
    this.fill,
    this.border,
    this.textStyle,
    this.placeholder,
    this.cursorColor,
    this.cursorWidth,
    this.selectionColor,
    this.radius,
    this.multilineRadius,
    this.minHeight,
    this.slotInset,
    this.motions,
    this.plasticity,
  });

  /// The defaults from the theme's tokens.
  factory CoilInputStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    final radii = theme.shape.radii(metrics.tier);
    return CoilInputStyle(
      plasticity: theme.plasticity,
      fill: WidgetStateProperty<Color?>.fromMap({
        WidgetState.focused: c.hover.withValues(alpha: 0),
        WidgetState.hovered: c.hover,
        WidgetState.any: c.hover.withValues(alpha: 0),
      }),
      border: WidgetStateProperty<Color?>.fromMap({
        WidgetState.focused: c.foreground.withValues(alpha: 0.4),
        WidgetState.error: c.destructive.withValues(alpha: 0.5),
        WidgetState.any: c.border,
      }),
      textStyle: theme.typography
          .resolve(metrics.tier, metrics.size)
          .field
          .copyWith(color: c.foreground),
      placeholder: c.mutedForeground,
      cursorColor: c.foreground,
      cursorWidth: 1,
      selectionColor: c.brand.withValues(alpha: 0.3),
      radius: radii.item,
      // A tall box at a pill radius would be a capsule.
      multilineRadius: math.min(
        radii.item,
        CoilShape.rounded.radii(metrics.tier).container,
      ),
      minHeight: metrics.controlHeight,
      // A compact button in a regular field: 28 in 36, 36 in 44.
      slotInset: metrics.size == CoilSize.compact ? 2 : 4,
    );
  }

  /// The field's background.
  final WidgetStateProperty<Color?>? fill;

  /// The field's hairline.
  final WidgetStateProperty<Color?>? border;

  /// The text style.
  final TextStyle? textStyle;

  /// The placeholder and slot color.
  final Color? placeholder;

  /// The caret color.
  final Color? cursorColor;

  /// The caret width.
  final double? cursorWidth;

  /// The text selection highlight.
  final Color? selectionColor;

  /// The corner radius of a single-line field.
  final double? radius;

  /// The corner radius of a multi-line field.
  final double? multilineRadius;

  /// The minimum height. The field grows with its text.
  final double? minHeight;

  /// The least space between a slot placed into the padding (a button) and
  /// the field's edge. The field grows when the slot and this inset on each
  /// side don't fit [minHeight].
  final double? slotInset;

  /// Springs for the field's animated parts, keyed by [CoilInputTrack]s:
  /// `{CoilInputTrack.border: const Motion.smoothSpring()}`. A field's own
  /// `motions:` win over these; these win over the motion tokens. [merge]
  /// combines the maps key by key.
  final Map<CoilInputTrack<Object>, Motion>? motions;

  /// How lit this component is. Defaults to the theme's
  /// `CoilThemeData.plasticity`; set it here to light (or flatten) one
  /// component type or instance.
  final CoilPlasticity? plasticity;

  @override
  CoilInputStyle merge(CoilInputStyle? other) => other == null
      ? this
      : CoilInputStyle(
          plasticity: other.plasticity ?? plasticity,
          fill: CoilComponentStyle.mergeStates(fill, other.fill),
          border: CoilComponentStyle.mergeStates(border, other.border),
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          placeholder: other.placeholder ?? placeholder,
          cursorColor: other.cursorColor ?? cursorColor,
          cursorWidth: other.cursorWidth ?? cursorWidth,
          selectionColor: other.selectionColor ?? selectionColor,
          radius: other.radius ?? radius,
          multilineRadius: other.multilineRadius ?? multilineRadius,
          minHeight: other.minHeight ?? minHeight,
          slotInset: other.slotInset ?? slotInset,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [
    fill,
    border,
    textStyle,
    placeholder,
    cursorColor,
    cursorWidth,
    selectionColor,
    radius,
    multilineRadius,
    minHeight,
    slotInset,
    motions,
    plasticity,
  ];
}
