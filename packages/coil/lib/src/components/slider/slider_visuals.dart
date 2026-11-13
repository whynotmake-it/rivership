// Internal to CoilSlider; not exported.
// ignore_for_file: public_member_api_docs

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/slider/slider_painters.dart';
import 'package:coil/src/components/slider/slider_scale.dart';
import 'package:coil/src/components/slider/slider_style.dart';
import 'package:coil/src/components/slider/slider_text.dart';
import 'package:flutter/widgets.dart';

/// Finds the pill's knob in tests.
const sliderKnobKey = ValueKey<String>('CoilSlider.knob');

/// Finds the value bubble in tests.
const sliderBubbleKey = ValueKey<String>('CoilSlider.bubble');

/// The regular row: label and value over a fill, a handle line and pips.
class SliderRow extends StatelessWidget {
  const SliderRow({
    required this.painter,
    required this.style,
    required this.metrics,
    required this.label,
    required this.valueText,
    required this.reserve,
    required this.labelColor,
    required this.valueColor,
    required this.emphasis,
    super.key,
  });

  final SliderRowPaint painter;
  final CoilSliderStyle style;
  final CoilMetrics metrics;
  final Widget? label;
  final String valueText;
  final Set<String> reserve;
  final Color labelColor;
  final Color valueColor;
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
              child: Row(
                children: [
                  if (label != null)
                    CoilMotionTarget(
                      index: SliderTarget.label,
                      child: DefaultTextStyle(
                        style: text.copyWith(
                          color: labelColor,
                          fontVariations: sliderWeight(emphasis),
                        ),
                        maxLines: 1,
                        softWrap: false,
                        child: label!,
                      ),
                    ),
                  const Spacer(),
                  CoilMotionTarget(
                    index: SliderTarget.value,
                    child: SliderValueText(
                      text: valueText,
                      reserve: reserve,
                      style: text,
                      color: valueColor,
                      emphasis: emphasis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill: a thin track with a knob, between an optional label and value.
class SliderPill extends StatelessWidget {
  const SliderPill({
    required this.painter,
    required this.style,
    required this.metrics,
    required this.label,
    required this.valueText,
    required this.reserve,
    required this.labelColor,
    required this.valueColor,
    required this.emphasis,
    required this.thumb,
    required this.thumbFraction,
    required this.track,
    super.key,
  });

  final SliderPillPaint painter;
  final CoilSliderStyle style;
  final CoilMetrics metrics;
  final Widget? label;
  final String valueText;
  final Set<String> reserve;
  final Color labelColor;
  final Color valueColor;
  final double emphasis;

  /// Notifies when the thumb moves, and its fraction of the range.
  final Listenable thumb;
  final ValueGetter<double> thumbFraction;

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
            listenable: thumb,
            builder: (context, _) => Align(
              alignment: AlignmentDirectional(
                thumbFraction().clamp(0.0, 1.0) * 2 - 1,
                0,
              ),
              child: SizedBox.square(
                dimension: box,
                child: Center(
                  child: DecoratedBox(
                    key: sliderKnobKey,
                    decoration: knobDecoration,
                    child: SizedBox.square(dimension: knob),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      spacing: metrics.gap,
      children: [
        if (label != null)
          DefaultTextStyle(
            style: text.copyWith(
              color: labelColor,
              fontVariations: sliderWeight(emphasis),
            ),
            maxLines: 1,
            softWrap: false,
            child: label!,
          ),
        Expanded(child: track(pill)),
        SliderValueText(
          text: valueText,
          reserve: reserve,
          style: text,
          color: valueColor,
          emphasis: emphasis,
        ),
      ],
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
    required this.text,
    super.key,
  });

  final CoilSliderStyle style;
  final double fraction;
  final SliderReach reach;
  final bool rtl;
  final double opacity;
  final String text;

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
                  child: Text(
                    text,
                    maxLines: 1,
                    softWrap: false,
                    style: style.bubbleTextStyle!.copyWith(
                      color: style.bubbleText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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
