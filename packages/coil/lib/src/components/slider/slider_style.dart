import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilSlider` looks; unset fields come from
/// [CoilSliderStyle.fallback].
///
/// [handle], [label] and [value] resolve [WidgetState.hovered],
/// [WidgetState.focused] and [WidgetState.pressed].
class CoilSliderStyle extends CoilComponentStyle<CoilSliderStyle> {
  /// Creates a slider style.
  const CoilSliderStyle({
    this.fill,
    this.pillFill,
    this.border,
    this.handle,
    this.pip,
    this.activePip,
    this.label,
    this.value,
    this.preview,
    this.knob,
    this.knobShadows,
    this.bubble,
    this.bubbleText,
    this.textStyle,
    this.bubbleTextStyle,
    this.radius,
    this.knobSize,
    this.knobBox,
    this.pillHeight,
    this.pipSize,
    this.pipGrowth,
    this.dotSize,
    this.dotGrowth,
    this.handleWidth,
    this.handleInset,
    this.bubbleGap,
    this.bubblePadding,
  });

  /// The defaults from [theme]'s tokens at [metrics].
  factory CoilSliderStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    final touch = metrics.tier == CoilTier.touch;
    return CoilSliderStyle(
      fill: c.active,
      pillFill: theme.brightness == Brightness.dark
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
      pip: c.mutedForeground.withValues(alpha: 0.3),
      activePip: c.foreground,
      label: WidgetStateProperty.resolveWith(
        (s) => s.isEmpty ? c.mutedForeground : c.foreground,
      ),
      value: WidgetStateProperty.resolveWith(
        (s) => s.isEmpty ? c.mutedForeground : c.foreground,
      ),
      preview: c.accent.withValues(alpha: 0.4),
      knob: const Color(0xFFFFFFFF),
      knobShadows: const [
        BoxShadow(
          color: Color(0x1A000000),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
        BoxShadow(
          color: Color(0x1A000000),
          offset: Offset(0, 1),
          blurRadius: 2,
          spreadRadius: -1,
        ),
      ],
      bubble: c.foreground,
      bubbleText: c.background,
      textStyle: theme.typography.style(metrics.body),
      bubbleTextStyle: theme.typography.style(metrics.caption),
      radius: theme.shape.radii(metrics.tier).item,
      knobSize: touch ? 22 : 16,
      knobBox: touch ? 44 : 20,
      pillHeight: 18,
      pipSize: 5,
      pipGrowth: 0.4,
      dotSize: 4,
      dotGrowth: 0.25,
      handleWidth: 2,
      handleInset: 8,
      bubbleGap: 8,
      bubblePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  /// The row's fill, up to the value.
  final Color? fill;

  /// The pill track's fill.
  final Color? pillFill;

  /// The 1 px outline of the row and the pill.
  final Color? border;

  /// The handle line of the row.
  final WidgetStateProperty<Color?>? handle;

  /// A pip dot.
  final Color? pip;

  /// The pip dot at the value.
  final Color? activePip;

  /// The label color.
  final WidgetStateProperty<Color?>? label;

  /// The value color.
  final WidgetStateProperty<Color?>? value;

  /// The hover preview bar.
  final Color? preview;

  /// The pill's knob.
  final Color? knob;

  /// The pill knob's shadows.
  final List<BoxShadow>? knobShadows;

  /// The value bubble's fill.
  final Color? bubble;

  /// The value bubble's text color.
  final Color? bubbleText;

  /// The label and value text style (color from [label] and [value]).
  final TextStyle? textStyle;

  /// The value bubble's text style.
  final TextStyle? bubbleTextStyle;

  /// The row's and bubble's corner radius.
  final double? radius;

  /// The pill knob's visual diameter.
  final double? knobSize;

  /// The pill knob's box; its hit area is this tall.
  final double? knobBox;

  /// The pill track's height.
  final double? pillHeight;

  /// A pip's diameter.
  final double? pipSize;

  /// How much larger the pip at the value is, as a fraction of [pipSize].
  final double? pipGrowth;

  /// The diameter of a step dot on the pill, colored [pip].
  final double? dotSize;

  /// How much larger the pill's dots grow while hovered, as a fraction of
  /// [dotSize].
  final double? dotGrowth;

  /// The handle line's width.
  final double? handleWidth;

  /// How far the handle line stops short of the row's top and bottom.
  final double? handleInset;

  /// The gap between the value bubble and the track.
  final double? bubbleGap;

  /// The padding inside the value bubble.
  final EdgeInsets? bubblePadding;

  @override
  CoilSliderStyle merge(CoilSliderStyle? other) => other == null
      ? this
      : CoilSliderStyle(
          fill: other.fill ?? fill,
          pillFill: other.pillFill ?? pillFill,
          border: other.border ?? border,
          handle: other.handle ?? handle,
          pip: other.pip ?? pip,
          activePip: other.activePip ?? activePip,
          label: other.label ?? label,
          value: other.value ?? value,
          preview: other.preview ?? preview,
          knob: other.knob ?? knob,
          knobShadows: other.knobShadows ?? knobShadows,
          bubble: other.bubble ?? bubble,
          bubbleText: other.bubbleText ?? bubbleText,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          bubbleTextStyle:
              bubbleTextStyle?.merge(other.bubbleTextStyle) ??
              other.bubbleTextStyle,
          radius: other.radius ?? radius,
          knobSize: other.knobSize ?? knobSize,
          knobBox: other.knobBox ?? knobBox,
          pillHeight: other.pillHeight ?? pillHeight,
          pipSize: other.pipSize ?? pipSize,
          pipGrowth: other.pipGrowth ?? pipGrowth,
          dotSize: other.dotSize ?? dotSize,
          dotGrowth: other.dotGrowth ?? dotGrowth,
          handleWidth: other.handleWidth ?? handleWidth,
          handleInset: other.handleInset ?? handleInset,
          bubbleGap: other.bubbleGap ?? bubbleGap,
          bubblePadding: other.bubblePadding ?? bubblePadding,
        );

  @override
  List<Object?> get props => [
    fill,
    pillFill,
    border,
    handle,
    pip,
    activePip,
    label,
    value,
    preview,
    knob,
    knobShadows,
    bubble,
    bubbleText,
    textStyle,
    bubbleTextStyle,
    radius,
    knobSize,
    knobBox,
    pillHeight,
    pipSize,
    pipGrowth,
    dotSize,
    dotGrowth,
    handleWidth,
    handleInset,
    bubbleGap,
    bubblePadding,
  ];
}
