import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/motion_size.dart';
import 'package:motor_widgets/src/motion_switcher.dart';

/// A [MotionSwitcher] inside a [MotionSize]: switches its child with a
/// spring transition and springs its size to fit.
///
/// The Motor version of rivership's `AnimatedSizeSwitcher`. If [child] is
/// null, it shrinks to take up as little space as possible.
class MotionSizeSwitcher extends StatelessWidget {
  /// Creates a [MotionSizeSwitcher].
  const MotionSizeSwitcher({
    required this.motion,
    required this.child,
    this.exitMotion,
    this.sizeMotion,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    this.immediateResize = false,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The child to switch to.
  ///
  /// As in [MotionSwitcher], a child that can't update the previous one (a
  /// different type or key) switches. Null takes up as little space as
  /// possible.
  final Widget? child;

  /// The motion an entering child follows, and the size unless
  /// [sizeMotion] is set.
  final Motion motion;

  /// The spring a leaving child follows. Defaults to [motion].
  final Motion? exitMotion;

  /// The motion the size follows. Defaults to [motion].
  ///
  /// Set it to resize on a spatial spring while the children fade on
  /// [motion].
  final Motion? sizeMotion;

  /// How the children are aligned while the size animates.
  final AlignmentGeometry alignment;

  /// How children are clipped while they overflow the animated size.
  final Clip clipBehavior;

  /// Wraps a child in a transition driven by its presence spring. Defaults
  /// to [AnimatedSwitcher.defaultTransitionBuilder].
  ///
  /// See [MotionSwitcher.transitionBuilder]; the animation may overshoot.
  final AnimatedSwitcherTransitionBuilder transitionBuilder;

  /// Whether the size follows the new child at once, ignoring the leaving
  /// children. Defaults to false.
  ///
  /// When false, the leaving children keep their space until they are gone,
  /// so the size only shrinks after they have left. When true, only the new
  /// child is sized. Leaving children keep the constraints they had and
  /// sit by [alignment], overflowing the new size and clipped by
  /// [clipBehavior].
  final bool immediateResize;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    final label = debugLabel ?? 'MotionSizeSwitcher';
    if (!immediateResize) {
      return MotionSize(
        motion: sizeMotion ?? motion,
        alignment: alignment,
        clipBehavior: clipBehavior,
        tickerRate: tickerRate,
        debugLabel: '$label size',
        child: MotionSwitcher(
          motion: motion,
          exitMotion: exitMotion,
          transitionBuilder: transitionBuilder,
          tickerRate: tickerRate,
          debugLabel: label,
          // An empty Stack would take the biggest size it is allowed, not
          // the smallest.
          layoutBuilder: (currentChild, previousChildren) =>
              currentChild == null && previousChildren.isEmpty
              ? const SizedBox.shrink()
              : Stack(
                  clipBehavior: clipBehavior,
                  alignment: alignment,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
          child: child,
        ),
      );
    }
    return MotionSwitcher(
      motion: motion,
      exitMotion: exitMotion,
      transitionBuilder: transitionBuilder,
      tickerRate: tickerRate,
      debugLabel: label,
      layoutBuilder: (currentChild, previousChildren) => _ImmediateResizeLayout(
        alignment: alignment,
        clipBehavior: clipBehavior,
        children: [
          ...previousChildren,
          MotionSize(
            motion: sizeMotion ?? motion,
            alignment: alignment,
            clipBehavior: clipBehavior,
            tickerRate: tickerRate,
            debugLabel: '$label size',
            child: currentChild,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Lays out the last child, the [MotionSize] around the current child, and
/// takes its size. The leaving children before it keep the constraints this
/// box gets, so a wrapping one doesn't reflow while it leaves. They sit by
/// [alignment], overflowing and clipped by [clipBehavior].
class _ImmediateResizeLayout extends MultiChildRenderObjectWidget {
  const _ImmediateResizeLayout({
    required this.alignment,
    required this.clipBehavior,
    super.children,
  });

  final AlignmentGeometry alignment;
  final Clip clipBehavior;

  @override
  _RenderImmediateResize createRenderObject(BuildContext context) =>
      _RenderImmediateResize(
        alignment: alignment,
        clipBehavior: clipBehavior,
        textDirection: Directionality.maybeOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderImmediateResize renderObject,
  ) {
    renderObject
      ..alignment = alignment
      ..clipBehavior = clipBehavior
      ..textDirection = Directionality.maybeOf(context);
  }
}

class _ImmediateResizeParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderImmediateResize extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ImmediateResizeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ImmediateResizeParentData> {
  _RenderImmediateResize({
    required AlignmentGeometry alignment,
    required Clip clipBehavior,
    TextDirection? textDirection,
  }) : _alignment = alignment,
       _clipBehavior = clipBehavior,
       _textDirection = textDirection;

  AlignmentGeometry get alignment => _alignment;
  AlignmentGeometry _alignment;
  set alignment(AlignmentGeometry value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    if (value == _clipBehavior) return;
    _clipBehavior = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  bool _hasVisualOverflow = false;
  final _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ImmediateResizeParentData) {
      child.parentData = _ImmediateResizeParentData();
    }
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  /// The child that sizes this box: the [MotionSize], always last.
  RenderBox get _sizing => lastChild!;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _sizing.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _sizing.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _sizing.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _sizing.getMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final sizing = _sizing;
    final offset = (sizing.parentData! as _ImmediateResizeParentData).offset;
    final distance = sizing.getDistanceToActualBaseline(baseline);
    return distance == null ? null : distance + offset.dy;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _sizing.getDryLayout(constraints);

  @override
  void performLayout() {
    final constraints = this.constraints;
    final sizing = _sizing..layout(constraints, parentUsesSize: true);
    size = sizing.size;
    final alignment = _alignment.resolve(_textDirection);
    _hasVisualOverflow = false;
    var child = firstChild;
    while (child != null && child != sizing) {
      child.layout(constraints, parentUsesSize: true);
      final parentData = child.parentData! as _ImmediateResizeParentData
        ..offset = alignment.inscribe(child.size, Offset.zero & size).topLeft;
      if (child.size.width > size.width || child.size.height > size.height) {
        _hasVisualOverflow = true;
      }
      child = parentData.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_hasVisualOverflow && clipBehavior != Clip.none) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        defaultPaint,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      defaultPaint(context, offset);
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _hasVisualOverflow && clipBehavior != Clip.none
      ? Offset.zero & size
      : null;
}
