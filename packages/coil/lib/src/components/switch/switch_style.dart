import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilSwitch` looks; unset fields come from
/// [CoilSwitchStyle.fallback].
///
/// [track] is resolved for the four ends the switch blends between:
/// off, off + [WidgetState.hovered], on ([WidgetState.selected]) and
/// on + hovered. [label] is resolved with [WidgetState.selected].
class CoilSwitchStyle extends CoilComponentStyle<CoilSwitchStyle> {
  /// Creates a switch style.
  const CoilSwitchStyle({
    this.track,
    this.thumb,
    this.label,
    this.textStyle,
    this.radius,
  });

  /// The defaults from [theme]'s tokens at [metrics].
  factory CoilSwitchStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    final m = metrics.switchMetrics;
    return CoilSwitchStyle(
      track: WidgetStateProperty<Color?>.fromMap({
        WidgetState.selected & WidgetState.hovered: CoilColorMix.oklab(
          c.brand,
          const Color(0xFF000000),
          0.92,
        ),
        WidgetState.selected: c.brand,
        WidgetState.hovered: CoilColorMix.oklab(c.accent, c.overlay, 0.9),
        WidgetState.any: c.accent,
      }),
      thumb: const Color(0xFFFFFFFF),
      label: WidgetStateProperty<Color?>.fromMap({
        WidgetState.selected: c.foreground,
        WidgetState.any: c.mutedForeground,
      }),
      textStyle: theme.typography.style(metrics.body),
      // A pill: half the track's height.
      radius: theme.shape == CoilShape.sharp ? 0 : m.trackHeight / 2,
    );
  }

  /// The track color.
  final WidgetStateProperty<Color?>? track;

  /// The thumb color.
  final Color? thumb;

  /// The label color.
  final WidgetStateProperty<Color?>? label;

  /// The label style (its color comes from [label]).
  final TextStyle? textStyle;

  /// The track's corner radius. The thumb is always a pill.
  final double? radius;

  @override
  CoilSwitchStyle merge(CoilSwitchStyle? other) => other == null
      ? this
      : CoilSwitchStyle(
          track: other.track ?? track,
          thumb: other.thumb ?? thumb,
          label: other.label ?? label,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
        );

  @override
  List<Object?> get props => [track, thumb, label, textStyle, radius];
}
