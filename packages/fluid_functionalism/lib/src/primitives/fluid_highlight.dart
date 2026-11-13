import 'package:fluid_functionalism/fluid_functionalism.dart'
    show FluidColors, FluidHoverRegion;
import 'package:fluid_functionalism/src/foundation/fluid_motion.dart'
    show FluidMotionThemeData;
import 'package:fluid_functionalism/src/foundation/fluid_theme.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A box that glides to [rect] and fades in and out: the moving fill behind
/// a hovered row, a selected tab, or a focus ring that travels between
/// items.
///
/// The port of `components/ui/fluid-hover-highlight.tsx`. Place it in a
/// [Stack] that shares the coordinate space of [rect] (a
/// [FluidHoverRegion]'s builders do this for you).
///
/// * When [rect] goes from null to a value, or [session] changes, the
///   highlight starts a fresh session: it appears at [from] (default: [rect])
///   and fades in rather than sliding over from wherever it was last.
/// * While visible, a new [rect] glides there on [motion] (default: the
///   theme's [FluidMotionThemeData.fast]).
/// * When [rect] becomes null it fades out on [exitMotion], gliding to
///   [exitTo] if given.
/// * [opacity] changes fade on [FluidMotionThemeData.fade].
///
/// Motions are read from the theme on every change, so runtime theme
/// changes apply to the next move.
///
/// Reduced motion (`MediaQuery.disableAnimations`) keeps the fades and drops
/// the travel.
class FluidHighlight extends StatefulWidget {
  /// Creates a highlight.
  const FluidHighlight({
    required this.rect,
    super.key,
    this.session = 0,
    this.from,
    this.exitTo,
    this.fadeIn = true,
    this.opacity = 1,
    this.motion,
    this.exitMotion,
    this.exitTravelMotion,
    this.color,
    this.borderRadius,
    this.border,
  });

  /// Where the highlight sits, in the parent [Stack]'s coordinates. Null
  /// hides it.
  final Rect? rect;

  /// Changing this starts a fresh session (appear at [from], fade in).
  final int session;

  /// Where a fresh session appears before gliding to [rect].
  final Rect? from;

  /// Where a hiding highlight glides while it fades out.
  final Rect? exitTo;

  /// Whether a fresh session fades in (true) or starts opaque.
  final bool fadeIn;

  /// The opacity while visible. Changes fade.
  final double opacity;

  /// The positional motion while visible. Defaults to the theme's `fast`.
  final Motion? motion;

  /// The opacity motion when hiding. Defaults to the theme's `fastExit`.
  final Motion? exitMotion;

  /// The positional motion toward [exitTo] when hiding. Defaults to the
  /// theme's `moderate`.
  final Motion? exitTravelMotion;

  /// Fill color. Defaults to [FluidColors.hover] when no [border] is given.
  final Color? color;

  /// Corner radius. Defaults to the theme shape's item radius.
  final BorderRadius? borderRadius;

  /// An optional border (a travelling focus ring is a highlight with only a
  /// border).
  final BoxBorder? border;

  @override
  State<FluidHighlight> createState() => _FluidHighlightState();
}

class _FluidHighlightState extends State<FluidHighlight>
    with TickerProviderStateMixin {
  late final MotionController<Rect> _rect = MotionController<Rect>(
    // Every move sets its motion from the theme first.
    motion: const Motion.instant(),
    vsync: this,
    converter: MotionConverter.rect,
    initialValue: widget.rect ?? widget.from ?? Rect.zero,
    velocityTracking: const VelocityTracking.off(),
    debugLabel: 'FluidHighlight.rect',
  );

  late final SingleMotionController _opacity = SingleMotionController(
    motion: const Motion.instant(),
    vsync: this,
    initialValue: widget.rect == null ? 0 : widget.opacity,
    velocityTracking: const VelocityTracking.off(),
    debugLabel: 'FluidHighlight.opacity',
  );

  late bool _visible = widget.rect != null;
  Rect? _rectTarget;
  double? _opacityTarget;

  @override
  void initState() {
    super.initState();
    _rectTarget = widget.rect;
    _opacityTarget = _visible ? widget.opacity : 0;
  }

  @override
  void didUpdateWidget(FluidHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tokens = FluidTheme.motionOf(context);
    final rect = widget.rect;
    if (rect != null) {
      final fresh = !_visible || widget.session != oldWidget.session;
      if (fresh) {
        _rect.value = widget.from ?? rect;
        _rectTarget = _rect.value;
        if (widget.fadeIn) {
          _opacity.value = 0;
          _opacityTarget = 0;
        }
      }
      _moveTo(rect, widget.motion ?? tokens.fast);
      _fadeTo(widget.opacity, tokens.fade);
      _visible = true;
    } else if (_visible) {
      _visible = false;
      _fadeTo(0, widget.exitMotion ?? tokens.fastExit);
      if (widget.exitTo case final exitTo?) {
        _moveTo(exitTo, widget.exitTravelMotion ?? tokens.moderate);
      }
    }
  }

  void _moveTo(Rect target, Motion motion) {
    if (_rectTarget == target && _rect.motion == motion) return;
    _rectTarget = target;
    _rect.motion = motion;
    _rect.animateTo(target);
  }

  void _fadeTo(double target, Motion motion) {
    if (_opacityTarget == target) return;
    _opacityTarget = target;
    _opacity
      ..motion = motion
      ..animateTo(target);
  }

  @override
  void dispose() {
    _rect.dispose();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluidTheme.of(context);
    final decoration = BoxDecoration(
      color:
          widget.color ?? (widget.border == null ? theme.colors.hover : null),
      borderRadius:
          widget.borderRadius ?? BorderRadius.circular(theme.shape.item),
      border: widget.border,
    );
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_rect, _opacity]),
        builder: (context, _) {
          final opacity = _opacity.value.clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (opacity > 0)
                Positioned.fromRect(
                  rect: _rect.value,
                  child: Opacity(
                    opacity: opacity,
                    child: DecoratedBox(decoration: decoration),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
