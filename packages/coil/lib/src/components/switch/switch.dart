// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/switch/switch_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilSwitch], as Motor tracks. Use them as keys
/// of [CoilSwitch.motions] or [CoilThemeData.trackMotions].
final class CoilSwitchTrack<T extends Object> extends Track<T> {
  CoilSwitchTrack._(super.converter, {required String super.debugLabel});

  /// The thumb's position, 0 (off) to 1 (on). Default motion: `standard`.
  static final thumb = CoilSwitchTrack<double>._(
    .single,
    debugLabel: 'CoilSwitch.thumb',
  );

  /// How pressed the thumb is, 0 to 1. Default motion: `quick`.
  static final squish = CoilSwitchTrack<double>._(
    .single,
    debugLabel: 'CoilSwitch.squish',
  );

  /// The track color, 0 (off) to 1 (on). Default motion: `fade`.
  static final tint = CoilSwitchTrack<double>._(
    .single,
    debugLabel: 'CoilSwitch.tint',
  );

  /// How hovered the thumb and track are, 0 to 1. Default motion: `quick`.
  static final hover = CoilSwitchTrack<double>._(
    .single,
    debugLabel: 'CoilSwitch.hover',
  );

  /// The label color. Default motion: `fade`.
  static final label = CoilSwitchTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilSwitch.label',
  );
}

/// A switch with an optional label.
///
/// Tap, Space or Enter toggles it. It can also be dragged: on release the
/// thumb decides by where it would land a moment later, so a quick flick
/// toggles from the near side and a slow drag decides by position.
///
/// The animated parts are [CoilSwitchTrack]s; override them with [motions].
class CoilSwitch extends StatefulWidget {
  /// Creates a switch.
  const CoilSwitch({
    required this.value,
    required this.onChanged,
    super.key,
    this.label,
    this.size,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.motion,
    this.motions,
    this.style,
    this.semanticLabel,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value. Null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// A label after the track. Muted while off.
  final Widget? label;

  /// Pins the switch to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Observes, and can force, hover/focus/press states.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for this
  /// instance.
  final CoilMotion? motion;

  /// Per-track motions for this instance, keyed by [CoilSwitchTrack]s:
  /// `motions: {.thumb: const .bouncySpring()}`. They win over the theme's
  /// [CoilThemeData.trackMotions] and the tokens; reduced motion still makes
  /// the thumb and squish instant.
  final Map<CoilSwitchTrack<Object>, Motion>? motions;

  /// Overrides for this switch's look, on top of the theme's
  /// [CoilSwitchStyle] and the defaults.
  final CoilSwitchStyle? style;

  /// A label for assistive technology when [label] is not plain text.
  final String? semanticLabel;

  @override
  State<CoilSwitch> createState() => _CoilSwitchState();
}

/// How far a drag may pull the thumb past either end, in travels.
const _overdrag = 0.15;

/// How far ahead a release is projected: the thumb decides by where it
/// would be this long after letting go (`x + v·t`), so a quick flick
/// toggles even from the near side and a slow drag decides by position.
const _projection = 0.1;

/// Whether a drag released at [position] (0 off, 1 on) moving at [velocity]
/// (travels per second) ends on.
bool _decidesOn(double position, double velocity) =>
    position + velocity * _projection > .5;

class _CoilSwitchState extends State<CoilSwitch>
    with SingleTickerProviderStateMixin {
  /// The motion tokens, read where each animation starts so runtime
  /// theme changes apply to the next one.
  CoilMotion get _motion =>
      CoilTheme.motionOf(context, override: widget.motion);

  late final _controller = TrackController(
    vsync: this,
    debugLabel: 'CoilSwitch',
  );

  final _thumb = CoilSwitchTrack.thumb;
  final _squish = CoilSwitchTrack.squish;
  final _tint = CoilSwitchTrack.tint;

  /// The motion for [track], per doc/api_guide.md §6.
  Motion _motionFor(CoilSwitchTrack<Object> track, Motion token) =>
      CoilTheme.trackMotionOf(
        context,
        track,
        instance: widget.motions,
        token: token,
        spatial:
            track != CoilSwitchTrack.tint && track != CoilSwitchTrack.label,
      );

  Motion get _thumbMotion => _motionFor(_thumb, _motion.standard);
  Motion get _squishMotion => _motionFor(_squish, _motion.quick);
  Motion get _tintMotion => _motionFor(_tint, _motion.fade);
  Motion get _hoverMotion => _motionFor(CoilSwitchTrack.hover, _motion.quick);
  Motion get _labelMotion => _motionFor(CoilSwitchTrack.label, _motion.fade);

  WidgetStatesController? _ownStates;
  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  bool _dragging = false;

  /// Whether the last drag decided the value, so a tap the same gesture
  /// may still report does not toggle it back.
  bool _dragDecided = false;

  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    final on = widget.value ? 1.0 : 0.0;
    _controller.set([
      _thumb.value(on),
      _tint.value(on),
      _squish.value(_states.value.contains(WidgetState.pressed) ? 1 : 0),
    ]);
    _states.addListener(_onStates);
  }

  @override
  void didUpdateWidget(CoilSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      (oldWidget.statesController ?? _ownStates)?.removeListener(_onStates);
      _states.addListener(_onStates);
    }
    if (oldWidget.value != widget.value && !_dragging) _settle();
    // A press held while the switch is disabled lets go.
    if (oldWidget.onChanged != null && !_enabled) _onStates();
  }

  @override
  void dispose() {
    _states.removeListener(_onStates);
    _ownStates?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStates() => _press(_dragging || _pressedNow);

  late double _squishTarget = _controller.value(_squish);

  /// Animates the squish only when its target changes: state listeners
  /// also fire for hover and focus, and during the first build.
  void _press(bool down) {
    final target = down ? 1.0 : 0.0;
    if (target == _squishTarget) return;
    _squishTarget = target;
    _controller.animate([
      _squish([.to(target, motion: _squishMotion)]),
    ]);
  }

  /// Springs every track to the current value, from wherever and however
  /// fast it is moving.
  void _settle() {
    final to = widget.value ? 1.0 : 0.0;
    _controller.animate([
      _thumb([
        .to(to, motion: _thumbMotion),
      ]),
      _tint([.to(to, motion: _tintMotion)]),
      _squish([
        .to(_squishTarget = _pressedNow ? 1 : 0, motion: _squishMotion),
      ]),
    ]);
  }

  bool get _pressedNow =>
      _enabled &&
      (_states.value.contains(WidgetState.pressed) || _containerPressed);

  /// A field row around the switch is pressed (`CoilFieldRow`).
  bool _containerPressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pressed = CoilFieldScope.maybeOf(context)?.containerPressed ?? false;
    if (pressed == _containerPressed) return;
    _containerPressed = pressed;
    _onStates();
  }

  void _toggle() {
    if (_dragDecided) {
      _dragDecided = false;
      return;
    }
    _report(!widget.value);
  }

  void _report(bool value) {
    unawaited(CoilHaptics.play(context, CoilHapticEvent.toggle));
    widget.onChanged?.call(value);
  }

  void _dragStart(DragStartDetails _) {
    if (!_enabled) return;
    _dragging = true;
    _dragDecided = false;
    _press(true);
  }

  void _dragUpdate(DragUpdateDetails details, double travel) {
    if (!_dragging) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dx = rtl ? -details.delta.dx : details.delta.dx;
    final thumb = (_controller.value(_thumb) + dx / travel).clamp(
      -_overdrag,
      1 + _overdrag,
    );
    _controller.set([_thumb.value(thumb)]);
  }

  void _dragEnd(DragEndDetails details, double travel) {
    if (!_dragging) return;
    _dragging = false;
    // Flutter's drag velocity knows when the finger stopped before lifting;
    // in travels per second, like the thumb track.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final speed = details.velocity.pixelsPerSecond.dx / travel * (rtl ? -1 : 1);
    final on = _decidesOn(_controller.value(_thumb), speed);
    if (on != widget.value) {
      _dragDecided = true;
      _report(on);
    }
    // Spring to the decided side right away from the release velocity. If
    // the parent accepts the change, its rebuild keeps this target.
    final to = on ? 1.0 : 0.0;
    _controller.animate([
      _thumb(
        [.to(to, motion: _thumbMotion)],
        withVelocity: speed,
      ),
      _tint([.to(to, motion: _tintMotion)]),
      _squish([.to(_squishTarget = 0, motion: _squishMotion)]),
    ]);
  }

  void _dragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _settle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilSwitchStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilSwitchStyle>(context)).merge(widget.style);
    final m = sizes.switchMetrics;
    final travel = m.trackWidth - m.thumbSize - m.thumbInset * 2;
    final sharp = theme.shape == CoilShape.sharp;
    final label = widget.label;
    final field = CoilFieldScope.maybeOf(context);

    final pressable = CoilInteraction(
      onPressed: _enabled ? _toggle : null,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      statesController: _states,
      // A framing container is the target.
      minHitTarget: (field?.framed ?? false) ? 0 : sizes.minHitTarget,
      builder: (context, states, _) {
        final hovered =
            states.contains(WidgetState.hovered) ||
            (_enabled && (field?.containerHovered ?? false));
        final labelColor = style.label!.resolve({
          if (widget.value) WidgetState.selected,
        })!;
        return Opacity(
          opacity: _enabled ? 1 : sizes.disabledOpacity,
          child: TrackBuilder(
            initialValues: [
              CoilSwitchTrack.hover.value(hovered ? 1.0 : 0.0),
              CoilSwitchTrack.label.value(labelColor),
            ],
            animations: [
              CoilSwitchTrack.hover([
                .to(hovered ? 1 : 0, motion: _hoverMotion),
              ]),
              CoilSwitchTrack.label([
                .to(labelColor, motion: _labelMotion),
              ]),
            ],
            builder: (context, value, _) {
              final track = CoilFocusRing(
                visible:
                    states.contains(WidgetState.focused) &&
                    !(field?.framed ?? false),
                borderRadius: BorderRadius.circular(style.radius!),
                offset: 2,
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => _SwitchTrack(
                    metrics: m,
                    style: style,
                    sharp: sharp,
                    thumb: _controller.value(_thumb),
                    squish: _controller.value(_squish).clamp(0, 1),
                    tint: _controller.value(_tint).clamp(0, 1),
                    hover: value(CoilSwitchTrack.hover).clamp(0, 1),
                  ),
                ),
              );
              if (label == null) return track;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: sizes.controlPaddingX,
                  vertical: sizes.switchRowPaddingY,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: sizes.gap,
                  children: [
                    track,
                    DefaultTextStyle(
                      style: style.textStyle!.copyWith(
                        color: value(CoilSwitchTrack.label),
                      ),
                      child: label,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    return CoilFieldControl(
      onLabelTap: _enabled ? () => _report(!widget.value) : null,
      tapArea: CoilFieldTapArea.row,
      child: MotorInspectionScope(
        group: 'CoilSwitch',
        child: Semantics(
          container: true,
          toggled: widget.value,
          enabled: _enabled,
          label: widget.semanticLabel,
          child: GestureDetector(
            // Dragging is a pointer nicety; it is not a scroll action.
            excludeFromSemantics: true,
            onHorizontalDragStart: _dragStart,
            onHorizontalDragUpdate: (details) => _dragUpdate(details, travel),
            onHorizontalDragEnd: (details) => _dragEnd(details, travel),
            onHorizontalDragCancel: _dragCancel,
            child: pressable,
          ),
        ),
      ),
    );
  }
}

/// Paints the track and thumb from the switch's track values.
class _SwitchTrack extends StatelessWidget {
  const _SwitchTrack({
    required this.metrics,
    required this.style,
    required this.sharp,
    required this.thumb,
    required this.squish,
    required this.tint,
    required this.hover,
  });

  final CoilSwitchMetrics metrics;
  final CoilSwitchStyle style;
  final bool sharp;

  /// 0 off, 1 on; a drag may pull it slightly past either end.
  final double thumb;
  final double squish;
  final double tint;
  final double hover;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final inset = m.thumbInset;
    final travel = m.trackWidth - m.thumbSize - inset * 2;
    final at = thumb.clamp(0.0, 1.0);

    // Hover makes the thumb a pill; a press widens and flattens it more.
    final hoverExtend = m.pillExtend * hover;
    final extend = hoverExtend + (m.pressExtend - hoverExtend) * squish;
    final width = m.thumbSize + extend;
    final height = m.thumbSize - m.pressShrink * squish;
    final start = inset + at * (travel - extend);
    final top = (m.trackHeight - height) / 2;

    final track = style.track!;
    final off = Color.lerp(
      track.resolve({}),
      track.resolve({WidgetState.hovered}),
      hover,
    )!;
    final on = Color.lerp(
      track.resolve({WidgetState.selected}),
      track.resolve({WidgetState.selected, WidgetState.hovered}),
      hover,
    )!;

    // Pulled past an end, the switch stretches toward it and narrows to
    // keep its area: about 4% at most, a quieter take on Motor's toggle.
    final over = (thumb - at).clamp(-_overdrag, _overdrag);
    final stretch = 1 + over.abs() * 0.25;
    final radius = BorderRadius.circular(style.radius!);

    return Transform(
      alignment: over > 0
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      transform: Matrix4.diagonal3Values(stretch, 1 / stretch, 1),
      child: Container(
        width: m.trackWidth,
        height: m.trackHeight,
        decoration: ShapeDecoration(
          color: Color.lerp(off, on, tint),
          shape: RoundedSuperellipseBorder(borderRadius: radius),
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              start: start,
              top: top,
              width: width,
              height: height,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: style.thumb,
                  shadows: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      spreadRadius: -1,
                    ),
                  ],
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(sharp ? 0 : height / 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
