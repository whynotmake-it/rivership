import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/field/choice_card_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilChoiceCard], as Motor tracks. Use them as
/// keys of `motions` or [CoilThemeData.trackMotions].
final class CoilChoiceCardTrack<T extends Object> extends Track<T> {
  CoilChoiceCardTrack._(super.converter, {required String super.debugLabel});

  /// The hover and press fill. Default motion: `fade` in, `fadeExit` out.
  static final fill = CoilChoiceCardTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilChoiceCard.fill',
  );

  /// The border, which darkens while selected. Default motion: `fade`.
  static final border = CoilChoiceCardTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilChoiceCard.border',
  );
}

/// A choice as a bordered card: a [control] (a `CoilCheckbox` or
/// `CoilSwitch`) at the start, then a [title] and an optional
/// [description].
///
/// The whole card is the target: a tap anywhere toggles the control. A
/// hovering pointer fills the card and lights the control as if it were
/// over it. While the control has visible focus the ring goes around the
/// card, and the control leaves out its own. A [selected] card's border
/// darkens.
///
/// Pass the control's value as [selected], and `enabled: false` with a
/// disabled control, as with a list tile. Stack cards in a
/// `CoilFieldGroup`.
///
/// ```dart
/// CoilChoiceCard(
///   selected: gpu,
///   title: Text('Kubernetes'),
///   description: Text('Run GPU workloads on a K8s cluster.'),
///   control: CoilCheckbox(value: gpu, onChanged: (v) => setGpu(v!)),
/// )
/// ```
class CoilChoiceCard extends StatefulWidget {
  /// Creates a choice card.
  const CoilChoiceCard({
    required this.control,
    required this.title,
    super.key,
    this.description,
    this.selected = false,
    this.enabled = true,
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// The control: a `CoilCheckbox` or a `CoilSwitch`.
  final Widget control;

  /// Names the choice. Usually a [Text].
  final Widget title;

  /// One sentence about the choice, under the [title].
  final Widget? description;

  /// Whether the control is on. The border darkens.
  final bool selected;

  /// Whether the card responds. Pass false with a disabled control.
  final bool enabled;

  /// Pins the card to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Overrides single tracks' motions.
  final Map<CoilChoiceCardTrack<Object>, Motion>? motions;

  /// Overrides for this card's look.
  final CoilChoiceCardStyle? style;

  @override
  State<CoilChoiceCard> createState() => _CoilChoiceCardState();
}

class _CoilChoiceCardState extends State<CoilChoiceCard> {
  final _states = WidgetStatesController();
  final _labelTarget = CoilFieldLabelTarget();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  Motion _motionFor(CoilChoiceCardTrack<Object> track, Motion token) =>
      CoilTheme.trackMotionOf(
        context,
        track,
        instance: widget.motions,
        token: token,
        spatial: false,
      );

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilChoiceCardStyle.fallback(theme, metrics)
        .merge(CoilTheme.styleOf<CoilChoiceCardStyle>(context))
        .merge(widget.style);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final radius = BorderRadius.circular(style.radius!);
    final description = widget.description;

    final text = Opacity(
      // The control dims itself.
      opacity: widget.enabled ? 1 : metrics.disabledOpacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: style.textGap!,
        children: [
          DefaultTextStyle(style: style.titleStyle!, child: widget.title),
          if (description != null)
            DefaultTextStyle(
              style: style.descriptionStyle!,
              child: description,
            ),
        ],
      ),
    );

    Widget card(Set<WidgetState> states) {
      final hovered = states.contains(WidgetState.hovered);
      final pressed = states.contains(WidgetState.pressed);
      final fill = style.fill!.resolve({
        if (hovered) WidgetState.hovered,
        // A hovering pointer's press needs no extra fill (DESIGN.md §8.1).
        if (pressed && !hovered) WidgetState.pressed,
      })!;
      final border = style.border!.resolve({
        if (widget.selected) WidgetState.selected,
      })!;
      return MotionBuilder<Color>(
        value: border,
        converter: MotionConverter.colorRgb,
        motion: _motionFor(CoilChoiceCardTrack.border, motion.fade),
        builder: (context, border, child) => MotionBuilder<Color>(
          value: fill,
          converter: MotionConverter.colorRgb,
          motion: _motionFor(
            CoilChoiceCardTrack.fill,
            hovered || pressed ? motion.fade : motion.fadeExit,
          ),
          builder: (context, fill, child) => DecoratedBox(
            decoration: ShapeDecoration(
              color: fill,
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: BorderSide(color: border),
              ),
            ),
            child: child,
          ),
          child: child,
        ),
        child: Padding(
          padding: EdgeInsets.all(style.padding!),
          child: CoilFieldScope(
            invalid: false,
            isRequired: false,
            labelTarget: _labelTarget,
            framed: true,
            containerHovered: hovered,
            // One node: the control's role and value, read with the title
            // and description.
            child: MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: style.gap!,
                children: [
                  // The control sits centered on the title's first line.
                  CoilLineBox(style: style.titleStyle!, child: widget.control),
                  Expanded(child: text),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return CoilFocusWithin(
      builder: (context, focused, child) => CoilFocusRing(
        visible: focused,
        borderRadius: radius,
        child: child!,
      ),
      child: CoilInteractionDetector(
        states: _states,
        enabled: widget.enabled,
        onTap: _labelTarget.activate,
        // The control carries the action in semantics.
        excludeFromSemantics: true,
        cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: ListenableBuilder(
          listenable: _states,
          builder: (context, _) => card(_states.value),
        ),
      ),
    );
  }
}
