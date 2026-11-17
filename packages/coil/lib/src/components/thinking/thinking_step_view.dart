import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/thinking/thinking_steps.dart';
import 'package:coil/src/components/thinking/thinking_steps_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The resolved motions of a step's entrance.
typedef ThinkingStepMotions = ({
  Motion height,
  Motion opacity,
  Motion sourcePop,
  Motion connector,
});

/// How long a new step's content waits to fade in after its height starts
/// to open (DESIGN.md §14.4).
const _stagger = Duration(milliseconds: 80);

/// One step of a `CoilThinkingSteps`. A step that arrives after the first
/// build ([enter]) opens its height, then fades in.
///
/// Every step but the [last] draws a connector down from its glyph, beside
/// the rest of the step. It is laid out with the step, so it follows long
/// titles, text scaling and new content, and it is revealed with the step's
/// own height as the step opens.
class ThinkingStepView extends StatefulWidget {
  /// Creates a step.
  const ThinkingStepView({
    required this.step,
    required this.enter,
    required this.last,
    required this.metrics,
    required this.motions,
    required this.style,
    super.key,
  });

  /// The step.
  final CoilThinkingStep step;

  /// Whether the step arrived after the first build, so it animates in.
  final bool enter;

  /// Whether this is the last step, which has no connector.
  final bool last;

  /// The component's metrics.
  final CoilMetrics metrics;

  /// The entrance motions.
  final ThinkingStepMotions motions;

  /// The component's resolved style.
  final CoilThinkingStepsStyle style;

  @override
  State<ThinkingStepView> createState() => _ThinkingStepViewState();
}

class _ThinkingStepViewState extends State<ThinkingStepView> {
  /// Sources at or past this index arrived after the step did.
  late final int _firstNewSource = widget.enter
      ? 0
      : widget.step.sources.length;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final style = widget.style;
    final sectionGap = style.sectionGap!;
    final sourceGap = style.sourceGap!;
    // The glyph column is one glyph square, so titles line up whether a
    // step shows a glyph or the smaller dot, and the connector knows where
    // the glyph ends. Glyphs grow with text, so the square does too.
    final glyphExtent = MediaQuery.textScalerOf(
      context,
    ).scale(widget.metrics.iconSize);

    return CoilCollapsible(
      expanded: true,
      appear: widget.enter,
      heightMotion: widget.motions.height,
      opacityMotion: widget.motions.opacity,
      opacityDelay: _stagger,
      debugLabel: 'CoilThinkingSteps.step',
      child: Padding(
        padding: style.stepPadding!,
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: glyphExtent,
              child: _Connector(
                visible: !widget.last,
                motion: widget.motions.connector,
                lineStyle: style.titleStyle!,
                glyphExtent: glyphExtent,
                gap: style.connectorGap!,
                thickness: style.connectorWidth!,
                color: style.connectorColor!,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: widget.metrics.gap,
              children: [
                IconTheme(
                  data: IconThemeData(
                    size: widget.metrics.iconSize,
                    color: style.glyphColor,
                    applyTextScaling: true,
                  ),
                  // As tall as the title's first line, so the glyph centers on
                  // it.
                  child: CoilLineBox(
                    style: style.titleStyle!,
                    child: SizedBox.square(
                      dimension: glyphExtent,
                      child: Center(
                        child:
                            step.leading ??
                            _Dot(
                              color: style.glyphColor!,
                              size: style.dotSize!,
                            ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle(
                        style: style.titleStyle!,
                        child: step.title,
                      ),
                      if (step.detail case final detail?)
                        Padding(
                          padding: EdgeInsets.only(top: style.detailGap!),
                          child: DefaultTextStyle(
                            style: style.detailStyle!,
                            child: detail,
                          ),
                        ),
                      if (step.sources.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: sectionGap),
                          child: Wrap(
                            spacing: sourceGap,
                            runSpacing: sourceGap,
                            children: [
                              for (final (i, source) in step.sources.indexed)
                                _SourceBadge(
                                  key: ValueKey(i),
                                  enter: i >= _firstNewSource,
                                  motion: widget.motions.sourcePop,
                                  style: style,
                                  child: source,
                                ),
                            ],
                          ),
                        ),
                      if (step.image case final image?)
                        Padding(
                          padding: EdgeInsets.only(top: sectionGap),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: style.imageMaxWidth!,
                            ),
                            child: ClipRSuperellipse(
                              borderRadius: BorderRadius.circular(
                                style.radius!,
                              ),
                              child: image,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The line under a step's glyph, filling the glyph column from just below
/// the glyph to the bottom of the step's content.
///
/// The glyph's place comes from layout: an invisible copy of the glyph's
/// line box sits where the real one does, and the line starts [gap] below
/// the glyph's box centered in it. A step with nothing under its first line
/// leaves the line no room, so it doesn't show.
class _Connector extends StatelessWidget {
  const _Connector({
    required this.visible,
    required this.motion,
    required this.lineStyle,
    required this.glyphExtent,
    required this.gap,
    required this.thickness,
    required this.color,
  });

  final bool visible;
  final Motion motion;
  final TextStyle lineStyle;
  final double glyphExtent;
  final double gap;
  final double thickness;
  final Color color;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: visible ? 1 : 0,
    motion: motion,
    debugLabel: 'CoilThinkingSteps.connector',
    builder: (context, presence, child) => presence <= 0
        ? const SizedBox.shrink()
        : Opacity(opacity: presence.clamp(0.0, 1.0), child: child),
    child: CustomMultiChildLayout(
      delegate: _ConnectorLayout(
        glyphExtent: glyphExtent,
        gap: gap,
        thickness: thickness,
      ),
      children: [
        LayoutId(
          id: _ConnectorPart.lineBox,
          child: CoilLineBox(
            style: lineStyle,
            child: SizedBox.square(dimension: glyphExtent),
          ),
        ),
        LayoutId(
          id: _ConnectorPart.line,
          child: ColoredBox(color: color),
        ),
      ],
    ),
  );
}

enum _ConnectorPart { lineBox, line }

class _ConnectorLayout extends MultiChildLayoutDelegate {
  _ConnectorLayout({
    required this.glyphExtent,
    required this.gap,
    required this.thickness,
  });

  final double glyphExtent;
  final double gap;
  final double thickness;

  @override
  void performLayout(Size size) {
    final lineBox = layoutChild(
      _ConnectorPart.lineBox,
      BoxConstraints(maxWidth: size.width),
    );
    positionChild(_ConnectorPart.lineBox, Offset.zero);
    final top = (lineBox.height + glyphExtent) / 2 + gap;
    final length = math.max(0, size.height - top).toDouble();
    layoutChild(
      _ConnectorPart.line,
      BoxConstraints.tight(Size(thickness, length)),
    );
    positionChild(
      _ConnectorPart.line,
      Offset((size.width - thickness) / 2, top),
    );
  }

  @override
  bool shouldRelayout(_ConnectorLayout oldDelegate) =>
      glyphExtent != oldDelegate.glyphExtent ||
      gap != oldDelegate.gap ||
      thickness != oldDelegate.thickness;
}

/// The dot shown when a step has no leading glyph.
class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: color,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(size / 2),
      ),
    ),
    child: SizedBox.square(dimension: size),
  );
}

/// A solid gray badge around a source, in caption text that doesn't grow
/// on touch.
///
/// A source added after its step appeared pops in: it scales up and
/// unblurs. Reduced motion fades it in.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({
    required this.enter,
    required this.motion,
    required this.style,
    required this.child,
    super.key,
  });

  final bool enter;
  final Motion motion;
  final CoilThinkingStepsStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final badge = DecoratedBox(
      decoration: ShapeDecoration(
        color: style.sourceFill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(style.radius!),
          side: switch (style.sourceBorder) {
            final color? => BorderSide(color: color),
            null => BorderSide.none,
          },
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: style.sourceMinHeight!),
        child: Padding(
          padding: style.sourcePadding!,
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: DefaultTextStyle(
              style: style.sourceTextStyle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: child,
            ),
          ),
        ),
      ),
    );
    if (!enter) return badge;
    return SingleMotionBuilder(
      value: 1,
      from: 0,
      motion: motion,
      debugLabel: 'CoilThinkingSteps.sourcePop',
      builder: (context, presence, child) => CoilBlurFade(
        presence: AlwaysStoppedAnimation(presence),
        blur: reduced ? 0 : CoilBlurFade.defaultBlur,
        scale: reduced ? 1 : 0.85,
        child: child!,
      ),
      child: badge,
    );
  }
}
