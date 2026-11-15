import 'package:coil/foundation.dart';
import 'package:coil/src/components/slider/range_slider.dart';
import 'package:coil/src/components/slider/slider_core.dart';
import 'package:coil/src/components/slider/slider_scale.dart';
import 'package:coil/src/components/slider/slider_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilSlider] or a [CoilRangeSlider], as Motor
/// tracks. Use them as keys of their `motions` or of
/// [CoilThemeData.trackMotions].
///
/// A custom motion replaces both the enter and the exit of its part.
final class CoilSliderTrack<T extends Object> extends Track<T> {
  CoilSliderTrack._(super.converter, {required String super.debugLabel});

  /// A thumb and the fill moving to a new value. While dragging a continuous
  /// slider they follow the pointer directly; with steps they spring to each
  /// step. Both thumbs of a range use it. Default motion: `standard`.
  static final thumb = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.thumb',
  );

  /// The hover preview bar's end, springing from the nearest thumb toward
  /// the hover. The hover bubble rides it once the two meet. Default
  /// motion: `quick`.
  static final preview = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.preview',
  );

  /// The preview bar's opacity. Default motion: `fade`.
  static final previewOpacity = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.previewOpacity',
  );

  /// The value bubble's or the value tooltips' opacity. Default motion:
  /// `fade`.
  static final bubble = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.bubble',
  );

  /// A handle line's color. Default motion: `fade`.
  static final handle = CoilSliderTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilSlider.handle',
  );

  /// The pill's step dots growing while the slider is hovered. Default
  /// motion: `standard`.
  static final dots = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.dots',
  );

  /// The label and value turning foreground and semibold, and the handle
  /// growing. Default motion: `fade`.
  static final emphasis = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.emphasis',
  );
}

/// How a [CoilSlider] draws its track.
enum CoilSliderVariant {
  /// A full-width row with a continuous fill and a handle line.
  scrubber,

  /// Like [scrubber], plus a dot at every step. Needs `divisions` or
  /// `steps`.
  pips,

  /// A thin pill track with a knob, between the label and the value.
  pill,

  /// Like [pill], plus a small dot at every step, hidden under the fill.
  /// Needs `divisions` or `steps`.
  pillPips,
}

/// Where a slider shows its value.
enum CoilSliderValueDisplay {
  /// As text at the end of the row, or after the pill.
  text,

  /// As [text]; a click or tap on a value, or Enter on a focused thumb,
  /// turns it into a field. Enter or Done applies the typed number, clamped
  /// to the range and snapped to a step; Esc leaves it unchanged. Leaving
  /// the field applies it too.
  editable,

  /// In a tooltip over each thumb while the slider is hovered, pressed or
  /// focused with the keyboard. There is no value text.
  tooltip,
}

/// A slider for one value between [min] and [max].
///
/// The slider is controlled: it shows [value] and asks for changes through
/// [onChanged].
///
/// Dragging moves the value with the pointer and never coasts. A tap jumps.
/// A pointer that hovers previews the value under it. A touch shows the
/// value above the thumb.
///
/// Values snap to [divisions] equal steps, or to the values in [steps].
///
/// Arrows step by one step, or 1 % when continuous. Shift+arrow, Page Up
/// and Page Down move 10 %. Home and End go to [min] and [max]. Left and
/// right follow the reading direction.
///
/// For two values, use [CoilRangeSlider]. The animated parts are
/// [CoilSliderTrack]s; override them with [motions].
class CoilSlider extends StatelessWidget {
  /// Creates a slider.
  const CoilSlider({
    required this.value,
    required this.onChanged,
    super.key,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.steps,
    this.onChangeStart,
    this.onChangeEnd,
    this.label,
    this.valueBuilder,
    this.semanticFormatter,
    this.editFormatter,
    this.editParser,
    this.variant = CoilSliderVariant.scrubber,
    this.valueDisplay = CoilSliderValueDisplay.text,
    this.size,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.motion,
    this.motions,
    this.style,
    this.semanticLabel,
  }) : assert(min < max, 'min must be less than max'),
       assert(
         divisions == null || divisions > 0,
         'divisions must be positive',
       ),
       assert(
         divisions == null || steps == null,
         'use divisions or steps, not both',
       ),
       assert(
         (variant != CoilSliderVariant.pips &&
                 variant != CoilSliderVariant.pillPips) ||
             divisions != null ||
             steps != null,
         'pips need divisions or steps',
       );

  /// The current value, between [min] and [max].
  final double value;

  /// Called with the new value, snapped to [divisions] or [steps]. Null
  /// disables the slider.
  final ValueChanged<double>? onChanged;

  /// The smallest value.
  final double min;

  /// The largest value.
  final double max;

  /// How many equal steps [min]..[max] is split into. Null, with no
  /// [steps], is continuous.
  final int? divisions;

  /// The values the slider can take, at any spacing, between [min] and
  /// [max]; usually the first is [min] and the last is [max]. The order
  /// doesn't matter. Arrows walk the list, and pips sit at each value.
  final List<double>? steps;

  /// Called with the current value when a change starts: a drag, a tap, a
  /// key, a typed value or a screen reader action.
  final ValueChanged<double>? onChangeStart;

  /// Called with the new value when that change ends.
  final ValueChanged<double>? onChangeEnd;

  /// The text before the track. It is built once, so a [GlobalKey] on it is
  /// safe.
  final Widget? label;

  /// Builds the value for the value text and the bubbles, styled by the
  /// slider's text style. The default is a [Text] with up to two decimals
  /// and no trailing zeros, with a `.` decimal mark; it isn't localized.
  final Widget Function(BuildContext context, double value)? valueBuilder;

  /// The value as screen readers announce it. Defaults to the same plain
  /// number as [valueBuilder]'s default, so set both when the shown value
  /// isn't that number (a unit, a name).
  final String Function(double value)? semanticFormatter;

  /// The text a value field opens with, under
  /// [CoilSliderValueDisplay.editable]. Defaults to the plain number.
  final String Function(double value)? editFormatter;

  /// Reads a typed value back, under [CoilSliderValueDisplay.editable].
  /// Null means the text isn't a value, and nothing changes. Defaults to
  /// [double.tryParse].
  final double? Function(String text)? editParser;

  /// How the track looks.
  final CoilSliderVariant variant;

  /// Where the value shows, and whether it can be typed.
  final CoilSliderValueDisplay valueDisplay;

  /// Pins the slider to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Observes, and can force, hover/focus/press states.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for this
  /// instance.
  final CoilMotion? motion;

  /// Per-part motions for this instance, keyed by [CoilSliderTrack]s.
  final Map<CoilSliderTrack<Object>, Motion>? motions;

  /// Overrides for this slider's look.
  final CoilSliderStyle? style;

  /// A label for assistive technology when [label] is not plain text.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final onChangeStart = this.onChangeStart;
    final onChangeEnd = this.onChangeEnd;
    return SliderCore(
      values: [value.clamp(min, max)],
      onChanged: onChanged == null ? null : (v) => onChanged(v.single),
      onChangeStart: onChangeStart == null
          ? null
          : (v) => onChangeStart(v.single),
      onChangeEnd: onChangeEnd == null ? null : (v) => onChangeEnd(v.single),
      scale: SliderScale(
        min: min,
        max: max,
        divisions: divisions,
        steps: steps,
      ),
      label: label,
      valueBuilder: valueBuilder,
      semanticFormatter: semanticFormatter,
      editFormatter: editFormatter,
      editParser: editParser,
      variant: variant,
      valueDisplay: valueDisplay,
      size: size,
      focusNode: focusNode,
      autofocus: autofocus,
      statesController: statesController,
      motion: motion,
      motions: motions,
      style: style,
      semanticLabel: semanticLabel,
      thumbLabels: const [],
    );
  }
}
