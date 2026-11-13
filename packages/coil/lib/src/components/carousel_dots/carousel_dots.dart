// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/carousel_dots/carousel_dots_labels.dart';
import 'package:coil/src/components/carousel_dots/carousel_dots_style.dart';
import 'package:coil/src/components/carousel_dots/carousel_dots_track.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// A row of dots, one per slide, where the current dot is a wider pill.
///
/// The dots are one adjustable control on every tier: one tab stop, arrow
/// keys and Home/End step through slides, and screen readers hear the
/// position ("Slide 2 of 5") with increase and decrease actions.
///
/// * **Pointer:** each dot has its own click target, and one hover
///   highlight glides between them.
/// * **Touch:** the whole row is one touch strip. Tap or drag along it to
///   scrub.
///
/// The dots never advance on their own. A carousel that autoplays drives
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
    this.labels = const CoilCarouselDotsLabels(),
    this.size,
    this.motion,
    this.motions,
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

  /// The words screen readers hear. Pass translations for other locales.
  final CoilCarouselDotsLabels labels;

  /// Pins the dots to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for these
  /// dots.
  final CoilMotion? motion;

  /// Per-track motions for these dots, keyed by [CoilCarouselDotsTrack]s.
  /// They win over the theme's [CoilThemeData.trackMotions] and the tokens.
  final Map<CoilCarouselDotsTrack<Object>, Motion>? motions;

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
  final _row = GlobalKey(debugLabel: 'CoilCarouselDots.row');
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

  /// Selects the dot under a finger anywhere in the touch strip: hit-tests
  /// the row of dots at the finger's horizontal position, through the
  /// row's middle.
  void _scrub(Offset global) {
    final row = _row.currentContext?.findRenderObject();
    if (row is! RenderBox || !row.hasSize) return;
    final local = row.globalToLocal(global);
    final result = BoxHitTestResult();
    row.hitTest(result, position: Offset(local.dx, row.size.height / 2));
    for (final entry in result.path) {
      if (entry.target case RenderMetaData(metaData: final int index)) {
        _select(index);
        return;
      }
    }
  }

  Motion _motionFor(CoilCarouselDotsTrack<Object> track, Motion token) =>
      CoilTheme.trackMotionOf(
        context,
        track,
        instance: widget.motions,
        token: token,
      );

  @override
  void dispose() {
    _states.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    final style = CoilCarouselDotsStyle.fallback(theme, metrics)
        .merge(CoilTheme.styleOf<CoilCarouselDotsStyle>(context))
        .merge(widget.style);
    final pill = _motionFor(CoilCarouselDotsTrack.pill, tokens.standard);
    final enabled = _enabled;
    final touch = metrics.tier == CoilTier.touch;

    final dots = MotorInspectionScope(
      group: 'CoilCarouselDots',
      child: CoilHoverRegion(
        axis: CoilHoverAxis.x,
        child: CoilHoverHighlight(
          color: style.highlight,
          radius: style.radius,
          motion: widget.motion,
          glideMotion: _motionFor(
            CoilCarouselDotsTrack.highlight,
            tokens.quick,
          ),
          child: Row(
            key: _row,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.count; i++)
                CoilHoverItem(
                  index: i,
                  enabled: enabled,
                  // Tags the dot for the touch strip's hit test.
                  child: MetaData(
                    metaData: i,
                    behavior: HitTestBehavior.opaque,
                    child: _DotTarget(
                      // On touch the strip takes every tap.
                      onPressed: enabled && !touch ? () => _select(i) : null,
                      child: _Dot(
                        current: i == widget.value,
                        progress: widget.progress ?? 1,
                        style: style,
                        motion: pill,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final ring = ListenableBuilder(
      listenable: _states,
      child: dots,
      builder: (context, dots) => CoilFocusRing(
        visible: _states.value.contains(WidgetState.focused),
        borderRadius: BorderRadius.circular(style.radius!),
        offset: style.ringOffset!,
        child: dots!,
      ),
    );

    // As tall as the tier's minimum hit target, as wide as the dots.
    Widget strip = SizedBox(
      height: math.max(style.targetSize!, metrics.minHitTarget),
      child: Center(widthFactor: 1, child: ring),
    );
    if (touch && enabled) {
      // The scrub needs the finger's position and a horizontal drag, which
      // the interaction primitives don't report.
      strip = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _scrub(details.globalPosition),
        onHorizontalDragStart: (details) => _scrub(details.globalPosition),
        onHorizontalDragUpdate: (details) => _scrub(details.globalPosition),
        child: strip,
      );
    }

    final labels = widget.labels;
    String position(int index) => labels.position(index + 1, widget.count);

    return Semantics(
      container: true,
      slider: true,
      enabled: enabled,
      label: labels.slides,
      value: position(widget.value),
      increasedValue: widget.value < widget.count - 1
          ? position(widget.value + 1)
          : null,
      decreasedValue: widget.value > 0 ? position(widget.value - 1) : null,
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
          child: ExcludeSemantics(
            child: Opacity(
              opacity: enabled ? 1 : theme.disabledOpacity,
              child: strip,
            ),
          ),
        ),
      ),
    );
  }
}

/// One dot's own click target on the pointer tier. The dots share one
/// focus node, so this is a [CoilInteractionDetector] rather than a
/// focusable [CoilInteraction].
class _DotTarget extends StatefulWidget {
  const _DotTarget({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_DotTarget> createState() => _DotTargetState();
}

class _DotTargetState extends State<_DotTarget> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return CoilInteractionDetector(
      states: _states,
      enabled: enabled,
      trackPress: enabled,
      onTap: widget.onPressed,
      excludeFromSemantics: true,
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: widget.child,
    );
  }
}

/// One dot in its round target: a resting dot, or the current pill with its
/// fill. The pill's width springs on [motion].
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
  final Motion motion;

  @override
  Widget build(BuildContext context) {
    final dot = style.dotSize!;
    final radius = BorderRadius.circular(math.min(style.radius!, dot / 2));
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: EdgeInsets.all((style.targetSize! - dot) / 2),
      child: SingleMotionBuilder(
        value: current ? style.pillWidth! : dot,
        motion: motion,
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
