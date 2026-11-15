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
});

/// How long a new step's content waits to fade in after its height starts
/// to open (DESIGN.md §14.4).
const _stagger = Duration(milliseconds: 80);

/// One step of a `CoilThinkingSteps`. A step that arrives after the first
/// build ([enter]) opens its height, then fades in.
class ThinkingStepView extends StatefulWidget {
  /// Creates a step.
  const ThinkingStepView({
    required this.step,
    required this.enter,
    required this.metrics,
    required this.motions,
    required this.style,
    super.key,
  });

  /// The step.
  final CoilThinkingStep step;

  /// Whether the step arrived after the first build, so it animates in.
  final bool enter;

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

    return CoilCollapsible(
      expanded: true,
      appear: widget.enter,
      heightMotion: widget.motions.height,
      opacityMotion: widget.motions.opacity,
      opacityDelay: _stagger,
      debugLabel: 'CoilThinkingSteps.step',
      child: Padding(
        padding: style.stepPadding!,
        child: Row(
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
                child: _GlyphBox(
                  child:
                      step.leading ??
                      _Dot(color: style.glyphColor!, size: style.dotSize!),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(style: style.titleStyle!, child: step.title),
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
                          borderRadius: BorderRadius.circular(style.radius!),
                          child: image,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A box one glyph wide, so titles line up whether a step shows a glyph or
/// the smaller dot.
class _GlyphBox extends StatelessWidget {
  const _GlyphBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: CoilIconSize.of(context),
    child: Center(heightFactor: 1, child: child),
  );
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
        blur: reduced ? 0 : 4,
        scale: reduced ? 1 : 0.85,
        child: child!,
      ),
      child: badge,
    );
  }
}
