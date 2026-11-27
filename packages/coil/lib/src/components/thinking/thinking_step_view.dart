/// @docImport 'package:coil/thinking.dart';
library;

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

/// One step of a [CoilThinkingSteps].
///
/// A step that arrives after the first build ([enter]) opens its height, then
/// fades in.
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
    required this.first,
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

  /// Whether this is the first step, which has no incoming connector from
  /// above.
  final bool first;

  /// Whether this is the last step, which has no outgoing connector below.
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
    // The content keeps the ambient icon theme; only the glyph takes the
    // step's.
    final ambientIcons = IconTheme.of(context);

    final pad = style.stepPadding!.resolve(Directionality.of(context));

    return CoilCollapsible(
      expanded: true,
      appear: widget.enter,
      heightMotion: widget.motions.height,
      opacityMotion: widget.motions.opacity,
      opacityDelay: _stagger,
      debugLabel: 'CoilThinkingSteps.step',
      child: Padding(
        padding: EdgeInsets.only(left: pad.left, right: pad.right),
        child: IconTheme(
          data: IconThemeData(
            size: widget.metrics.iconSize,
            color: style.glyphColor,
            applyTextScaling: true,
          ),
          child: Builder(
            builder: (context) {
              // The glyph column is one glyph square, so titles line up
              // whether a step shows a glyph or the smaller dot, and the
              // connector knows where the glyph ends. Glyphs grow with
              // text, so the square does too.
              final glyphExtent = CoilIconSize.of(context);
              final glyphHeight =
                  step.leading == null ? style.dotSize! : glyphExtent;
              return Stack(
                children: [
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: glyphExtent,
                    child: _Connector(
                      showTop: !widget.first,
                      showBottom: !widget.last,
                      motion: widget.motions.connector,
                      lineStyle: style.titleStyle!,
                      glyphExtent: glyphExtent,
                      glyphHeight: glyphHeight,
                      topPadding: pad.top,
                      gap: style.connectorGap!,
                      thickness: style.connectorWidth!,
                      color: style.connectorColor!,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: widget.metrics.gap,
                      children: [
                        // As tall as the title's first line, so the glyph
                        // centers on it.
                        CoilLineBox(
                          style: style.titleStyle!,
                          child: SizedBox.square(
                            dimension: glyphExtent,
                            child: Center(
                              child:
                                  step.leading ??
                                  _StatusDot(
                                    status: step.status,
                                    color: style.glyphColor!,
                                    size: style.dotSize!,
                                  ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: IconTheme(
                            data: ambientIcons,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  value: switch (step.status) {
                                    CoilThinkingStepStatus.done => null,
                                    CoilThinkingStepStatus.running =>
                                      'In progress',
                                    CoilThinkingStepStatus.error => 'Failed',
                                  },
                                  child: DefaultTextStyle(
                                    style: style.titleStyle!,
                                    child: CoilShimmer(
                                      active:
                                          step.status ==
                                          CoilThinkingStepStatus.running,
                                      child: step.title,
                                    ),
                                  ),
                                ),
                                if (step.detail case final detail?)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: style.detailGap!,
                                    ),
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
                                        for (final (i, source)
                                            in step.sources.indexed)
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
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The vertical rail around a step's glyph: an outgoing segment below when
/// [showBottom] and an incoming segment above when [showTop], so consecutive
/// steps stay joined across [CoilThinkingStepsStyle.stepPadding] even on
/// one-line steps without subtitles.
class _Connector extends StatelessWidget {
  const _Connector({
    required this.showTop,
    required this.showBottom,
    required this.motion,
    required this.lineStyle,
    required this.glyphExtent,
    required this.glyphHeight,
    required this.topPadding,
    required this.gap,
    required this.thickness,
    required this.color,
  });

  final bool showTop;
  final bool showBottom;
  final Motion motion;
  final TextStyle lineStyle;
  final double glyphExtent;
  final double glyphHeight;
  final double topPadding;
  final double gap;
  final double thickness;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomMultiChildLayout(
    delegate: _ConnectorLayout(
      glyphExtent: glyphExtent,
      glyphHeight: glyphHeight,
      topPadding: topPadding,
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
        id: _ConnectorPart.topLine,
        child: SingleMotionBuilder(
          value: showTop ? 1 : 0,
          motion: motion,
          debugLabel: 'CoilThinkingSteps.connectorTop',
          builder: (context, presence, child) => presence <= 0
              ? const SizedBox.shrink()
              : Opacity(opacity: presence.clamp(0.0, 1.0), child: child),
          child: ColoredBox(color: color),
        ),
      ),
      LayoutId(
        id: _ConnectorPart.bottomLine,
        child: SingleMotionBuilder(
          value: showBottom ? 1 : 0,
          motion: motion,
          debugLabel: 'CoilThinkingSteps.connector',
          builder: (context, presence, child) => presence <= 0
              ? const SizedBox.shrink()
              : Opacity(opacity: presence.clamp(0.0, 1.0), child: child),
          child: ColoredBox(color: color),
        ),
      ),
    ],
  );
}

enum _ConnectorPart { lineBox, topLine, bottomLine }

class _ConnectorLayout extends MultiChildLayoutDelegate {
  _ConnectorLayout({
    required this.glyphExtent,
    required this.glyphHeight,
    required this.topPadding,
    required this.gap,
    required this.thickness,
  });

  final double glyphExtent;
  final double glyphHeight;
  final double topPadding;
  final double gap;
  final double thickness;

  @override
  void performLayout(Size size) {
    final lineBox = layoutChild(
      _ConnectorPart.lineBox,
      BoxConstraints(maxWidth: size.width),
    );
    positionChild(_ConnectorPart.lineBox, Offset(0, topPadding));
    final centerX = (size.width - thickness) / 2;

    final topEnd = math.max(
      0,
      topPadding + (lineBox.height - glyphHeight) / 2 - gap,
    ).toDouble();
    layoutChild(
      _ConnectorPart.topLine,
      BoxConstraints.tight(Size(thickness, topEnd)),
    );
    positionChild(_ConnectorPart.topLine, Offset(centerX, 0));

    final bottomStart =
        topPadding + (lineBox.height + glyphHeight) / 2 + gap;
    final bottomLength = math.max(0, size.height - bottomStart).toDouble();
    layoutChild(
      _ConnectorPart.bottomLine,
      BoxConstraints.tight(Size(thickness, bottomLength)),
    );
    positionChild(_ConnectorPart.bottomLine, Offset(centerX, bottomStart));
  }

  @override
  bool shouldRelayout(_ConnectorLayout oldDelegate) =>
      glyphExtent != oldDelegate.glyphExtent ||
      glyphHeight != oldDelegate.glyphHeight ||
      topPadding != oldDelegate.topPadding ||
      gap != oldDelegate.gap ||
      thickness != oldDelegate.thickness;
}

/// The dot shown when a step has no leading glyph.
/// The default glyph, by status: the style's dot when done; a dot in the
/// foreground color breathing between 55 % and 100 % of [size] × 4⁄3 while
/// running (still under reduced motion); a destructive dot when failed.
class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.status,
    required this.color,
    required this.size,
  });

  final CoilThinkingStepStatus status;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return switch (status) {
      CoilThinkingStepStatus.done => _Dot(color: color, size: size),
      CoilThinkingStepStatus.error => _Dot(
        color: colors.destructive,
        size: size,
      ),
      CoilThinkingStepStatus.running => CoilPulse(
        builder: (context, t) => Opacity(
          opacity: 0.55 + 0.45 * t,
          child: _Dot(
            color: colors.foreground,
            size: size * 4 / 3 * (0.55 + 0.45 * t),
          ),
        ),
      ),
    };
  }
}

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
