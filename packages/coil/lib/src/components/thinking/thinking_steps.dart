// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/thinking/thinking_step_view.dart';
import 'package:coil/src/components/thinking/thinking_steps_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// One step of a [CoilThinkingSteps].
@immutable
class CoilThinkingStep {
  /// Creates a step.
  const CoilThinkingStep({
    required this.title,
    this.detail,
    this.sources = const [],
    this.image,
    this.leading,
  });

  /// What the step did, in one line.
  final String title;

  /// More about the step, in a muted caption.
  final String? detail;

  /// Where the step looked, each shown in a small badge. Usually `Text`.
  final List<Widget> sources;

  /// An image under the step.
  final Widget? image;

  /// A glyph before the title, styled by [IconTheme]. A small dot when
  /// null.
  final Widget? leading;
}

/// The animated parts of a [CoilThinkingSteps]. Use them as keys of
/// [CoilThinkingSteps.motions] or [CoilThemeData.trackMotions].
final class CoilThinkingStepsTrack<T extends Object> extends Track<T> {
  CoilThinkingStepsTrack._(super.converter, {required String super.debugLabel});

  /// The chevron's quarter turn. Default motion: `quick` opening,
  /// `quickExit` closing.
  static final chevron = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.chevron',
  );

  /// How open the list of steps is, 0 to 1. Default motion: `standard`
  /// opening, `standardExit` closing.
  static final height = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.height',
  );

  /// The list's opacity. Default motion: `fade` opening, `fadeExit`
  /// closing.
  static final opacity = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.opacity',
  );

  /// The trigger's fill. Default motion: `fade` showing, `fadeExit`
  /// clearing.
  static final fill = CoilThinkingStepsTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilThinkingSteps.fill',
  );

  /// The trigger's label color. Default motion: `fade`.
  static final label = CoilThinkingStepsTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilThinkingSteps.label',
  );

  /// The trigger's label weight, normal to semibold. Default motion:
  /// `fade`.
  static final weight = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.weight',
  );

  /// How open a new step is, 0 to 1. Default motion: `gentle`.
  static final stepHeight = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.stepHeight',
  );

  /// A new step's opacity, after a short delay. Default motion: `fade`.
  static final stepOpacity = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.stepOpacity',
  );

  /// A new source badge popping in, 0 to 1. Default motion: `standard`,
  /// or `fade` under reduced motion.
  static final sourcePop = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.sourcePop',
  );
}

/// A collapsible list of reasoning steps under a trigger such as
/// "Thought for 12s".
///
/// It is controlled: it shows [expanded] and reports the new state through
/// [onChanged]. Steps added after the first build animate in. Steps
/// present at the first build show at once.
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
    this.motions,
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

  /// Per-track motions for this component, keyed by
  /// [CoilThinkingStepsTrack]s. They win over the theme's
  /// [CoilThemeData.trackMotions] and the tokens.
  final Map<CoilThinkingStepsTrack<Object>, Motion>? motions;

  /// Overrides for this component's look, on top of the theme's
  /// [CoilThinkingStepsStyle] and the defaults.
  final CoilThinkingStepsStyle? style;

  @override
  State<CoilThinkingSteps> createState() => _CoilThinkingStepsState();
}

class _CoilThinkingStepsState extends State<CoilThinkingSteps> {
  /// Steps at or past this index arrived after the first build.
  late final int _firstNew = widget.steps.length;

  Motion _track(
    CoilThinkingStepsTrack<Object> track,
    Motion token, {
    bool spatial = true,
  }) => CoilTheme.trackMotionOf(
    context,
    track,
    instance: widget.motions,
    token: token,
    spatial: spatial,
  );

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final style =
        CoilThinkingStepsStyle.fallback(
              theme,
              metrics,
              highContrast: MediaQuery.maybeHighContrastOf(context) ?? false,
            )
            .merge(CoilTheme.styleOf<CoilThinkingStepsStyle>(context))
            .merge(widget.style);
    final onChanged = widget.onChanged;
    final expanded = widget.expanded;
    final stepMotions = (
      height: _track(CoilThinkingStepsTrack.stepHeight, motion.gentle),
      opacity: _track(
        CoilThinkingStepsTrack.stepOpacity,
        motion.fade,
        spatial: false,
      ),
      sourcePop: _track(
        CoilThinkingStepsTrack.sourcePop,
        reduced ? motion.fade : motion.standard,
        spatial: false,
      ),
    );

    return MotorInspectionScope(
      group: 'CoilThinkingSteps',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: style.maxWidth!),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoilDisclosureTrigger(
              label: widget.label,
              indicator: widget.indicator,
              expanded: expanded,
              onPressed: onChanged == null ? null : () => onChanged(!expanded),
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              fill: style.triggerFill!,
              foreground: expanded ? style.expandedLabel! : style.label!,
              textStyle: style.textStyle!,
              radius: style.radius!,
              minHeight: metrics.controlHeight,
              padding: EdgeInsets.symmetric(
                horizontal: metrics.controlPaddingX,
                vertical: metrics.controlPaddingY(metrics.body),
              ),
              gap: metrics.gap,
              iconSize: metrics.iconSize,
              minHitTarget: metrics.minHitTarget,
              mainAxisSize: MainAxisSize.min,
              // Touch triggers rest at full foreground, so a disabled one
              // fades further.
              disabledOpacity: metrics.disabledRowOpacity,
              focusRingOffset: style.focusRingOffset,
              chevronMotion: _track(
                CoilThinkingStepsTrack.chevron,
                expanded ? motion.quick : motion.quickExit,
              ),
              fillMotion: _track(
                CoilThinkingStepsTrack.fill,
                motion.fade,
                spatial: false,
              ),
              fillExitMotion: _track(
                CoilThinkingStepsTrack.fill,
                motion.fadeExit,
                spatial: false,
              ),
              labelMotion: _track(
                CoilThinkingStepsTrack.label,
                motion.fade,
                spatial: false,
              ),
              weightMotion: _track(
                CoilThinkingStepsTrack.weight,
                motion.fade,
                spatial: false,
              ),
            ),
            CoilCollapsible(
              expanded: expanded,
              heightMotion: _track(
                CoilThinkingStepsTrack.height,
                expanded ? motion.standard : motion.standardExit,
              ),
              opacityMotion: _track(
                CoilThinkingStepsTrack.opacity,
                expanded ? motion.fade : motion.fadeExit,
                spatial: false,
              ),
              debugLabel: 'CoilThinkingSteps.panel',
              child: Padding(
                padding: style.panelPadding!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, step) in widget.steps.indexed)
                      ThinkingStepView(
                        key: ValueKey(i),
                        step: step,
                        enter: i >= _firstNew,
                        metrics: metrics,
                        motions: stepMotions,
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
