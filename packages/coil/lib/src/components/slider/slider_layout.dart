// Internal to CoilSlider; not exported.
// ignore_for_file: public_member_api_docs
// The render object's fields sit behind setters that mark layout dirty.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The parts of a pill row.
enum SliderPillSlot { label, track, value }

/// Lays out a pill row: label, track and value on one line when the track
/// keeps at least [minTrack] there; otherwise the label and the value share
/// a line above a full-width track.
///
/// The choice is part of layout: it compares the row's width with the
/// label's and the value's natural widths, so nothing is measured after
/// layout and nothing rebuilds.
class SliderPillLayout
    extends SlottedMultiChildRenderObjectWidget<SliderPillSlot, RenderBox> {
  const SliderPillLayout({
    required this.label,
    required this.track,
    required this.value,
    required this.gap,
    required this.minTrack,
    super.key,
  });

  final Widget? label;
  final Widget track;
  final Widget? value;

  /// The space between the parts on a line.
  final double gap;

  /// The narrowest the track may get beside the label and the value.
  final double minTrack;

  @override
  Iterable<SliderPillSlot> get slots => SliderPillSlot.values;

  @override
  Widget? childForSlot(SliderPillSlot slot) => switch (slot) {
    SliderPillSlot.label => label,
    SliderPillSlot.track => track,
    SliderPillSlot.value => value,
  };

  @override
  RenderSliderPill createRenderObject(BuildContext context) => RenderSliderPill(
    gap: gap,
    minTrack: minTrack,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderSliderPill renderObject) {
    renderObject
      ..gap = gap
      ..minTrack = minTrack
      ..textDirection = Directionality.of(context);
  }
}

class RenderSliderPill extends RenderBox
    with SlottedContainerRenderObjectMixin<SliderPillSlot, RenderBox> {
  RenderSliderPill({
    required double gap,
    required double minTrack,
    required TextDirection textDirection,
  }) : _gap = gap,
       _minTrack = minTrack,
       _textDirection = textDirection;

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double get minTrack => _minTrack;
  double _minTrack;
  set minTrack(double value) {
    if (value == _minTrack) return;
    _minTrack = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _label => childForSlot(SliderPillSlot.label);
  RenderBox get _track => childForSlot(SliderPillSlot.track)!;
  RenderBox? get _value => childForSlot(SliderPillSlot.value);

  /// Whether the parts are stacked: in a row [width] wide, the label, the
  /// value and the gaps leave the track less than [minTrack].
  bool stacked(double width) {
    if (!width.isFinite) return false;
    return _naturalLine(_label) + _naturalLine(_value) + minTrack > width;
  }

  /// A part's natural width plus the gap beside it, 0 when absent.
  double _naturalLine(RenderBox? child) =>
      child == null ? 0 : child.getMaxIntrinsicWidth(double.infinity) + gap;

  @override
  double computeMinIntrinsicWidth(double height) {
    // Stacked: the wider of the text line and the shortest track.
    final line = _naturalLine(_label) + _naturalLine(_value) - gap;
    return math.max(math.max(line, 0), minTrack);
  }

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _naturalLine(_label) + _naturalLine(_value) + minTrack;

  @override
  double computeMinIntrinsicHeight(double width) => _height(
    width,
    (child, w) => child.getMinIntrinsicHeight(w),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _height(
    width,
    (child, w) => child.getMaxIntrinsicHeight(w),
  );

  double _height(double width, double Function(RenderBox, double) of) {
    final label = _label == null ? 0.0 : of(_label!, double.infinity);
    final value = _value == null ? 0.0 : of(_value!, double.infinity);
    final track = of(_track, width);
    final line = math.max(label, value);
    return stacked(width) ? line + track : math.max(line, track);
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    assert(
      debugCannotComputeDryLayout(
        reason: 'The track measures itself during layout.',
      ),
      'no dry layout',
    );
    return Size.zero;
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final label = _label;
    final value = _value;
    final rtl = textDirection == TextDirection.rtl;

    final valueSize = value == null
        ? Size.zero
        : (value..layout(
                BoxConstraints(maxWidth: width),
                parentUsesSize: true,
              ))
              .size;
    final valueSpace = value == null ? 0.0 : valueSize.width + gap;

    if (stacked(width)) {
      // The label gives way to the value on the shared line, then ellipsizes.
      final labelSize = label == null
          ? Size.zero
          : (label..layout(
                  BoxConstraints(maxWidth: math.max(0, width - valueSpace)),
                  parentUsesSize: true,
                ))
                .size;
      final line = math.max(labelSize.height, valueSize.height);
      _track.layout(
        BoxConstraints.tightFor(width: width),
        parentUsesSize: true,
      );
      _place(
        label,
        rtl ? width - labelSize.width : 0,
        (line - labelSize.height) / 2,
      );
      _place(
        value,
        rtl ? 0 : width - valueSize.width,
        (line - valueSize.height) / 2,
      );
      _place(_track, 0, line);
      size = constraints.constrain(Size(width, line + _track.size.height));
      return;
    }

    final labelSize = label == null
        ? Size.zero
        : (label..layout(
                BoxConstraints(
                  maxWidth: width.isFinite ? width : double.infinity,
                ),
                parentUsesSize: true,
              ))
              .size;
    final labelSpace = label == null ? 0.0 : labelSize.width + gap;
    final trackWidth = width.isFinite
        ? math.max(0, width - labelSpace - valueSpace).toDouble()
        : minTrack;
    _track.layout(
      BoxConstraints.tightFor(width: trackWidth),
      parentUsesSize: true,
    );
    final height = [
      labelSize.height,
      valueSize.height,
      _track.size.height,
    ].reduce(math.max);
    final total = labelSpace + trackWidth + valueSpace;
    double startX(double x, double w) => rtl ? total - x - w : x;
    _place(label, startX(0, labelSize.width), (height - labelSize.height) / 2);
    _place(
      _track,
      startX(labelSpace, trackWidth),
      (height - _track.size.height) / 2,
    );
    _place(
      value,
      startX(labelSpace + trackWidth + gap, valueSize.width),
      (height - valueSize.height) / 2,
    );
    size = constraints.constrain(Size(total, height));
  }

  void _place(RenderBox? child, double x, double y) {
    if (child == null) return;
    (child.parentData! as BoxParentData).offset = Offset(x, y);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, local) => child.hitTest(result, position: local),
      );
      if (hit) return true;
    }
    return false;
  }
}
