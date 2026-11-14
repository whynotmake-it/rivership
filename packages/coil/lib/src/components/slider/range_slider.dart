import 'package:coil/foundation.dart';
import 'package:coil/src/components/slider/slider.dart';
import 'package:coil/src/components/slider/slider_core.dart';
import 'package:coil/src/components/slider/slider_scale.dart';
import 'package:coil/src/components/slider/slider_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The two values of a [CoilRangeSlider], like Flutter's `RangeValues`.
@immutable
class CoilRangeValues {
  /// Creates a range from [start] to [end].
  const CoilRangeValues(this.start, this.end);

  /// The lower value.
  final double start;

  /// The upper value.
  final double end;

  @override
  bool operator ==(Object other) =>
      other is CoilRangeValues && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'CoilRangeValues($start, $end)';
}

/// A slider for a range: two thumbs on a pill track between [min] and
/// [max].
///
/// It behaves like a [CoilSlider] with the [CoilSliderVariant.pill] look,
/// with these differences:
///
/// * The fill runs between the thumbs, and the thumbs can't cross; they may
///   meet.
/// * A tap or a drag moves the nearest thumb. On two stacked thumbs, the
///   drag's direction picks one.
/// * Each thumb is a focus stop and a slider node of its own, named
///   [startSemanticLabel] and [endSemanticLabel]. Tab moves between them.
/// * The value text reads "start – end".
///
/// The slider is controlled: it shows [values] and asks for changes through
/// [onChanged].
class CoilRangeSlider extends StatelessWidget {
  /// Creates a range slider.
  const CoilRangeSlider({
    required this.values,
    required this.onChanged,
    super.key,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.steps,
    this.onChangeStart,
    this.onChangeEnd,
    this.label,
    this.valueFormatter,
    this.valueDisplay = CoilSliderValueDisplay.text,
    this.size,
    this.autofocus = false,
    this.statesController,
    this.motion,
    this.motions,
    this.style,
    this.semanticLabel,
    this.startSemanticLabel = 'Minimum',
    this.endSemanticLabel = 'Maximum',
  }) : assert(min < max, 'min must be less than max'),
       assert(
         divisions == null || divisions > 0,
         'divisions must be positive',
       ),
       assert(
         divisions == null || steps == null,
         'use divisions or steps, not both',
       );

  /// The current range, with `start <= end`, between [min] and [max].
  final CoilRangeValues values;

  /// Called with the new range, snapped to [divisions] or [steps]. Null
  /// disables the slider.
  final ValueChanged<CoilRangeValues>? onChanged;

  /// The smallest value.
  final double min;

  /// The largest value.
  final double max;

  /// How many equal steps [min]..[max] is split into. Null, with no
  /// [steps], is continuous.
  final int? divisions;

  /// The values the thumbs can take; see [CoilSlider.steps].
  final List<double>? steps;

  /// Called with the current range when a change starts.
  final ValueChanged<CoilRangeValues>? onChangeStart;

  /// Called with the new range when that change ends.
  final ValueChanged<CoilRangeValues>? onChangeEnd;

  /// The text before the track.
  final Widget? label;

  /// Formats each value; see [CoilSlider.valueFormatter].
  final String Function(double value)? valueFormatter;

  /// Where the values show, and whether they can be typed.
  final CoilSliderValueDisplay valueDisplay;

  /// Pins the slider to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Whether the start thumb takes focus when first built.
  final bool autofocus;

  /// Observes, and can force, hover/focus/press states. Focused means
  /// either thumb has keyboard focus.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens for this instance.
  final CoilMotion? motion;

  /// Per-part motions for this instance. [CoilSliderTrack.thumb] moves both
  /// thumbs.
  final Map<CoilSliderTrack<Object>, Motion>? motions;

  /// Overrides for this slider's look.
  final CoilSliderStyle? style;

  /// A label for assistive technology for the whole slider, when [label] is
  /// not plain text.
  final String? semanticLabel;

  /// The start thumb's name for assistive technology.
  final String startSemanticLabel;

  /// The end thumb's name for assistive technology.
  final String endSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final onChangeStart = this.onChangeStart;
    final onChangeEnd = this.onChangeEnd;
    CoilRangeValues range(List<double> v) => CoilRangeValues(v.first, v.last);
    final start = values.start.clamp(min, max);
    return SliderCore(
      values: [start, values.end.clamp(start, max)],
      onChanged: onChanged == null ? null : (v) => onChanged(range(v)),
      onChangeStart: onChangeStart == null
          ? null
          : (v) => onChangeStart(range(v)),
      onChangeEnd: onChangeEnd == null ? null : (v) => onChangeEnd(range(v)),
      scale: SliderScale(
        min: min,
        max: max,
        divisions: divisions,
        steps: steps,
      ),
      label: label,
      valueFormatter: valueFormatter,
      variant: CoilSliderVariant.pill,
      valueDisplay: valueDisplay,
      size: size,
      focusNode: null,
      autofocus: autofocus,
      statesController: statesController,
      motion: motion,
      motions: motions,
      style: style,
      semanticLabel: semanticLabel,
      thumbLabels: [startSemanticLabel, endSemanticLabel],
    );
  }
}
