// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/thinking/thinking_steps_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// One step of a [CoilThinkingSteps].
@immutable
class CoilThinkingStep {
  /// Creates a step.
  const CoilThinkingStep({
    required this.title,
    this.detail,
    this.sources = const [],
    this.image,
    this.icon,
  });

  /// What the step did, in one line.
  final String title;

  /// More about the step, in a muted caption.
  final String? detail;

  /// Where the step looked, each shown in a small badge. Usually `Text`.
  final List<Widget> sources;

  /// An image under the step, at most 200 wide.
  final Widget? image;

  /// A glyph before the title, styled by [IconTheme]. A small dot when
  /// null.
  final Widget? icon;
}

/// A collapsible list of reasoning steps under a trigger such as
/// "Thought for 12s".
///
/// It is controlled: it shows [expanded] and reports the new state through
/// [onChanged]. Steps added while it is shown grow in on the `gentle`
/// spring and fade in 80 ms later, and new sources pop in with a short
/// blur. Steps present when it first builds show at once.
class CoilThinkingSteps extends StatefulWidget {
  /// Creates thinking steps.
  const CoilThinkingSteps({
    required this.label,
    required this.steps,
    required this.expanded,
    required this.onChanged,
    super.key,
    this.indicator,
    this.focusNode,
    this.autofocus = false,
    this.size,
    this.motion,
    this.style,
  });

  /// The trigger's text, for example `Text('Thought for 12s')`. It turns
  /// semibold while expanded.
  final Widget label;

  /// The steps, oldest first. Append to add a step.
  final List<CoilThinkingStep> steps;

  /// Whether the steps show.
  final bool expanded;

  /// Called with the new expanded state when the trigger is pressed. Null
  /// disables the trigger.
  final ValueChanged<bool>? onChanged;

  /// Replaces the chevron. It turns a quarter when the steps open.
  final Widget? indicator;

  /// The trigger's focus node.
  final FocusNode? focusNode;

  /// Whether the trigger takes focus when first built.
  final bool autofocus;

  /// Pins the component to one size step. Null follows
  /// [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Overrides for this component's look, on top of the theme's
  /// [CoilThinkingStepsStyle] and the defaults.
  final CoilThinkingStepsStyle? style;

  @override
  State<CoilThinkingSteps> createState() => _CoilThinkingStepsState();
}

class _CoilThinkingStepsState extends State<CoilThinkingSteps> {
  /// Steps at or past this index arrived after the first build.
  late final int _firstNew = widget.steps.length;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final style =
        CoilThinkingStepsStyle.fallback(
              theme,
              metrics,
              highContrast: MediaQuery.maybeHighContrastOf(context) ?? false,
            )
            .merge(CoilTheme.styleOf<CoilThinkingStepsStyle>(context))
            .merge(widget.style);
    final onChanged = widget.onChanged;

    return MotorInspectionScope(
      group: 'CoilThinkingSteps',
      // DESIGN.md §14.4: 320 wide at most.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Trigger(
              label: widget.label,
              expanded: widget.expanded,
              indicator: widget.indicator,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              onPressed: onChanged == null
                  ? null
                  : () => onChanged(!widget.expanded),
              metrics: metrics,
              motion: motion,
              style: style,
            ),
            CoilCollapsible(
              expanded: widget.expanded,
              motion: widget.motion,
              debugLabel: 'CoilThinkingSteps.panel',
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: metrics.controlPaddingX,
                  end: metrics.controlPaddingX,
                  bottom: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, step) in widget.steps.indexed)
                      _Step(
                        key: ValueKey(i),
                        step: step,
                        enter: i >= _firstNew,
                        metrics: metrics,
                        motion: motion,
                        style: style,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The trigger: label and chevron in a row as wide as its content.
class _Trigger extends StatelessWidget {
  const _Trigger({
    required this.label,
    required this.expanded,
    required this.indicator,
    required this.focusNode,
    required this.autofocus,
    required this.onPressed,
    required this.metrics,
    required this.motion,
    required this.style,
  });

  final Widget label;
  final bool expanded;
  final Widget? indicator;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onPressed;
  final CoilMetrics metrics;
  final CoilMotion motion;
  final CoilThinkingStepsStyle style;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(style.radius!);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final semibold = style.textStyle!.copyWith(
      fontVariations: CoilWeight.semibold.variations,
    );
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      expanded: expanded,
      child: CoilInteraction(
        onPressed: onPressed,
        focusNode: focusNode,
        autofocus: autofocus,
        minHitTarget: metrics.minHitTarget,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          final fill = style.triggerFill!.resolve({
            if (hovered) WidgetState.hovered,
            if (pressed && !hovered) WidgetState.pressed,
          })!;
          final color = style.label!.resolve({
            if (expanded) WidgetState.selected,
            if (hovered) WidgetState.hovered,
          })!;
          return Opacity(
            opacity: onPressed == null ? 0.5 : 1,
            child: CoilFocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: radius,
              offset: 2,
              child: MotionBuilder<Color>(
                value: fill,
                motion: fill.a > 0 ? motion.fade : motion.fadeExit,
                converter: MotionConverter.colorRgb,
                debugLabel: 'CoilThinkingSteps.fill',
                builder: (context, fill, child) => DecoratedBox(
                  decoration: ShapeDecoration(
                    color: fill,
                    shape: RoundedSuperellipseBorder(borderRadius: radius),
                  ),
                  child: child,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: metrics.controlHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: metrics.controlPaddingX,
                      vertical: metrics.controlPaddingY(metrics.body),
                    ),
                    child: MotionBuilder<Color>(
                      value: color,
                      motion: motion.fade,
                      converter: MotionConverter.colorRgb,
                      debugLabel: 'CoilThinkingSteps.label',
                      builder: (context, color, _) => IconTheme(
                        data: IconThemeData(
                          size: metrics.iconSize,
                          applyTextScaling: true,
                          color: color,
                          weight: expanded || hovered
                              ? CoilIconWeight.emphasis
                              : CoilIconWeight.rest,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: metrics.gap,
                          children: [
                            Flexible(
                              // A hidden semibold copy reserves the width.
                              child: Stack(
                                children: [
                                  ExcludeSemantics(
                                    child: Opacity(
                                      opacity: 0,
                                      child: _line(semibold, label),
                                    ),
                                  ),
                                  _line(
                                    (expanded ? semibold : style.textStyle!)
                                        .copyWith(color: color),
                                    label,
                                  ),
                                ],
                              ),
                            ),
                            MotionRotation(
                              turns: expanded ? (rtl ? -0.25 : 0.25) : 0,
                              motion: expanded
                                  ? motion.quick
                                  : motion.quickExit,
                              debugLabel: 'CoilThinkingSteps.chevron',
                              child: indicator ?? const _Chevron(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _line(TextStyle style, Widget child) => DefaultTextStyle(
    style: style,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    softWrap: false,
    child: child,
  );
}

/// One step. A step that arrives later grows its height on `gentle`, then
/// fades in 80 ms later on `fade`.
class _Step extends StatefulWidget {
  const _Step({
    required this.step,
    required this.enter,
    required this.metrics,
    required this.motion,
    required this.style,
    super.key,
  });

  final CoilThinkingStep step;
  final bool enter;
  final CoilMetrics metrics;
  final CoilMotion motion;
  final CoilThinkingStepsStyle style;

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> {
  /// The delay between a new step's height opening and its content fading
  /// in (DESIGN.md §14.4).
  static const _fadeDelay = Duration(milliseconds: 80);

  Timer? _delay;
  late bool _visible = !widget.enter;

  /// Sources at or past this index arrived after the step did.
  late final int _firstNewSource = widget.enter
      ? 0
      : widget.step.sources.length;

  @override
  void initState() {
    super.initState();
    if (widget.enter) {
      _delay = Timer(_fadeDelay, () => setState(() => _visible = true));
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final metrics = widget.metrics;
    final style = widget.style;
    final scaler = MediaQuery.textScalerOf(context);
    final radius = BorderRadius.circular(style.radius!);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: metrics.gap,
        children: [
          // As tall as the title's first line, so the glyph centers on it.
          SizedBox(
            width: scaler.scale(metrics.iconSize),
            height: scaler.scale(metrics.body.lineHeight),
            child: Center(
              child: IconTheme(
                data: IconThemeData(
                  size: metrics.iconSize,
                  color: style.glyphColor,
                  applyTextScaling: true,
                ),
                child: step.icon ?? _Dot(color: style.glyphColor!),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: style.titleStyle),
                if (step.detail case final detail?)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(detail, style: style.detailStyle),
                  ),
                if (step.sources.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (i, source) in step.sources.indexed)
                          _SourceBadge(
                            key: ValueKey(i),
                            enter: i >= _firstNewSource,
                            motion: widget.motion,
                            style: style,
                            child: source,
                          ),
                      ],
                    ),
                  ),
                if (step.image case final image?)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: ClipRSuperellipse(
                        borderRadius: radius,
                        child: image,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return SingleMotionBuilder(
      value: 1,
      from: widget.enter ? 0 : null,
      motion: widget.motion.gentle,
      debugLabel: 'CoilThinkingSteps.stepHeight',
      builder: (context, height, child) => ClipRect(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: height < 0 ? 0 : height,
          child: child,
        ),
      ),
      child: SingleMotionBuilder(
        value: _visible ? 1 : 0,
        motion: widget.motion.fade,
        debugLabel: 'CoilThinkingSteps.stepOpacity',
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity.clamp(0, 1), child: child),
        child: content,
      ),
    );
  }
}

/// The 6 px dot shown when a step has no icon.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: color,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(3)),
    ),
    child: const SizedBox.square(dimension: 6),
  );
}

/// A solid gray badge around a source. A stand-in until coil has a Badge
/// component: 24 high, padding 10, caption text, never bigger on touch.
///
/// A source added after its step appeared scales 0.85 → 1 and unblurs
/// 4 → 0 on `standard`. Reduced motion fades it in on `fade`.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({
    required this.enter,
    required this.motion,
    required this.style,
    required this.child,
    super.key,
  });

  final bool enter;
  final CoilMotion motion;
  final CoilThinkingStepsStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final text = style.sourceTextStyle!;
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
        constraints: const BoxConstraints(minHeight: 24),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: (24 - text.fontSize! * text.height!) / 2,
          ),
          child: DefaultTextStyle(
            style: text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: child,
          ),
        ),
      ),
    );
    if (!enter) return badge;
    return SingleMotionBuilder(
      value: 1,
      from: 0,
      motion: reduced ? motion.fade : motion.standard,
      debugLabel: 'CoilThinkingSteps.source',
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

/// The default indicator: a chevron pointing toward the end, drawn in the
/// [IconTheme]'s size, color and weight (1.5 stroke at 400, 2 at 533).
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    final icons = IconTheme.of(context);
    return CustomPaint(
      size: Size.square(CoilIconSize.of(context)),
      painter: _ChevronPainter(
        color: icons.color ?? const Color(0xFF000000),
        stroke: 1.5 * (icons.weight ?? CoilIconWeight.rest) / 400,
        rtl: Directionality.of(context) == TextDirection.rtl,
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter({
    required this.color,
    required this.stroke,
    required this.rtl,
  });

  final Color color;
  final double stroke;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    // On the 24-unit grid; mirrored so it points to the end in RTL.
    double x(double v) => (rtl ? 24 - v : v) * s;
    canvas.drawPath(
      Path()
        ..moveTo(x(9), 6 * s)
        ..lineTo(x(15), 12 * s)
        ..lineTo(x(9), 18 * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.color != color || old.stroke != stroke || old.rtl != rtl;
}
