// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/thinking/thinking_step_view.dart';
import 'package:coil/src/components/thinking/thinking_steps_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// Where a [CoilThinkingStep] stands.
enum CoilThinkingStepStatus {
  /// Finished: a small muted dot.
  done,

  /// Under way: the dot breathes in the foreground color and a highlight
  /// sweeps across the title. Write the title in the present tense
  /// ("Searching the library…"), since reduced motion stills both.
  running,

  /// Failed: the dot turns [CoilColors.destructive]. Say what failed in the
  /// title or [CoilThinkingStep.detail]; color alone doesn't.
  error,
}

/// A single reasoning step displayed in [CoilThinkingSteps].
@immutable
class CoilThinkingStep {
  /// Creates a step.
  const CoilThinkingStep({
    required this.title,
    this.key,
    this.detail,
    this.sources = const [],
    this.image,
    this.leading,
    this.status = CoilThinkingStepStatus.done,
  });

  /// Optional identity key so inserting, removing, or folding steps preserves
  /// step state without shifting animations.
  final Key? key;

  /// Whether the step is done, running or failed.
  ///
  /// It sets the default dot's look (a [leading] glyph replaces the dot),
  /// sweeps a highlight across a running step's title, and tells screen
  /// readers "In progress" or "Failed".
  final CoilThinkingStepStatus status;

  /// What the step did, in one line.
  ///
  /// Usually a [Text].
  final Widget title;

  /// More about the step, in a muted caption.
  ///
  /// Usually a [Text].
  final Widget? detail;

  /// Where the step looked, each shown in a small badge.
  ///
  /// Usually [Text] widgets.
  final List<Widget> sources;

  /// An image under the step.
  final Widget? image;

  /// A glyph before the title, styled by [IconTheme].
  ///
  /// Shows a small dot when null, which follows [status].
  final Widget? leading;
}

/// The animated parts of a [CoilThinkingSteps].
///
/// Use these as keys of [CoilThinkingSteps.motions] or
/// [CoilThinkingStepsStyle.motions].
final class CoilThinkingStepsTrack<T extends Object> extends Track<T> {
  CoilThinkingStepsTrack._(super.converter, {required String super.debugLabel});

  /// The chevron's quarter turn.
  ///
  /// Defaults to [CoilMotion.quick] opening and [CoilMotion.quickExit] closing.
  static final chevron = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.chevron',
  );

  /// How open the list of steps is, from 0 to 1.
  ///
  /// Defaults to [CoilMotion.standard] opening and [CoilMotion.standardExit]
  /// closing.
  static final height = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.height',
  );

  /// The list's opacity.
  ///
  /// Defaults to [CoilMotion.fade] opening and [CoilMotion.fadeExit] closing.
  static final opacity = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.opacity',
  );

  /// The trigger's fill.
  ///
  /// Defaults to [CoilMotion.fade] showing and [CoilMotion.fadeExit] clearing.
  static final fill = CoilThinkingStepsTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilThinkingSteps.fill',
  );

  /// The trigger's label color.
  ///
  /// Defaults to [CoilMotion.fade].
  static final label = CoilThinkingStepsTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilThinkingSteps.label',
  );

  /// The trigger's label weight, from normal to semibold.
  ///
  /// Defaults to [CoilMotion.fade].
  static final weight = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.weight',
  );

  /// How open a new step is, from 0 to 1.
  ///
  /// Defaults to [CoilMotion.gentle].
  static final stepHeight = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.stepHeight',
  );

  /// A new step's opacity, after a short delay.
  ///
  /// Defaults to [CoilMotion.fade].
  static final stepOpacity = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.stepOpacity',
  );

  /// A step's connector showing or hiding as the step stops or starts
  /// being the last one, from 0 to 1.
  ///
  /// Defaults to [CoilMotion.fade].
  static final connector = CoilThinkingStepsTrack<double>._(
    .single,
    debugLabel: 'CoilThinkingSteps.connector',
  );

  /// A new source badge popping in, from 0 to 1.
  ///
  /// Defaults to [CoilMotion.standard], or [CoilMotion.fade] under reduced
  /// motion.
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
    this.active,
    this.indicator,
    this.focusNode,
    this.autofocus = false,
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// Whether work is currently in progress.
  ///
  /// When null, defaults to `true` while any step in [steps] has
  /// [CoilThinkingStepStatus.running]. While active, a highlight sweeps across
  /// [label].
  final bool? active;

  /// The trigger's text, for example `Text('Thought for 12s')`.
  ///
  /// Turns semibold while expanded.
  final Widget label;

  /// The steps, oldest first.
  ///
  /// Append to add a step.
  final List<CoilThinkingStep> steps;

  /// Whether the steps show.
  final bool expanded;

  /// Called with the new expanded state when the trigger is pressed.
  ///
  /// When null, disables the trigger.
  final ValueChanged<bool>? onChanged;

  /// Replaces the chevron ([CoilIcons.chevronEnd]).
  ///
  /// Turns a quarter when the steps open.
  final Widget? indicator;

  /// The trigger's focus node.
  final FocusNode? focusNode;

  /// Whether the trigger takes focus when first built.
  final bool autofocus;

  /// Pins the component to one size step.
  ///
  /// Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions for this component, keyed by [CoilThinkingStepsTrack]s.
  ///
  /// They win over the style's [CoilThinkingStepsStyle.motions] and the tokens.
  final Map<CoilThinkingStepsTrack<Object>, Motion>? motions;

  /// Overrides for this component's look, on top of the theme's
  /// [CoilThinkingStepsStyle] and the defaults.
  final CoilThinkingStepsStyle? style;

  @override
  State<CoilThinkingSteps> createState() => _CoilThinkingStepsState();
}

class _CoilThinkingStepsState extends State<CoilThinkingSteps> {
  /// Steps at or past this index arrived after the first build.
  ///
  /// It drops when steps are removed, so steps added after a clear (a retry)
  /// grow in again.
  late int _firstNew = widget.steps.length;

  @override
  void didUpdateWidget(CoilThinkingSteps oldWidget) {
    super.didUpdateWidget(oldWidget);
    _firstNew = math.min(_firstNew, widget.steps.length);
  }

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
    Motion motionFor(
      CoilThinkingStepsTrack<Object> track,
      Motion token, {
      bool spatial = true,
    }) => CoilTheme.trackMotionOf(
      context,
      track,
      instance: widget.motions,
      styled: style.motions,
      token: token,
      spatial: spatial,
    );
    final onChanged = widget.onChanged;
    final hasSteps = widget.steps.isNotEmpty;
    final staticHeader = !hasSteps && onChanged == null;
    final expanded = !staticHeader && widget.expanded;
    final isActive =
        widget.active ??
        widget.steps.any((s) => s.status == CoilThinkingStepStatus.running);
    final stepMotions = (
      height: motionFor(CoilThinkingStepsTrack.stepHeight, motion.gentle),
      opacity: motionFor(
        CoilThinkingStepsTrack.stepOpacity,
        motion.fade,
        spatial: false,
      ),
      sourcePop: motionFor(
        CoilThinkingStepsTrack.sourcePop,
        reduced ? motion.fade : motion.standard,
        spatial: false,
      ),
      connector: motionFor(
        CoilThinkingStepsTrack.connector,
        motion.fade,
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
              label: CoilShimmer(active: isActive, child: widget.label),
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
              padding: style.triggerPadding!,
              gap: metrics.gap,
              iconSize: metrics.iconSize,
              minHitTarget: metrics.minHitTarget,
              mainAxisSize: MainAxisSize.min,
              showIndicator: !staticHeader,
              // Touch triggers rest at full foreground, so a disabled one
              // fades further. Static status headers stay at full opacity.
              disabledOpacity: staticHeader ? 1 : metrics.disabledRowOpacity,
              focusRingOffset: style.focusRingOffset,
              chevronMotion: motionFor(
                CoilThinkingStepsTrack.chevron,
                expanded ? motion.quick : motion.quickExit,
              ),
              fillMotion: motionFor(
                CoilThinkingStepsTrack.fill,
                motion.fade,
                spatial: false,
              ),
              fillExitMotion: motionFor(
                CoilThinkingStepsTrack.fill,
                motion.fadeExit,
                spatial: false,
              ),
              labelMotion: motionFor(
                CoilThinkingStepsTrack.label,
                motion.fade,
                spatial: false,
              ),
              weightMotion: motionFor(
                CoilThinkingStepsTrack.weight,
                motion.fade,
                spatial: false,
              ),
            ),
            CoilCollapsible(
              expanded: expanded,
              heightMotion: motionFor(
                CoilThinkingStepsTrack.height,
                expanded ? motion.standard : motion.standardExit,
              ),
              opacityMotion: motionFor(
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
                        key: step.key ?? ValueKey(i),
                        step: step,
                        enter: i >= _firstNew,
                        first: i == 0,
                        last: i == widget.steps.length - 1,
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
