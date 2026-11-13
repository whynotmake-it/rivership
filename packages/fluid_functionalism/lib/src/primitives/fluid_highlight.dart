import 'package:fluid_functionalism/src/primitives/fluid_motion_layer.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A box that glides between the targets of a [FluidMotionLayer] and fades
/// in and out: the moving fill behind a hovered row, a selected tab's pill,
/// a focus ring that travels between items.
///
/// The port of `components/ui/fluid-hover-highlight.tsx`, as a layer
/// painter. It animates a *delta* relative to its target's rect, which the
/// layer reads at paint time; so when the target resizes, reflows or
/// scrolls, the highlight stays on it in the same frame, and when the
/// target changes the delta glides to zero on the given motion (a spring
/// keeps its velocity when retargeted mid-glide).
///
/// Drive it with [update] from the owning widget's build:
///
/// * A target after none, or a new `session`, starts a fresh session: it
///   appears at `from` (default: the target) and fades in rather than
///   sliding over from wherever it was last.
/// * A new target while visible: glides there on `motion`.
/// * A null target: fades out on `exitMotion`, gliding to `exitTo` if given.
/// * `opacity` changes fade on `fade`.
class FluidHighlightPainter extends FluidLayerPainter {
  /// Creates a highlight painter ticking on [vsync].
  FluidHighlightPainter({required TickerProvider vsync, String? debugLabel})
    : _delta = MotionController<Rect>(
        motion: const Motion.instant(),
        vsync: vsync,
        converter: MotionConverter.rect,
        initialValue: Rect.zero,
        velocityTracking: const VelocityTracking.off(),
        debugLabel: '${debugLabel ?? 'FluidHighlight'}.delta',
      ),
      _opacity = SingleMotionController(
        motion: const Motion.instant(),
        vsync: vsync,
        velocityTracking: const VelocityTracking.off(),
        debugLabel: '${debugLabel ?? 'FluidHighlight'}.opacity',
      ) {
    _delta.addListener(notifyListeners);
    _opacity.addListener(notifyListeners);
  }

  final MotionController<Rect> _delta;
  final SingleMotionController _opacity;

  bool _initialized = false;
  bool _visible = false;
  int _session = 0;
  double? _opacityTarget;

  /// The target the delta is relative to (the exit target while leaving),
  /// or null when frozen at [_lastPainted].
  int? _anchor;

  /// Geometry work deferred to paint, where target rects are current.
  _Pending? _pending;
  Rect? _lastPainted;

  /// The rect painted in the last frame (before any inflate), in layer
  /// coordinates.
  @visibleForTesting
  Rect? get debugLastPaintedRect => _lastPainted;

  Decoration? _decoration;
  BoxPainter? _boxPainter;
  double _inflate = 0;

  /// Points the highlight at [target] (a target index of the layer), or
  /// hides it when null. Call on every build; unchanged values are no-ops.
  void update({
    required int? target,
    required Motion motion,
    required Motion exitMotion,
    required Motion exitTravelMotion,
    required Motion fade,
    required Decoration decoration,
    int session = 0,
    int? from,
    int? exitTo,
    bool fadeIn = true,
    double opacity = 1,
    double inflate = 0,
  }) {
    if (decoration != _decoration) {
      _decoration = decoration;
      _boxPainter?.dispose();
      _boxPainter = null;
    }
    _inflate = inflate;

    if (!_initialized) {
      _initialized = true;
      _session = session;
      _visible = target != null;
      _anchor = target;
      _opacityTarget = _visible ? opacity : 0;
      _opacity.value = _opacityTarget!;
      notifyListeners();
      return;
    }

    if (target != null) {
      final fresh = !_visible || session != _session;
      if (fresh) {
        _pending = _Pending.fresh(from: from, motion: motion);
        if (fadeIn) {
          _opacity.value = 0;
          _opacityTarget = 0;
        }
      } else if (target != _anchor) {
        _pending = _Pending.retarget(motion);
      }
      _anchor = target;
      _session = session;
      _visible = true;
      _fadeTo(opacity, fade);
    } else if (_visible) {
      _visible = false;
      _fadeTo(0, exitMotion);
      if (exitTo != null) {
        _anchor = exitTo;
        _pending = _Pending.retarget(exitTravelMotion);
      } else {
        _anchor = null; // Frozen where it was while it fades.
      }
    }
    notifyListeners();
  }

  void _fadeTo(double target, Motion motion) {
    if (_opacityTarget == target) return;
    _opacityTarget = target;
    _opacity
      ..motion = motion
      ..animateTo(target);
  }

  static Rect _diff(Rect a, Rect b) => Rect.fromLTRB(
    a.left - b.left,
    a.top - b.top,
    a.right - b.right,
    a.bottom - b.bottom,
  );

  static Rect _add(Rect a, Rect d) => Rect.fromLTRB(
    a.left + d.left,
    a.top + d.top,
    a.right + d.right,
    a.bottom + d.bottom,
  );

  @override
  void paint(Canvas canvas, Offset offset, FluidLayerGeometry geometry) {
    Rect? rect;
    final anchor = _anchor;
    final target = anchor == null ? null : geometry.rectOf(anchor);
    if (target != null) {
      switch (_pending) {
        case _Pending(fresh: true, :final from, :final motion):
          final start = from == null ? null : geometry.rectOf(from);
          final delta = start == null ? Rect.zero : _diff(start, target);
          _delta.value = delta;
          if (delta != Rect.zero) {
            _delta
              ..motion = motion
              ..animateTo(Rect.zero);
          }
        case _Pending(fresh: false, :final motion):
          final last = _lastPainted;
          final delta = last == null ? Rect.zero : _diff(last, target);
          _delta
            ..motion = motion
            ..animateTo(Rect.zero, from: delta);
        case null:
          break;
      }
      _pending = null;
      rect = _add(target, _delta.value);
    } else {
      // Frozen while fading out; a target that disappeared paints nothing.
      rect = anchor == null ? _lastPainted : null;
    }
    _lastPainted = rect;

    final opacity = _opacity.value.clamp(0.0, 1.0);
    final decoration = _decoration;
    if (rect == null || opacity <= 0 || decoration == null) return;
    final painted = rect.inflate(_inflate).shift(offset);
    final painter = _boxPainter ??= decoration.createBoxPainter(
      notifyListeners,
    );
    if (opacity < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    }
    painter.paint(
      canvas,
      painted.topLeft,
      ImageConfiguration(size: painted.size, textDirection: TextDirection.ltr),
    );
    if (opacity < 1) canvas.restore();
  }

  @override
  void dispose() {
    _delta.dispose();
    _opacity.dispose();
    _boxPainter?.dispose();
    super.dispose();
  }
}

class _Pending {
  const _Pending.fresh({required this.from, required this.motion})
    : fresh = true;
  const _Pending.retarget(this.motion) : fresh = false, from = null;

  final bool fresh;
  final int? from;
  final Motion motion;
}
