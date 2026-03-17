import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget that shrinks its child vertically based on [sizeFactor].
///
/// When [sizeFactor] is 1.0, the child is displayed at full height.
/// As [sizeFactor] decreases toward 0.0, the visible height shrinks.
///
/// Values above 1.0 are supported to allow spring-based animations that
/// overshoot — the child is laid out at the full target height.
///
/// If the child cannot shrink below its minimum intrinsic height, the child
/// is laid out at its minimum size and the overflow is clipped at the bottom.
/// This produces a visual effect equivalent to a slide once the minimum
/// height is reached.
class ShrinkTransition extends SingleChildRenderObjectWidget {
  /// Creates a shrink transition.
  ///
  /// The [sizeFactor] must be non-negative.
  const ShrinkTransition({
    required this.sizeFactor,
    super.key,
    super.child,
  }) : assert(
          sizeFactor >= 0.0,
          'sizeFactor must be non-negative, got $sizeFactor',
        );

  /// The fraction of the maximum height to display.
  ///
  /// Typically between 0.0 and 1.0, but values above 1.0 are allowed to
  /// support spring overshoot.
  final double sizeFactor;

  /// Returns the `referenceHeight` of the nearest ancestor
  /// [RenderShrinkTransition], or `null` if there is none.
  ///
  /// This is the height that [sizeFactor] scales against and is useful for
  /// normalizing drag deltas consistently, regardless of whether the child
  /// actually shrank.
  static double? referenceHeightOf(BuildContext context) {
    final renderObject =
        context.findAncestorRenderObjectOfType<RenderShrinkTransition>();
    return renderObject?.referenceHeight;
  }

  @override
  RenderShrinkTransition createRenderObject(BuildContext context) {
    return RenderShrinkTransition(sizeFactor: sizeFactor);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderShrinkTransition renderObject,
  ) {
    renderObject.sizeFactor = sizeFactor;
  }
}

/// Render object that lays out its child at a height determined by
/// [sizeFactor], falling back to the child's minimum intrinsic height
/// when the target height is too small.
///
/// The child is allowed to be taller than this render object and will be
/// clipped — no overflow errors are reported.
class RenderShrinkTransition extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  /// Creates a render object for [ShrinkTransition].
  RenderShrinkTransition({required double sizeFactor})
      : _sizeFactor = sizeFactor;

  double _sizeFactor;

  /// The fraction of the maximum height to display.
  double get sizeFactor => _sizeFactor;
  set sizeFactor(double value) {
    if (_sizeFactor == value) return;
    _sizeFactor = value;
    markNeedsLayout();
  }

  /// The maximum height from the most recent layout pass.
  ///
  /// This is the height that [sizeFactor] scales against and can be read
  /// by ancestors (e.g. gesture detectors) to normalize drag deltas
  /// consistently, regardless of whether the child actually shrank.
  double get referenceHeight => _referenceHeight;
  double _referenceHeight = 0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    // First, lay out at the full available height to learn the child's
    // natural height.  Most children (Scaffold, Column, etc.) will expand
    // to fill; short children (Container with maxHeight) will be smaller.
    child.layout(
      constraints.copyWith(minHeight: 0),
      parentUsesSize: true,
    );
    final naturalHeight = child.size.height;

    // The reference height is the child's natural height so that drag
    // deltas are normalised against the actual content, not the route.
    _referenceHeight = naturalHeight;

    // Scale from the child's natural height so that a 400 px child
    // inside a 1000 px route already shrinks at sizeFactor = 0.5
    // (→ 200 px) instead of remaining unchanged.
    final targetHeight = _sizeFactor * naturalHeight;

    // Don't let the child go below its minimum intrinsic height.
    final minHeight = _illegallyComputeMinIntrinsicHeight(constraints.maxWidth);
    final childMaxHeight = math.max(targetHeight, minHeight);

    // Re-layout only when the tighter constraint actually differs.
    if (childMaxHeight < naturalHeight) {
      child.layout(
        constraints.copyWith(
          minHeight: 0,
          maxHeight: childMaxHeight,
        ),
        parentUsesSize: true,
      );
    }

    // Clamp our reported size to the constraints — we can never be taller
    // than the parent allows.
    size = constraints.constrain(Size(child.size.width, targetHeight));

    // When sizeFactor > 1.0 (spring overshoot), targetHeight exceeds the
    // child's natural height but constraints.constrain clamps our size to
    // at most naturalHeight.  To visualise the overshoot we translate the
    // child *upward* by the excess pixels so it appears to push up.
    final overshootPx = targetHeight - child.size.height;
    final dy = overshootPx > 0 ? -overshootPx : 0.0;
    (child.parentData! as BoxParentData).offset = Offset(0, dy);
  }

  // FIXME: Hey! this feels illegal https://github.com/flutter/flutter/issues/183443
  double _illegallyComputeMinIntrinsicHeight(double width) {
    final wasCheckingIntrinsics = RenderObject.debugCheckingIntrinsics;
    try {
      RenderObject.debugCheckingIntrinsics = true;
      return child?.getMinIntrinsicHeight(constraints.maxWidth) ?? 0.0;
    } finally {
      RenderObject.debugCheckingIntrinsics = wasCheckingIntrinsics;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;

    final childParentData = child.parentData! as BoxParentData;
    context.paintChild(child, childParentData.offset + offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final childParentData = child.parentData! as BoxParentData;
    return result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return child.hitTest(result, position: transformed);
      },
    );
  }
}
