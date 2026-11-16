import 'package:coil/foundation.dart';
import 'package:coil/src/components/checkbox/checkbox.dart'
    show CoilCheckboxTrack;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Overrides for how a `CoilCheckbox` looks; unset fields come from
/// [CoilCheckboxStyle.fallback].
///
/// [border] is resolved with [WidgetState.hovered], [WidgetState.selected]
/// (checked or indeterminate) and [WidgetState.error] (`invalid`).
class CoilCheckboxStyle extends CoilComponentStyle<CoilCheckboxStyle> {
  /// Creates a checkbox style.
  const CoilCheckboxStyle({
    this.border,
    this.borderWidth,
    this.glyphColor,
    this.size,
    this.radius,
    this.motions,
  });

  /// The defaults from [theme]'s tokens at [metrics].
  factory CoilCheckboxStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    return CoilCheckboxStyle(
      border: WidgetStateProperty<Color?>.fromMap({
        WidgetState.hovered: c.foreground.withValues(alpha: 0.4),
        WidgetState.selected: c.border.withValues(alpha: 0),
        WidgetState.error: c.destructive.withValues(alpha: 0.5),
        WidgetState.any: c.border,
      }),
      borderWidth: 1.5,
      glyphColor: c.foreground,
      size: metrics.checkboxSize,
      radius: theme.shape == CoilShape.sharp ? 0 : metrics.checkboxRadius,
    );
  }

  /// The box outline color.
  final WidgetStateProperty<Color?>? border;

  /// The box outline width.
  final double? borderWidth;

  /// The tick and dash color.
  final Color? glyphColor;

  /// The box size before text scaling.
  final double? size;

  /// The box's corner radius before text scaling.
  final double? radius;

  /// Springs for the checkbox's animated parts, keyed by
  /// [CoilCheckboxTrack]s: `{CoilCheckboxTrack.glyph: const
  /// Motion.bouncySpring()}`. A checkbox's own `motions:` win over these;
  /// these win over the motion tokens. [merge] combines the maps key by key.
  final Map<CoilCheckboxTrack<Object>, Motion>? motions;

  @override
  CoilCheckboxStyle merge(CoilCheckboxStyle? other) => other == null
      ? this
      : CoilCheckboxStyle(
          border: other.border ?? border,
          borderWidth: other.borderWidth ?? borderWidth,
          glyphColor: other.glyphColor ?? glyphColor,
          size: other.size ?? size,
          radius: other.radius ?? radius,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [
    border,
    borderWidth,
    glyphColor,
    size,
    radius,
    motions,
  ];
}
