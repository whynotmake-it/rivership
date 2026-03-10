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

    _referenceHeight = constraints.maxHeight;
    final targetHeight = _sizeFactor * constraints.maxHeight;
    final minHeight = _illegallyComputeMinIntrinsicHeight(constraints.maxWidth);
    final childMaxHeight = math.max(targetHeight, minHeight);

    child.layout(
      constraints.copyWith(
        minHeight: 0,
        maxHeight: childMaxHeight,
      ),
      parentUsesSize: true,
    );

    final visibleHeight = math.min(child.size.height, childMaxHeight);
    size = constraints.constrain(Size(child.size.width, visibleHeight));

    (child.parentData! as BoxParentData).offset =
        Offset(0, constraints.maxHeight - targetHeight);
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
