// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
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
}

/// A switch with an optional label (`registry/radix/switch.tsx`).
///
/// Built like Motor's toggle example: one [TrackController] animates three
/// tracks, each 0..1:
///
/// * **thumb**: where the thumb is. Dragging [TrackController.set]s it and
///   may pull it a little past either end, which stretches the switch;
///   letting go decides by the projected position `x + v·0.1 s` and animates
///   from the release velocity, so a flick finishes the way it was thrown.
/// * **squish**: the press. The thumb widens and flattens while pressed.
/// * **tint**: the track color, off to on, on its own spring.
///
/// The tracks carry no default motion: every `.to(...)` passes the theme's
/// current token (or [motion]), so runtime theme changes apply to the next
/// animation.
///
/// Hover (the thumb turning into a pill, the track darkening) is a plain
/// [SingleMotionBuilder]. Geometry and colors are Fluid Functionalism's.
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

  /// A label for assistive technology when [label] is not plain text.
  final String? semanticLabel;

  /// Whether a drag released at [position] (0 off .. 1 on) moving at
  /// [velocity] (travels per second) ends on: the projected position
  /// `position + velocity · 0.1 s` past the midpoint.
  @visibleForTesting
  static bool decideRelease(double position, double velocity) =>
      position + velocity * _projection > .5;

  @override
  State<CoilSwitch> createState() => _CoilSwitchState();
}

/// How far a drag may pull the thumb past either end, in travels.
const _overdrag = 0.15;

/// How far ahead a release is projected: the thumb decides by where it
/// would be this long after letting go (`x + v·t`), so a quick flick
/// toggles even from the near side and a slow drag decides by position.
const _projection = 0.1;

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
        spatial: track != CoilSwitchTrack.tint,
      );

  Motion get _thumbMotion => _motionFor(_thumb, _motion.standard);
  Motion get _squishMotion => _motionFor(_squish, _motion.quick);
  Motion get _tintMotion => _motionFor(_tint, _motion.fade);

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
  }

  @override
  void dispose() {
    _states.removeListener(_onStates);
    _ownStates?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStates() =>
      _press(_dragging || _states.value.contains(WidgetState.pressed));

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

  bool get _pressedNow => _states.value.contains(WidgetState.pressed);

  void _toggle() {
    if (_dragDecided) {
      _dragDecided = false;
      return;
    }
    widget.onChanged?.call(!widget.value);
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
    final on = CoilSwitch.decideRelease(_controller.value(_thumb), speed);
    if (on != widget.value) {
      _dragDecided = true;
      widget.onChanged?.call(on);
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
    final colors = theme.colors;
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final m = sizes.switchMetrics;
    final travel = m.trackWidth - m.thumbSize - m.thumbInset * 2;
    final sharp = theme.shape == CoilShape.sharp;
    final label = widget.label;

    final pressable = CoilInteraction(
      onPressed: _enabled ? _toggle : null,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      statesController: _states,
      builder: (context, states, _) {
        final track = CoilFocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: BorderRadius.circular(sharp ? 0 : m.trackHeight / 2),
          offset: 2,
          child: SingleMotionBuilder(
            value: states.contains(WidgetState.hovered) ? 1 : 0,
            motion: _motion.quick,
            debugLabel: 'Hover',
            builder: (context, hover, _) => ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _SwitchTrack(
                metrics: m,
                colors: colors,
                sharp: sharp,
                thumb: _controller.value(_thumb),
                squish: _controller.value(_squish).clamp(0, 1),
                tint: _controller.value(_tint).clamp(0, 1),
                hover: hover.clamp(0, 1),
              ),
            ),
          ),
        );

        Widget content = track;
        if (label != null) {
          content = Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sizes.controlPaddingX,
              vertical: sizes.switchRowPaddingY,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: sizes.gap,
              children: [
                track,
                MotionBuilder<Color>(
                  value: widget.value
                      ? colors.foreground
                      : colors.mutedForeground,
                  motion: _motion.fade,
                  converter: .colorRgb,
                  debugLabel: 'Label color',
                  builder: (context, color, child) => DefaultTextStyle(
                    style: theme.typography.style(sizes.body, color: color),
                    child: child!,
                  ),
                  child: label,
                ),
              ],
            ),
          );
        }
        return Opacity(
          opacity: _enabled ? 1 : 0.5,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: sizes.minHitTarget,
              minWidth: sizes.minHitTarget,
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        );
      },
    );

    return MotorInspectionScope(
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
    );
  }
}

/// Paints the track and thumb from the switch's track values.
class _SwitchTrack extends StatelessWidget {
  const _SwitchTrack({
    required this.metrics,
    required this.colors,
    required this.sharp,
    required this.thumb,
    required this.squish,
    required this.tint,
    required this.hover,
  });

  final CoilSwitchMetrics metrics;
  final CoilColors colors;
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

    final off = Color.lerp(
      colors.accent,
      CoilColorMix.oklab(colors.accent, colors.overlay, 0.9),
      hover,
    )!;
    final on = Color.lerp(
      colors.brand,
      CoilColorMix.oklab(colors.brand, const Color(0xFF000000), 0.92),
      hover,
    )!;

    // Pulled past an end, the switch stretches toward it and narrows to
    // keep its area: about 4% at most, a quieter take on Motor's toggle.
    final over = (thumb - at).clamp(-_overdrag, _overdrag);
    final stretch = 1 + over.abs() * 0.25;
    final radius = BorderRadius.circular(sharp ? 0 : m.trackHeight / 2);

    return Transform(
      alignment: over > 0
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      transform: Matrix4.diagonal3Values(stretch, 1 / stretch, 1),
      child: Container(
        width: m.trackWidth,
        height: m.trackHeight,
        decoration: BoxDecoration(
          color: Color.lerp(off, on, tint),
          borderRadius: radius,
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              start: start,
              top: top,
              width: width,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(
                    sharp ? 0 : m.thumbSize,
                  ),
                  // Tailwind `shadow-sm`.
                  boxShadow: const [
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
