// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/carousel_dots/carousel_dots_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// A row of dots, one per slide, where the current dot is a wider pill.
///
/// The dots are one adjustable control on every tier: one tab stop, arrow
/// keys and Home/End step through slides, and screen readers hear
/// "Slide 2 of 5" with increase and decrease actions.
///
/// * **Pointer:** each dot sits in an 18 px round click target, and one
///   hover highlight glides between the targets.
/// * **Touch:** the whole row is one 44 px high strip. Tap or drag along it
///   to scrub; single dots get no 44 px boxes of their own.
///
/// The dots don't advance on their own. A carousel that autoplays drives
/// [value] and [progress] from its own clock, and stops that clock under
/// reduced motion (`MediaQuery.disableAnimationsOf`).
class CoilCarouselDots extends StatefulWidget {
  /// Creates carousel dots.
  const CoilCarouselDots({
    required this.count,
    required this.value,
    required this.onChanged,
    super.key,
    this.progress,
    this.semanticLabel = 'Slides',
    this.size,
    this.motion,
    this.style,
    this.focusNode,
    this.autofocus = false,
  }) : assert(count > 0, 'count must be positive'),
       assert(value >= 0 && value < count, 'value must be in 0..count-1');

  /// How many slides there are.
  final int count;

  /// The index of the current slide.
  ///
  /// An index, not a generic value: the dots stand for positions in a
  /// sequence, the way a `PageController` page does.
  final int value;

  /// Called with the index of the slide to show. Null disables the dots.
  final ValueChanged<int>? onChanged;

  /// How far the current slide has played, from 0 to 1. The current pill
  /// fills by this much. Null shows a solid pill.
  final double? progress;

  /// The name screen readers announce before the slide position.
  final String semanticLabel;

  /// Pins the dots to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for these
  /// dots.
  final CoilMotion? motion;

  /// Overrides for these dots' look, on top of the theme's
  /// [CoilCarouselDotsStyle] and the defaults.
  final CoilCarouselDotsStyle? style;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  @override
  State<CoilCarouselDots> createState() => _CoilCarouselDotsState();
}

class _CoilCarouselDotsState extends State<CoilCarouselDots> {
  final _states = WidgetStatesController();
  FocusNode? _ownFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'CoilCarouselDots'));

  bool get _enabled => widget.onChanged != null;

  late final Map<Type, Action<Intent>> _actions = {
    _StepIntent: CallbackAction<_StepIntent>(
      onInvoke: (intent) {
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final delta = intent.horizontal && rtl ? -intent.delta : intent.delta;
        _select(widget.value + delta);
        return null;
      },
    ),
    _JumpIntent: CallbackAction<_JumpIntent>(
      onInvoke: (intent) {
        _select(intent.toEnd ? widget.count - 1 : 0);
        return null;
      },
    ),
  };

  static const _shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-1),
    SingleActivator(LogicalKeyboardKey.arrowUp): _StepIntent(
      1,
      horizontal: false,
    ),
    SingleActivator(LogicalKeyboardKey.arrowDown): _StepIntent(
      -1,
      horizontal: false,
    ),
    SingleActivator(LogicalKeyboardKey.home): _JumpIntent(toEnd: false),
    SingleActivator(LogicalKeyboardKey.end): _JumpIntent(toEnd: true),
  };

  void _select(int index) {
    final clamped = index.clamp(0, widget.count - 1);
    if (clamped != widget.value) widget.onChanged?.call(clamped);
  }

  @override
  void dispose() {
    _states.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final override = widget.motion;
    if (override == null) return _build(context);
    // The hover highlight reads the theme's motion, so an instance override
    // goes in as a theme override.
    return CoilTheme.override(
      transform: (theme) => theme.copyWith(motion: override),
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final motion = CoilTheme.motionOf(context);
    final style = CoilCarouselDotsStyle.fallback(theme, metrics)
        .merge(CoilTheme.styleOf<CoilCarouselDotsStyle>(context))
        .merge(widget.style);
    final geometry = _Geometry(style, widget.count, widget.value);
    final enabled = _enabled;
    final touch = metrics.tier == CoilTier.touch;

    final dots = MotorInspectionScope(
      group: 'CoilCarouselDots',
      child: CoilHoverRegion(
        axis: CoilHoverAxis.x,
        highlightColor: style.highlight,
        highlightRadius: style.radius,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.count; i++)
              CoilHoverItem(
                index: i,
                enabled: enabled,
                child: _Dot(
                  current: i == widget.value,
                  progress: widget.progress ?? 1,
                  style: style,
                  motion: motion,
                ),
              ),
          ],
        ),
      ),
    );

    final ring = ListenableBuilder(
      listenable: _states,
      child: dots,
      builder: (context, dots) => CoilFocusRing(
        visible: _states.value.contains(WidgetState.focused),
        borderRadius: BorderRadius.circular(style.radius!),
        offset: 2,
        child: dots!,
      ),
    );

    void scrub(Offset local) {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final x = rtl ? geometry.width - local.dx : local.dx;
      _select(geometry.indexAt(x));
    }

    // Touch: one strip at least 44 high. Pointer: the 18 px targets alone.
    final strip = SizedBox(
      width: geometry.width,
      height: math.max(style.targetSize!, metrics.minHitTarget),
      child: Center(child: ring),
    );

    return Semantics(
      container: true,
      slider: true,
      enabled: enabled,
      label: widget.semanticLabel,
      value: _position(widget.value),
      increasedValue: widget.value < widget.count - 1
          ? _position(widget.value + 1)
          : null,
      decreasedValue: widget.value > 0 ? _position(widget.value - 1) : null,
      onIncrease: enabled && widget.value < widget.count - 1
          ? () => _select(widget.value + 1)
          : null,
      onDecrease: enabled && widget.value > 0
          ? () => _select(widget.value - 1)
          : null,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        shortcuts: _shortcuts,
        actions: _actions,
        child: CoilInteractionDetector(
          states: _states,
          enabled: enabled,
          focusNode: _focusNode,
          trackPress: false,
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: ExcludeSemantics(
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: enabled
                    ? (details) => scrub(details.localPosition)
                    : null,
                onHorizontalDragStart: enabled && touch
                    ? (details) => scrub(details.localPosition)
                    : null,
                onHorizontalDragUpdate: enabled && touch
                    ? (details) => scrub(details.localPosition)
                    : null,
                child: strip,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _position(int index) => 'Slide ${index + 1} of ${widget.count}';
}

/// Where the dots sit once the current pill has settled.
class _Geometry {
  _Geometry(this.style, this.count, this.current);

  final CoilCarouselDotsStyle style;
  final int count;
  final int current;

  double get _pad => style.targetSize! - style.dotSize!;

  double _widthOf(int index) =>
      (index == current ? style.pillWidth! : style.dotSize!) + _pad;

  double get width =>
      style.pillWidth! + style.dotSize! * (count - 1) + _pad * count;

  /// The dot whose target holds [x], measured from the start edge.
  int indexAt(double x) {
    var end = 0.0;
    for (var i = 0; i < count; i++) {
      end += _widthOf(i);
      if (x < end) return i;
    }
    return count - 1;
  }
}

/// One dot in its round target: a resting dot, or the current pill with its
/// fill. The pill's width springs on `standard`.
class _Dot extends StatelessWidget {
  const _Dot({
    required this.current,
    required this.progress,
    required this.style,
    required this.motion,
  });

  final bool current;
  final double progress;
  final CoilCarouselDotsStyle style;
  final CoilMotion motion;

  @override
  Widget build(BuildContext context) {
    final dot = style.dotSize!;
    final radius = BorderRadius.circular(math.min(style.radius!, dot / 2));
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: EdgeInsets.all((style.targetSize! - dot) / 2),
      child: SingleMotionBuilder(
        value: current ? style.pillWidth! : dot,
        motion: motion.standard,
        debugLabel: 'CoilCarouselDots.pill',
        builder: (context, width, _) {
          // The fill is a full-width pill slid in from the start edge, never
          // scaled, so its rounded end keeps its shape. At 0 a round dot
          // shows; at 1 it covers the pill.
          final hidden = (1 - progress.clamp(0.0, 1.0)) * (width - dot);
          return ClipRSuperellipse(
            borderRadius: radius,
            child: SizedBox(
              width: width,
              height: dot,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: style.track,
                  shape: RoundedSuperellipseBorder(borderRadius: radius),
                ),
                child: current
                    ? Transform.translate(
                        offset: Offset(rtl ? hidden : -hidden, 0),
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: style.fill,
                            shape: RoundedSuperellipseBorder(
                              borderRadius: radius,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StepIntent extends Intent {
  const _StepIntent(this.delta, {this.horizontal = true});

  final int delta;

  /// Left and Right follow the reading direction; Up and Down don't.
  final bool horizontal;
}

class _JumpIntent extends Intent {
  const _JumpIntent({required this.toEnd});

  final bool toEnd;
}
