import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/converters.dart';
import 'package:motor_widgets/src/on_end.dart';
import 'package:motor_widgets/src/ticker_rate.dart';

/// The widget behind `MotionSize`, with an extra way for a parent to watch
/// the size grow.
///
/// Internal: [widthGrowth] is how `MotionSizeSwitcher` fades new content in
/// while the size is still too small to show it, and is not part of the
/// public API. See `MotionSize` for how the size follows its child.
class RawMotionSize extends StatefulWidget {
  /// Creates a [RawMotionSize].
  const RawMotionSize({
    required this.motion,
    this.child,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    this.widthGrowth,
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

  /// Receives how far the size has come while it grows in width: 0 when a
  /// growth starts to 1 when it has arrived, eased (squared) so it stays low
  /// early. It is 1 at rest, while shrinking, after a snap, and when only the
  /// height grows.
  ///
  /// Never set from layout, which can't notify.
  final ValueNotifier<double>? widthGrowth;

  @override
  State<RawMotionSize> createState() => _RawMotionSizeState();
}

class _RawMotionSizeState extends State<RawMotionSize>
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
  void didUpdateWidget(RawMotionSize oldWidget) {
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
    return _RawMotionSizeLayout(
      controller: _controller,
      textScaler: MediaQuery.maybeTextScalerOf(context),
      alignment: widget.alignment,
      clipBehavior: widget.clipBehavior,
      widthGrowth: widget.widthGrowth,
      child: widget.child,
    );
  }
}

class _RawMotionSizeLayout extends SingleChildRenderObjectWidget {
  const _RawMotionSizeLayout({
    required this.controller,
    required this.textScaler,
    required this.alignment,
    required this.clipBehavior,
    required this.widthGrowth,
    super.child,
  });

  final MotionController<Size> controller;
  final ValueNotifier<double>? widthGrowth;
  final TextScaler? textScaler;
  final AlignmentGeometry alignment;
  final Clip clipBehavior;

  @override
  _RenderMotionSize createRenderObject(BuildContext context) {
    return _RenderMotionSize(
      controller: controller,
      textScaler: textScaler,
      widthGrowth: widthGrowth,
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
      ..widthGrowth = widthGrowth
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
    this.widthGrowth,
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

  /// Receives the eased progress of a width growth, see
  /// [RawMotionSize.widthGrowth].
  ValueNotifier<double>? widthGrowth;

  /// The size the running spring started from.
  Size _from = Size.zero;

  /// Reports how far a growth in width has come. Called from the controller's
  /// ticks and status, never from layout, which can't notify.
  void _reportGrowth() {
    final growth = widthGrowth;
    if (growth == null) return;
    var value = 1.0;
    final target = _target;
    if (_following && _controller.isAnimating && target != null) {
      final distance = target.width - _from.width;
      // Only a growth in width counts; shrinking and a height-only growth
      // are 1.
      if (distance > 0) {
        final done = (_controller.value.width - _from.width) / distance;
        final t = done.clamp(0.0, 1.0);
        value = t * t;
      }
    }
    if (growth.value != value) growth.value = value;
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
    if (attached) _detachController();
    _controller = value;
    _target = null;
    _following = false;
    if (attached) _attachController();
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

  void _onControllerChanged() {
    _reportGrowth();
    markNeedsLayout();
  }

  /// Whether [performLayout] is running: starting a spring there reports
  /// its status at once, and the layout in progress already reads it.
  bool _laying = false;

  void _onStatus(AnimationStatus _) {
    if (_laying) return;
    _reportGrowth();
    markNeedsLayout();
  }

  void _attachController() => _controller
    ..addListener(_onControllerChanged)
    ..addStatusListener(_onStatus);

  void _detachController() => _controller
    ..removeListener(_onControllerChanged)
    ..removeStatusListener(_onStatus);

  bool _hasVisualOverflow = false;
  final _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _attachController();
  }

  @override
  void detach() {
    _detachController();
    super.detach();
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    _laying = true;
    try {
      _layoutChild();
    } finally {
      _laying = false;
    }
  }

  void _layoutChild() {
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
      if (widthGrowth case final growth? when growth.value != 1) {
        // Layout can't notify; whatever was growing has arrived.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (attached) growth.value = 1;
        });
      }
    } else {
      if (childSize != target) {
        _target = childSize;
        _from = _following ? _controller.value : target;
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
