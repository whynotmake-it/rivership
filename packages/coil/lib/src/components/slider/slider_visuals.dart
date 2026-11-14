// Internal to CoilSlider; not exported.
// ignore_for_file: public_member_api_docs

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/slider/slider_layout.dart';
import 'package:coil/src/components/slider/slider_painters.dart';
import 'package:coil/src/components/slider/slider_scale.dart';
import 'package:coil/src/components/slider/slider_style.dart';
import 'package:coil/src/components/slider/slider_text.dart';
import 'package:flutter/widgets.dart';

/// Finds the pill's knobs in tests: knob `i` is keyed
/// `ValueKey((sliderKnobKey, i))`.
const sliderKnobKey = 'CoilSlider.knob';

/// Finds the value bubble in tests.
const sliderBubbleKey = ValueKey<String>('CoilSlider.bubble');

/// The regular row: label and value over a fill, a handle line and pips.
class SliderRow extends StatelessWidget {
  const SliderRow({
    required this.painter,
    required this.style,
    required this.metrics,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.emphasis,
    super.key,
  });

  final SliderRowPaint painter;
  final CoilSliderStyle style;
  final CoilMetrics metrics;
  final Widget? label;

  /// The value text, or null when the value shows in a tooltip.
  final Widget? value;
  final Color labelColor;
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final text = style.textStyle!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(style.radius!),
      child: CoilMotionLayer(
        background: [painter],
        child: CoilMotionTarget(
          index: SliderTarget.track,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: metrics.controlHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.controlPaddingX,
              ),
              // The value keeps its reserved width; the label takes what is
              // left and ellipsizes when that isn't enough.
              child: Row(
                spacing: metrics.gap,
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: label == null
                          ? null
                          : CoilMotionTarget(
                              index: SliderTarget.label,
                              child: DefaultTextStyle(
                                style: text.copyWith(
                                  color: labelColor,
                                  fontVariations: sliderWeight(emphasis),
                                ),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                child: label!,
                              ),
                            ),
                    ),
                  ),
                  if (value case final value?)
                    CoilMotionTarget(index: SliderTarget.value, child: value),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill: a thin track with a knob per thumb, between an optional label
/// and value, or below them when the row is too narrow for all three.
class SliderPill extends StatelessWidget {
  const SliderPill({
    required this.painter,
    required this.style,
    required this.metrics,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.emphasis,
    required this.thumbs,
    required this.fractions,
    required this.ring,
    required this.track,
    super.key,
  });

  final SliderPillPaint painter;
  final CoilSliderStyle style;
  final CoilMetrics metrics;
  final Widget? label;

  /// The value text, or null when the value shows in a tooltip.
  final Widget? value;
  final Color labelColor;
  final double emphasis;

  /// Notifies when a thumb moves, and the thumbs' fractions of the range.
  final Listenable thumbs;
  final ValueGetter<List<double>> fractions;

  /// The knob that shows the focus ring, if any.
  final int? ring;

  /// Wraps the pill track with the slider's gestures.
  final Widget Function(Widget track) track;

  @override
  Widget build(BuildContext context) {
    final text = style.textStyle!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final box = style.knobBox!;
    final knob = style.knobSize!;
    final knobDecoration = ShapeDecoration(
      color: style.knob,
      shadows: style.knobShadows,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(knob / 2),
      ),
    );
    final pill = CoilMotionLayer(
      background: [painter],
      child: CoilMotionTarget(
        index: SliderTarget.track,
        child: SizedBox(
          height: box,
          child: ListenableBuilder(
            listenable: thumbs,
            builder: (context, _) => Stack(
              children: [
                for (final (i, f) in fractions().indexed)
                  Align(
                    alignment: AlignmentDirectional(
                      f.clamp(0.0, 1.0) * 2 - 1,
                      0,
                    ),
                    child: SizedBox.square(
                      dimension: box,
                      child: Center(
                        child: CoilFocusRing(
                          visible: ring == i,
                          borderRadius: BorderRadius.circular(knob / 2),
                          offset: 2,
                          child: DecoratedBox(
                            key: ValueKey((sliderKnobKey, i)),
                            decoration: knobDecoration,
                            child: SizedBox.square(dimension: knob),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return SliderPillLayout(
      gap: metrics.gap,
      minTrack: style.pillMinTrack!,
      label: label == null
          ? null
          : DefaultTextStyle(
              style: text.copyWith(
                color: labelColor,
                fontVariations: sliderWeight(emphasis),
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              child: label!,
            ),
      track: track(pill),
      value: value,
    );
  }
}

/// The value bubble above the thumb or the hovered position.
class SliderBubble extends StatelessWidget {
  const SliderBubble({
    required this.style,
    required this.fraction,
    required this.reach,
    required this.rtl,
    required this.opacity,
    required this.child,
    super.key,
  });

  final CoilSliderStyle style;
  final double fraction;
  final SliderReach reach;
  final bool rtl;
  final double opacity;

  /// The value, styled by the bubble's text style.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            key: sliderBubbleKey,
            opacity: opacity.clamp(0.0, 1.0),
            child: CustomSingleChildLayout(
              delegate: SliderBubbleLayout(
                fraction: fraction.clamp(0.0, 1.0),
                reach: reach,
                rtl: rtl,
                gap: style.bubbleGap!,
              ),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: style.bubble,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(style.radius!),
                  ),
                ),
                child: Padding(
                  padding: style.bubblePadding!,
                  child: DefaultTextStyle(
                    maxLines: 1,
                    softWrap: false,
                    style: style.bubbleTextStyle!.copyWith(
                      color: style.bubbleText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
