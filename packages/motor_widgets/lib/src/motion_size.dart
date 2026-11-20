import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/converters.dart';
import 'package:motor_widgets/src/on_end.dart';
import 'package:motor_widgets/src/ticker_rate.dart';

/// Animated widget that springs its own size toward its child's size
/// whenever the child's size changes.
///
/// The Motor version of [AnimatedSize]. The size is driven by a Motor
/// controller from the render object, so when the child's size changes
/// again mid-flight, the size heads for the new one with the velocity it
/// already has instead of restarting.
///
/// The first layout takes the child's size at once. While the size is
/// smaller than the child, the child is aligned by [alignment] and clipped
/// by [clipBehavior].
///
/// ## Content springs, room snaps
///
/// Unlike [AnimatedSize], this tells *why* the child's size changed. When the
/// child's own content changes (a label gets longer, a message wraps to
/// another line), the size springs to the new one. When a change in the
/// incoming constraints changes the child's size (the window is resized and
/// rewraps or ellipsizes the child), the size snaps to the child's new size
/// at once and drops any spring in flight, so a window being dragged never
/// lags behind the cursor. A change in the constraints that leaves the
/// child's size alone (a sibling taking more room in a [Row]) keeps the
/// spring running.
///
/// A change of the ambient text scale snaps too.
class MotionSize extends StatefulWidget {
  /// Creates a [MotionSize].
  const MotionSize({
    required this.motion,
    this.child,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The widget below this widget in the tree.
  final Widget? child;

  /// The alignment of the child within the parent when the parent is not yet
  /// the same size as the child.
  final AlignmentGeometry alignment;

  /// The motion the size follows.
  final Motion motion;

  /// How to clip the child while it is larger than this widget.
  final Clip clipBehavior;

  /// {@macro motor_widgets.onEnd}
  final VoidCallback? onEnd;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  @override
  State<MotionSize> createState() => _MotionSizeState();
}

class _MotionSizeState extends State<MotionSize>
    with FixedTickerProviderStateMixin, WidgetTickerRateMixin {
  late final MotionController<Size> _controller;

  @override
  TickerRate? get widgetTickerRate => widget.tickerRate;

  @override
  void initState() {
    super.initState();
    _controller = MotionController<Size>(
      motion: widget.motion,
      vsync: this,
      converter: const NonNegativeSizeMotionConverter(),
      initialValue: Size.zero,
      // The size only ever animates toward the child's size; it never follows
      // values set from outside.
      velocityTracking: const VelocityTracking.off(),
      debugLabel: widget.debugLabel ?? 'MotionSize',
    );
    _listenForEnd();
  }

  ValueChanged<AnimationStatus>? _onEnd;

  void _listenForEnd() {
    if (_onEnd case final listener?) _controller.removeStatusListener(listener);
    _onEnd = onEndListener(widget.onEnd);
    if (_onEnd case final listener?) _controller.addStatusListener(listener);
  }

  @override
  void didUpdateWidget(MotionSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.motion != oldWidget.motion) _controller.motion = widget.motion;
    if (widget.tickerRate != oldWidget.tickerRate) updateTickerRate();
    if (widget.onEnd != oldWidget.onEnd) _listenForEnd();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MotionSizeLayout(
      controller: _controller,
      textScaler: MediaQuery.maybeTextScalerOf(context),
      alignment: widget.alignment,
      clipBehavior: widget.clipBehavior,
      child: widget.child,
    );
  }
}

class _MotionSizeLayout extends SingleChildRenderObjectWidget {
  const _MotionSizeLayout({
    required this.controller,
    required this.textScaler,
    required this.alignment,
    required this.clipBehavior,
    super.child,
  });

  final MotionController<Size> controller;
  final TextScaler? textScaler;
  final AlignmentGeometry alignment;
  final Clip clipBehavior;

  @override
  _RenderMotionSize createRenderObject(BuildContext context) {
    return _RenderMotionSize(
      controller: controller,
      textScaler: textScaler,
      alignment: alignment,
      clipBehavior: clipBehavior,
      textDirection: Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMotionSize renderObject,
  ) {
    renderObject
      ..controller = controller
      ..textScaler = textScaler
      ..alignment = alignment
      ..clipBehavior = clipBehavior
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// A render object that animates its size toward its child's size with a
/// Motor [MotionController].
///
/// Each layout compares the child's size with the size the controller is
/// heading for. When they differ, the controller is retargeted, which keeps
/// the velocity it has, unless the constraints changed since the last layout
/// (or the text scale did): then the size snaps to the child's.
class _RenderMotionSize extends RenderAligningShiftedBox {
  /// Creates a [_RenderMotionSize] driven by [controller].
  _RenderMotionSize({
    required MotionController<Size> controller,
    super.alignment,
    super.textDirection,
    TextScaler? textScaler,
    Clip clipBehavior = Clip.hardEdge,
  }) : _controller = controller,
       _textScaler = textScaler,
       _clipBehavior = clipBehavior;

  /// The ambient text scale. A change is not a content change, so the next
  /// layout snaps.
  TextScaler? get textScaler => _textScaler;
  TextScaler? _textScaler;
  set textScaler(TextScaler? value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _snapNext = true;
    markNeedsLayout();
  }

  /// The constraints of the last layout. A different set means the parent,
  /// not the content, may have changed the child's size.
  BoxConstraints? _lastConstraints;

  bool _snapNext = false;

  /// The controller that animates this render object's size.
  MotionController<Size> get controller => _controller;
  MotionController<Size> _controller;
  set controller(MotionController<Size> value) {
    if (value == _controller) return;
    if (attached) _controller.removeListener(_onControllerChanged);
    _controller = value;
    _target = null;
    _following = false;
    if (attached) _controller.addListener(_onControllerChanged);
    markNeedsLayout();
  }

  /// How to clip the child while it overflows this render object.
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    if (value == _clipBehavior) return;
    _clipBehavior = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// The size the controller is heading for, or null before the first
  /// layout with a child.
  Size? _target;

  /// Whether the size follows [controller], which is true from the first
  /// change of the child's size on.
  bool _following = false;

  void _onControllerChanged() => markNeedsLayout();

  bool _hasVisualOverflow = false;
  final _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void detach() {
    _controller.removeListener(_onControllerChanged);
    super.detach();
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    _hasVisualOverflow = false;
    final constraints = this.constraints;
    final child = this.child;
    final roomChanged = _lastConstraints != constraints;
    final reset = _snapNext;
    _lastConstraints = constraints;
    _snapNext = false;
    if (child == null || constraints.isTight) {
      // Nothing to animate toward: settle on the smallest size, as
      // AnimatedSize does.
      // A stop changes no value, so it doesn't notify mid-layout.
      _controller.stop(canceled: true);
      _target = null;
      _following = false;
      size = constraints.smallest;
      if (child != null) {
        child.layout(constraints);
        // The child fills the size: put it at the origin instead of where it
        // was aligned mid-flight.
        (child.parentData! as BoxParentData).offset = Offset.zero;
      }
      return;
    }

    child.layout(constraints, parentUsesSize: true);
    final childSize = child.size;
    final target = _target;
    if (target == null || reset || (roomChanged && childSize != target)) {
      // The first size, a reset, or a change in the room that changed the
      // child's size (a window resize that rewraps or ellipsizes it): take
      // the child's size at once and drop any spring in flight. A change in
      // the room that leaves the child's size alone (a sibling taking more
      // room in a Row) falls through and keeps the spring. A stop changes
      // no value, so it doesn't notify mid-layout.
      if (_following || _controller.isAnimating) {
        _controller.stop(canceled: true);
      }
      _following = false;
      _target = childSize;
      size = constraints.constrain(childSize);
    } else {
      if (childSize != target) {
        _target = childSize;
        // A controller that hasn't animated for this child yet starts from
        // the size it showed, the previous target.
        _controller.animateTo(childSize, from: _following ? null : target);
        _following = true;
      }
      size = constraints.constrain(_following ? _controller.value : target);
    }
    alignChild();

    if (size.width < childSize.width || size.height < childSize.height) {
      _hasVisualOverflow = true;
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null || constraints.isTight) return constraints.smallest;
    final childSize = child.getDryLayout(constraints);
    // At rest on the child's size, the size is the child's; otherwise it is
    // wherever the animation is.
    if (!_following ||
        _lastConstraints != constraints ||
        (!_controller.isAnimating && childSize == _target)) {
      return constraints.constrain(childSize);
    }
    return constraints.constrain(_controller.value);
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    final result = child.getDryBaseline(constraints, baseline);
    if (result == null) return null;
    if (constraints.isTight) return result;
    // Offset by the alignment within the current size, as alignChild does.
    final childSize = child.getDryLayout(constraints);
    final offset = resolvedAlignment.alongOffset(
      (getDryLayout(constraints) - childSize) as Offset,
    );
    return result + offset.dy;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && _hasVisualOverflow && clipBehavior != Clip.none) {
      final rect = Offset.zero & size;
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        rect,
        super.paint,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      super.paint(context, offset);
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    switch (clipBehavior) {
      case Clip.none:
        return null;
      case Clip.hardEdge:
      case Clip.antiAlias:
      case Clip.antiAliasWithSaveLayer:
        return _hasVisualOverflow ? Offset.zero & size : null;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Size?>('target', _target))
      ..add(EnumProperty<Clip>('clipBehavior', clipBehavior));
  }
}
