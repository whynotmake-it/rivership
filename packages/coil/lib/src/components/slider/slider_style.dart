import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilSlider` looks; unset fields come from
/// [CoilSliderStyle.fallback].
///
/// The colors resolve these states:
///
/// * [handle]: [WidgetState.hovered], [WidgetState.focused],
///   [WidgetState.pressed].
/// * [label] and [value]: [WidgetState.hovered], [WidgetState.focused],
///   [WidgetState.pressed] (any of them turns the text to foreground).
/// * [pip]: [WidgetState.selected] for the pip at the value.
class CoilSliderStyle extends CoilComponentStyle<CoilSliderStyle> {
  /// Creates a slider style.
  const CoilSliderStyle({
    this.fill,
    this.compactFill,
    this.border,
    this.handle,
    this.pip,
    this.label,
    this.value,
    this.preview,
    this.knob,
    this.bubble,
    this.bubbleText,
    this.textStyle,
    this.bubbleTextStyle,
    this.radius,
    this.knobSize,
    this.knobBox,
    this.compactTrackHeight,
    this.pipSize,
  });

  /// The defaults from [theme]'s tokens at [metrics].
  factory CoilSliderStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    final touch = metrics.tier == CoilTier.touch;
    final active = WidgetStateProperty.resolveWith<bool>(
      (s) =>
          s.contains(WidgetState.hovered) ||
          s.contains(WidgetState.focused) ||
          s.contains(WidgetState.pressed),
    );
    return CoilSliderStyle(
      fill: c.active,
      compactFill: theme.brightness == Brightness.dark
          ? c.accent.withValues(alpha: 0.4)
          : c.selected.withValues(alpha: 0.5),
      border: c.border,
      handle: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused)
            ? c.foreground
            : s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed)
            ? c.foreground.withValues(alpha: 0.5)
            : c.foreground.withValues(alpha: 0.25),
      ),
      pip: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? c.foreground
            : c.mutedForeground.withValues(alpha: 0.3),
      ),
      label: WidgetStateProperty.resolveWith(
        (s) => active.resolve(s) ? c.foreground : c.mutedForeground,
      ),
      value: WidgetStateProperty.resolveWith(
        (s) => active.resolve(s) ? c.foreground : c.mutedForeground,
      ),
      preview: c.brand.withValues(alpha: 0.4),
      knob: const Color(0xFFFFFFFF),
      bubble: c.foreground,
      bubbleText: c.background,
      textStyle: theme.typography.style(metrics.body),
      bubbleTextStyle: theme.typography.style(metrics.caption),
      radius: theme.shape.radii(metrics.tier).item,
      knobSize: touch ? 22 : 16,
      knobBox: touch ? 44 : 20,
      compactTrackHeight: 18,
      pipSize: 5,
    );
  }

  /// The comfortable row's fill, up to the value.
  final Color? fill;

  /// The compact track's fill.
  final Color? compactFill;

  /// The 1 px outline of the row and the compact track.
  final Color? border;

  /// The handle line of the comfortable row.
  final WidgetStateProperty<Color?>? handle;

  /// A pip dot.
  final WidgetStateProperty<Color?>? pip;

  /// The label color.
  final WidgetStateProperty<Color?>? label;

  /// The value color.
  final WidgetStateProperty<Color?>? value;

  /// The hover preview bar.
  final Color? preview;

  /// The compact knob.
  final Color? knob;

  /// The value bubble's fill.
  final Color? bubble;

  /// The value bubble's text.
  final Color? bubbleText;

  /// The label and value text style (color from [label] and [value]).
  final TextStyle? textStyle;

  /// The value bubble's text style.
  final TextStyle? bubbleTextStyle;

  /// The row's and bubble's corner radius.
  final double? radius;

  /// The compact knob's visual diameter.
  final double? knobSize;

  /// The compact knob's box (its hit area is this tall).
  final double? knobBox;

  /// The compact track's height.
  final double? compactTrackHeight;

  /// A pip's diameter.
  final double? pipSize;

  @override
  CoilSliderStyle merge(CoilSliderStyle? other) => other == null
      ? this
      : CoilSliderStyle(
          fill: other.fill ?? fill,
          compactFill: other.compactFill ?? compactFill,
          border: other.border ?? border,
          handle: other.handle ?? handle,
          pip: other.pip ?? pip,
          label: other.label ?? label,
          value: other.value ?? value,
          preview: other.preview ?? preview,
          knob: other.knob ?? knob,
          bubble: other.bubble ?? bubble,
          bubbleText: other.bubbleText ?? bubbleText,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          bubbleTextStyle:
              bubbleTextStyle?.merge(other.bubbleTextStyle) ??
              other.bubbleTextStyle,
          radius: other.radius ?? radius,
          knobSize: other.knobSize ?? knobSize,
          knobBox: other.knobBox ?? knobBox,
          compactTrackHeight: other.compactTrackHeight ?? compactTrackHeight,
          pipSize: other.pipSize ?? pipSize,
        );

  @override
  List<Object?> get props => [
    fill,
    compactFill,
    border,
    handle,
    pip,
    label,
    value,
    preview,
    knob,
    bubble,
    bubbleText,
    textStyle,
    bubbleTextStyle,
    radius,
    knobSize,
    knobBox,
    compactTrackHeight,
    pipSize,
  ];
}
