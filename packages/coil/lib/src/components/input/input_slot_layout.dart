// Internal to CoilInput; not exported.
// ignore_for_file: public_member_api_docs
// The render object's fields sit behind setters that mark layout dirty.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:coil/primitives.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The parts of a text field's box.
enum InputSlot { line, leading, field, trailing }

/// Whether an [InputSlotLayout] holds one line of text or several.
enum InputSlotLines {
  /// Everything centers in the field.
  single,

  /// The text and inline slots start at the top; inset slots sit in the
  /// bottom corner.
  multi,
}

/// Lays out a text field's box: `[leading] field [trailing]`, inside the
/// field's border. Its padding, [minHeight] and [minInset] are measured
/// from the border's inner edge, which is the same all round, so a slot
/// even inset here is even inset from the field's outer edge too.
///
/// Each slot is measured, then placed, in this one layout pass, so the
/// first frame is already right and nothing rebuilds:
///
/// * a slot no taller than [line] (an empty line of the field's text style,
///   never painted) sits inline: inside the padding, centered on the text,
///   or on the first line of a multi-line field;
/// * a taller slot (a button) sits inset: centered in the field, as far
///   from its side as from its top and bottom, and the field grows only
///   when the slot and [minInset] on each side don't fit [minHeight]. On a
///   multi-line field it sits that far in from the bottom corner.
///
/// [CoilInputSlotPlacement.inline] and [CoilInputSlotPlacement.inset] force
/// one or the other. An inset slot takes taps in a box of at least
/// [minHitTarget] around it, inside the field, so a touch button can drop
/// its own hit padding.
class InputSlotLayout
    extends SlottedMultiChildRenderObjectWidget<InputSlot, RenderBox> {
  const InputSlotLayout({
    required this.line,
    required this.field,
    required this.paddingX,
    required this.paddingY,
    required this.gap,
    required this.minHeight,
    required this.minInset,
    required this.minHitTarget,
    required this.lines,
    this.leading,
    this.trailing,
    this.leadingPlacement = CoilInputSlotPlacement.auto,
    this.trailingPlacement = CoilInputSlotPlacement.auto,
    super.key,
  });

  /// An empty line of the field's text style, never painted: the height
  /// an inline slot fits.
  final Widget line;
  final Widget? leading;
  final Widget field;
  final Widget? trailing;

  /// The padding between the border and the text.
  final double paddingX;
  final double paddingY;

  /// The space between a slot and the text.
  final double gap;

  /// The minimum height inside the border.
  final double minHeight;

  /// The least space between an inset slot and the border.
  final double minInset;

  /// The least size of the box an inset slot takes taps in.
  final double minHitTarget;

  final InputSlotLines lines;
  final CoilInputSlotPlacement leadingPlacement;
  final CoilInputSlotPlacement trailingPlacement;

  @override
  Iterable<InputSlot> get slots => InputSlot.values;

  @override
  Widget? childForSlot(InputSlot slot) => switch (slot) {
    InputSlot.line => line,
    InputSlot.leading => leading,
    InputSlot.field => field,
    InputSlot.trailing => trailing,
  };

  @override
  RenderInputSlotLayout createRenderObject(BuildContext context) =>
      RenderInputSlotLayout(
        paddingX: paddingX,
        paddingY: paddingY,
        gap: gap,
        minHeight: minHeight,
        minInset: minInset,
        minHitTarget: minHitTarget,
        lines: lines,
        leadingPlacement: leadingPlacement,
        trailingPlacement: trailingPlacement,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderInputSlotLayout renderObject,
  ) {
    renderObject
      ..paddingX = paddingX
      ..paddingY = paddingY
      ..gap = gap
      ..minHeight = minHeight
      ..minInset = minInset
      ..minHitTarget = minHitTarget
      ..lines = lines
      ..leadingPlacement = leadingPlacement
      ..trailingPlacement = trailingPlacement
      ..textDirection = Directionality.of(context);
  }
}

/// Where one slot went.
typedef _Placed = ({Size size, bool inset, double x, double y});

/// The result of one layout: the box's size, and the field's constraints
/// and offset for its baseline.
typedef _Layout = ({
  Size size,
  BoxConstraints fieldConstraints,
  Offset fieldOffset,
  _Placed? leading,
  _Placed? trailing,
});

class RenderInputSlotLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<InputSlot, RenderBox> {
  RenderInputSlotLayout({
    required double paddingX,
    required double paddingY,
    required double gap,
    required double minHeight,
    required double minInset,
    required double minHitTarget,
    required InputSlotLines lines,
    required CoilInputSlotPlacement leadingPlacement,
    required CoilInputSlotPlacement trailingPlacement,
    required TextDirection textDirection,
  }) : _paddingX = paddingX,
       _paddingY = paddingY,
       _gap = gap,
       _minHeight = minHeight,
       _minInset = minInset,
       _minHitTarget = minHitTarget,
       _lines = lines,
       _leadingPlacement = leadingPlacement,
       _trailingPlacement = trailingPlacement,
       _textDirection = textDirection;

  double get paddingX => _paddingX;
  double _paddingX;
  set paddingX(double value) {
    if (value == _paddingX) return;
    _paddingX = value;
    markNeedsLayout();
  }

  double get paddingY => _paddingY;
  double _paddingY;
  set paddingY(double value) {
    if (value == _paddingY) return;
    _paddingY = value;
    markNeedsLayout();
  }

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double get minHeight => _minHeight;
  double _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  double get minInset => _minInset;
  double _minInset;
  set minInset(double value) {
    if (value == _minInset) return;
    _minInset = value;
    markNeedsLayout();
  }

  double get minHitTarget => _minHitTarget;
  double _minHitTarget;
  set minHitTarget(double value) {
    if (value == _minHitTarget) return;
    _minHitTarget = value;
    // Only hit testing reads it.
  }

  InputSlotLines get lines => _lines;
  InputSlotLines _lines;
  set lines(InputSlotLines value) {
    if (value == _lines) return;
    _lines = value;
    markNeedsLayout();
  }

  CoilInputSlotPlacement get leadingPlacement => _leadingPlacement;
  CoilInputSlotPlacement _leadingPlacement;
  set leadingPlacement(CoilInputSlotPlacement value) {
    if (value == _leadingPlacement) return;
    _leadingPlacement = value;
    markNeedsLayout();
  }

  CoilInputSlotPlacement get trailingPlacement => _trailingPlacement;
  CoilInputSlotPlacement _trailingPlacement;
  set trailingPlacement(CoilInputSlotPlacement value) {
    if (value == _trailingPlacement) return;
    _trailingPlacement = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _line => childForSlot(InputSlot.line)!;
  RenderBox? get _leading => childForSlot(InputSlot.leading);
  RenderBox get _field => childForSlot(InputSlot.field)!;
  RenderBox? get _trailing => childForSlot(InputSlot.trailing);

  bool get _multi => lines == InputSlotLines.multi;

  /// Whether a slot [height] tall goes into the padding, for a line
  /// [lineHeight] tall.
  static bool _isInset(
    CoilInputSlotPlacement placement,
    double height,
    double lineHeight,
  ) => switch (placement) {
    CoilInputSlotPlacement.inline => false,
    CoilInputSlotPlacement.inset => true,
    // Half a pixel of slack for rounding in the slot's own layout.
    CoilInputSlotPlacement.auto => height > lineHeight + 0.5,
  };

  /// The inset of a slot [height] tall in a field [fieldHeight] tall: as
  /// far from the side as from the top and bottom, never under [minInset].
  double _insetOf(double height, double fieldHeight) =>
      math.max(minInset, (fieldHeight - height) / 2);

  /// A [ChildLayouter] that answers from a child's intrinsics, for this
  /// layout's own intrinsic sizes, so children that can't lay out dry still
  /// answer them. A child takes its max intrinsic width up to the
  /// constraints and [heightAt] that width.
  static ChildLayouter _intrinsic(
    double Function(RenderBox child, double width) heightAt,
  ) => (child, constraints) {
    final width = constraints.hasTightWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(
            child.getMaxIntrinsicWidth(double.infinity),
          );
    return constraints.constrain(Size(width, heightAt(child, width)));
  };

  /// The width the slots and their gaps and edges take, at the field's
  /// minimum height.
  double _sides(double Function(RenderBox) width, double lineHeight) {
    double side(RenderBox? slot, CoilInputSlotPlacement placement) {
      if (slot == null) return paddingX;
      final w = width(slot);
      final h = slot.getMaxIntrinsicHeight(w);
      final edge = _isInset(placement, h, lineHeight)
          ? _insetOf(h, minHeight)
          : paddingX;
      return edge + w + gap;
    }

    return side(_leading, leadingPlacement) +
        side(_trailing, trailingPlacement);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _sides(
        (c) => c.getMaxIntrinsicWidth(double.infinity),
        _line.getMaxIntrinsicHeight(double.infinity),
      ) +
      _field.getMinIntrinsicWidth(double.infinity);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _sides(
        (c) => c.getMaxIntrinsicWidth(double.infinity),
        _line.getMaxIntrinsicHeight(double.infinity),
      ) +
      _field.getMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicHeight(double width) => _compute(
    BoxConstraints(maxWidth: width),
    _intrinsic((child, width) => child.getMinIntrinsicHeight(width)),
  ).size.height;

  @override
  double computeMaxIntrinsicHeight(double width) => _compute(
    BoxConstraints(maxWidth: width),
    _intrinsic((child, width) => child.getMaxIntrinsicHeight(width)),
  ).size.height;

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _compute(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final layout = _compute(constraints, ChildLayoutHelper.dryLayoutChild);
    final distance = _field.getDryBaseline(layout.fieldConstraints, baseline);
    return distance == null ? null : distance + layout.fieldOffset.dy;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final field = _field;
    final distance = field.getDistanceToActualBaseline(baseline);
    if (distance == null) return null;
    return distance + (field.parentData! as BoxParentData).offset.dy;
  }

  _Layout? _layout;

  @override
  void performLayout() {
    final layout = _layout = _compute(
      constraints,
      ChildLayoutHelper.layoutChild,
    );
    size = layout.size;
    final rtl = textDirection == TextDirection.rtl;
    void put(RenderBox? child, Size childSize, Offset at) {
      if (child == null) return;
      (child.parentData! as BoxParentData).offset = Offset(
        rtl ? size.width - at.dx - childSize.width : at.dx,
        at.dy,
      );
    }

    put(_line, _line.size, Offset.zero);
    put(_field, _field.size, layout.fieldOffset);
    for (final (child, placed) in [
      (_leading, layout.leading),
      (_trailing, layout.trailing),
    ]) {
      if (placed != null) put(child, placed.size, Offset(placed.x, placed.y));
    }
  }

  /// Lays the field out with [layoutChild]. Offsets are left to right;
  /// [performLayout] mirrors them for right to left.
  _Layout _compute(BoxConstraints constraints, ChildLayouter layoutChild) {
    final leading = _leading;
    final trailing = _trailing;
    final field = _field;
    final multi = _multi;
    final bounded = constraints.hasBoundedWidth;
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);

    final lineHeight = layoutChild(_line, const BoxConstraints()).height;
    final leadingSize = leading == null ? null : layoutChild(leading, loose);
    final trailingSize = trailing == null ? null : layoutChild(trailing, loose);
    final leadingInset =
        leadingSize != null &&
        _isInset(leadingPlacement, leadingSize.height, lineHeight);
    final trailingInset =
        trailingSize != null &&
        _isInset(trailingPlacement, trailingSize.height, lineHeight);

    // How far the text starts in from an edge, for a field [height] tall.
    double edge(Size? slot, bool inset, double height) => slot == null
        ? paddingX
        : (inset ? _insetOf(slot.height, height) : paddingX) + slot.width + gap;

    BoxConstraints fieldConstraints(double height) {
      final start = edge(leadingSize, leadingInset, height);
      final end = edge(trailingSize, trailingInset, height);
      final maxHeight = constraints.hasBoundedHeight
          ? math.max(0, constraints.maxHeight - 2 * paddingY).toDouble()
          : double.infinity;
      if (!bounded) return BoxConstraints(maxHeight: maxHeight);
      return BoxConstraints(
        minWidth: math.max(0, constraints.maxWidth - start - end),
        maxWidth: math.max(0, constraints.maxWidth - start - end),
        maxHeight: maxHeight,
      );
    }

    // The height everything needs around a field [fieldHeight] tall.
    double heightFor(double fieldHeight) {
      var height = math.max(minHeight, fieldHeight + 2 * paddingY);
      for (final (slot, inset) in [
        (leadingSize, leadingInset),
        (trailingSize, trailingInset),
      ]) {
        if (slot == null) continue;
        height = math.max(
          height,
          inset
              ? slot.height + 2 * _insetOf(slot.height, minHeight)
              : multi
              // On the first line, or from the top when taller.
              ? paddingY + math.max(lineHeight, slot.height) + paddingY
              : slot.height + 2 * paddingY,
        );
      }
      return constraints.constrainHeight(height);
    }

    // First at the minimum height. A single-line field that grows (large
    // text) centers its inset slots in the taller box and lays the text out
    // again at the width that leaves; its height doesn't change with the
    // width. A multi-line field keeps the insets of the minimum height.
    var fieldBox = fieldConstraints(minHeight);
    var fieldSize = layoutChild(field, fieldBox);
    var height = heightFor(fieldSize.height);
    if (!multi && height != minHeight && (leadingInset || trailingInset)) {
      final again = fieldConstraints(height);
      if (again != fieldBox) {
        fieldBox = again;
        fieldSize = layoutChild(field, fieldBox);
        height = heightFor(fieldSize.height);
      }
    }
    final insetHeight = multi ? minHeight : height;

    final width = bounded
        ? constraints.maxWidth
        : constraints.constrainWidth(
            edge(leadingSize, leadingInset, insetHeight) +
                fieldSize.width +
                edge(trailingSize, trailingInset, insetHeight),
          );
    final size = Size(width, height);

    double slotY(Size slot, bool inset) {
      if (!multi) return (height - slot.height) / 2;
      if (inset) {
        return height - _insetOf(slot.height, insetHeight) - slot.height;
      }
      return paddingY + math.max(0, (lineHeight - slot.height) / 2);
    }

    _Placed? place(Size? slot, bool inset, {required bool start}) {
      if (slot == null) return null;
      final side = inset ? _insetOf(slot.height, insetHeight) : paddingX;
      return (
        size: slot,
        inset: inset,
        x: start ? side : width - side - slot.width,
        y: slotY(slot, inset),
      );
    }

    return (
      size: size,
      fieldConstraints: fieldBox,
      fieldOffset: Offset(
        edge(leadingSize, leadingInset, insetHeight),
        multi ? paddingY : (height - fieldSize.height) / 2,
      ),
      leading: place(leadingSize, leadingInset, start: true),
      trailing: place(trailingSize, trailingInset, start: false),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // The line only measures.
    for (final child in [_field, ?_leading, ?_trailing]) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final (child, placed) in [
      (_trailing, _layout?.trailing),
      (_leading, _layout?.leading),
    ]) {
      if (child == null) continue;
      final offset = (child.parentData! as BoxParentData).offset;
      final bounds = offset & child.size;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, local) => child.hitTest(result, position: local),
      );
      if (hit) return true;
      // An inset slot takes taps around it up to the hit target, inside
      // the field: the touch rim a button dropped.
      if (placed != null &&
          placed.inset &&
          _hitBox(bounds).contains(position)) {
        final center = child.size.center(Offset.zero);
        final hitCenter = result.addWithRawTransform(
          transform: MatrixUtils.forceToPoint(center),
          position: center,
          hitTest: (result, local) => child.hitTest(result, position: local),
        );
        if (hitCenter) return true;
      }
    }
    final field = _field;
    return result.addWithPaintOffset(
      offset: (field.parentData! as BoxParentData).offset,
      position: position,
      hitTest: (result, local) => field.hitTest(result, position: local),
    );
  }

  /// [slot] grown to [minHitTarget] around its center, inside the field.
  Rect _hitBox(Rect slot) {
    final grow = Size(
      math.max(0, minHitTarget - slot.width) / 2,
      math.max(0, minHitTarget - slot.height) / 2,
    );
    return Rect.fromLTRB(
      slot.left - grow.width,
      slot.top - grow.height,
      slot.right + grow.width,
      slot.bottom + grow.height,
    ).intersect(Offset.zero & size);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty('lines', lines))
      ..add(EnumProperty('leadingPlacement', leadingPlacement))
      ..add(EnumProperty('trailingPlacement', trailingPlacement));
  }
}
