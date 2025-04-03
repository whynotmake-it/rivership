// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum _FadeBetweenSlot {
  atZero,
  atOne,
}

class FadeBetween
    extends SlottedMultiChildRenderObjectWidget<_FadeBetweenSlot, RenderBox> {
  const FadeBetween({
    super.key,
    required this.progress,
    required this.childAtZero,
    required this.childAtOne,
  });

  final double progress;

  final Widget? childAtZero;

  final Widget? childAtOne;

  @override
  Iterable<_FadeBetweenSlot> get slots => _FadeBetweenSlot.values;

  @override
  Widget? childForSlot(_FadeBetweenSlot slot) => switch (slot) {
        _FadeBetweenSlot.atZero => childAtZero,
        _FadeBetweenSlot.atOne => childAtOne,
      };

  @override
  _FadeBetweenRenderObject createRenderObject(BuildContext context) {
    return _FadeBetweenRenderObject(progress);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _FadeBetweenRenderObject renderObject) {
    renderObject.progress = progress;
  }
}

class _FadeBetweenRenderObject extends RenderProxyBox
    with SlottedContainerRenderObjectMixin<_FadeBetweenSlot, RenderBox> {
  _FadeBetweenRenderObject(this._progress);

  double _progress;
  double get progress => _progress;

  RenderBox? get childAtZero => childForSlot(_FadeBetweenSlot.atZero);

  RenderBox? get childAtOne => childForSlot(_FadeBetweenSlot.atOne);

  set progress(double v) {
    if (v == _progress) return;
    _progress = v;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    childAtZero?.layout(constraints, parentUsesSize: true);
    childAtOne?.layout(constraints, parentUsesSize: true);

    size = Size(
      _getLargest(childAtZero?.size.width, childAtOne?.size.width) ??
          constraints.biggest.width,
      _getLargest(childAtZero?.size.height, childAtOne?.size.height) ??
          constraints.biggest.height,
    );
  }

  double? _getLargest(double? a, double? b) => switch ((a, b)) {
        (final a?, final b?) when a > b => a,
        (double(), final b?) => b,
        (final a?, null) => a,
        (null, final b?) => b,
        (null, null) => null,
      };

  @override
  @override
  void paint(PaintingContext context, Offset offset) {
    // Save layer with a Paint that has the right compositing mode
    context.canvas.saveLayer(
      offset & size,
      Paint(),
    );

    // Paint first child with appropriate opacity
    if (childAtZero != null) {
      final opacity = 1.0 - progress;
      if (opacity > 0.0) {
        context.canvas.saveLayer(
          offset & size,
          Paint()
            ..color = Color.from(
              alpha: opacity,
              red: 1,
              green: 1,
              blue: 1,
            ),
        );
        context.paintChild(childAtZero!, offset);
      }
    }

    // Paint second child with appropriate opacity
    if (childAtOne != null) {
      final opacity = progress;
      if (opacity > 0.0) {
        context.canvas.saveLayer(
          offset & size,
          Paint()
            ..color = Color.from(
              alpha: opacity,
              red: 1,
              green: 1,
              blue: 1,
            ),
        );
        context.paintChild(childAtOne!, offset);
      }
    }

    if (progress < 1) context.canvas.restore();
    if (progress > 0) context.canvas.restore();

    // Restore the original layer
    context.canvas.restore();
  }
}
