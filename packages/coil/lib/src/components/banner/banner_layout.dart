// Internal to CoilBanner; not exported.
// ignore_for_file: public_member_api_docs
// The render object's fields sit behind setters that mark layout dirty.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The parts of a banner's row.
enum BannerSlot { line, icon, text, actions, dismiss }

/// How a [BannerLayout] arranges its text and actions.
enum BannerFlow {
  /// Actions after the text when the text fits beside them on one line,
  /// all centered on that line; otherwise under the text.
  auto,

  /// Actions always under the text, everything top-aligned.
  stacked,
}

/// Lays out a banner: `[icon] text [actions] [dismiss]`.
///
/// With [BannerFlow.auto], the actions sit after the text when the text's
/// natural width and the actions fit the row; the text then ends where the
/// actions start, and every part centers on the row. When they don't fit,
/// the actions move under the text, and the icon and the dismiss button
/// center on the text's first line, which [line] (an empty line of the
/// title's style) measures. A dismiss button taller than the line reaches
/// up into the banner's padding there, and still takes taps.
///
/// The choice is part of layout: the text is laid out once at the full
/// width to find its natural width, so nothing is measured after layout and
/// nothing rebuilds.
class BannerLayout
    extends SlottedMultiChildRenderObjectWidget<BannerSlot, RenderBox> {
  const BannerLayout({
    required this.line,
    required this.text,
    required this.gap,
    required this.actionSpacing,
    required this.flow,
    this.icon,
    this.actions,
    this.dismiss,
    super.key,
  });

  /// An empty line of the title's style, never painted: the height the
  /// icon and the dismiss button center on when stacked.
  final Widget line;
  final Widget? icon;
  final Widget text;
  final Widget? actions;
  final Widget? dismiss;

  /// The space between the icon, the text (or the actions after it) and
  /// the dismiss button.
  final double gap;

  /// The space between the text and the actions under it.
  final double actionSpacing;

  final BannerFlow flow;

  @override
  Iterable<BannerSlot> get slots => BannerSlot.values;

  @override
  Widget? childForSlot(BannerSlot slot) => switch (slot) {
    BannerSlot.line => line,
    BannerSlot.icon => icon,
    BannerSlot.text => text,
    BannerSlot.actions => actions,
    BannerSlot.dismiss => dismiss,
  };

  @override
  RenderBannerLayout createRenderObject(BuildContext context) =>
      RenderBannerLayout(
        gap: gap,
        actionSpacing: actionSpacing,
        flow: flow,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBannerLayout renderObject,
  ) {
    renderObject
      ..gap = gap
      ..actionSpacing = actionSpacing
      ..flow = flow
      ..textDirection = Directionality.of(context);
  }
}

class RenderBannerLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<BannerSlot, RenderBox> {
  RenderBannerLayout({
    required double gap,
    required double actionSpacing,
    required BannerFlow flow,
    required TextDirection textDirection,
  }) : _gap = gap,
       _actionSpacing = actionSpacing,
       _flow = flow,
       _textDirection = textDirection;

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double get actionSpacing => _actionSpacing;
  double _actionSpacing;
  set actionSpacing(double value) {
    if (value == _actionSpacing) return;
    _actionSpacing = value;
    markNeedsLayout();
  }

  BannerFlow get flow => _flow;
  BannerFlow _flow;
  set flow(BannerFlow value) {
    if (value == _flow) return;
    _flow = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _line => childForSlot(BannerSlot.line)!;
  RenderBox? get _icon => childForSlot(BannerSlot.icon);
  RenderBox get _text => childForSlot(BannerSlot.text)!;
  RenderBox? get _actions => childForSlot(BannerSlot.actions);
  RenderBox? get _dismiss => childForSlot(BannerSlot.dismiss);

  /// The width the icon and the dismiss button take, gaps included.
  double _sides(double Function(RenderBox) width) =>
      (_icon == null ? 0 : width(_icon!) + gap) +
      (_dismiss == null ? 0 : width(_dismiss!) + gap);

  @override
  double computeMinIntrinsicWidth(double height) {
    // Stacked, the narrower of the text and the actions sets the column.
    final column = math.max(
      _text.getMinIntrinsicWidth(double.infinity),
      _actions?.getMinIntrinsicWidth(double.infinity) ?? 0,
    );
    return _sides((c) => c.getMaxIntrinsicWidth(double.infinity)) + column;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final actions = _actions;
    return _sides((c) => c.getMaxIntrinsicWidth(double.infinity)) +
        _text.getMaxIntrinsicWidth(double.infinity) +
        (actions == null
            ? 0
            : gap + actions.getMaxIntrinsicWidth(double.infinity));
  }

  /// A [ChildLayouter] that answers from a child's intrinsics, for this
  /// layout's own intrinsic heights: children that can't lay out dry (a
  /// `LayoutBuilder`) still answer them. A child takes its max intrinsic
  /// width up to the constraints, as text does, and [heightAt] that width.
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
    final distance = _text.getDryBaseline(layout.textConstraints, baseline);
    return distance == null ? null : distance + layout.textTop;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final text = _text;
    final distance = text.getDistanceToActualBaseline(baseline);
    if (distance == null) return null;
    return distance + (text.parentData! as BoxParentData).offset.dy;
  }

  @override
  void performLayout() {
    size = _compute(
      constraints,
      ChildLayoutHelper.layoutChild,
      place: true,
    ).size;
  }

  /// Lays the banner out with [layoutChild]: its size, and where the text
  /// goes (its constraints and its top) for the baseline. With [place], it
  /// also positions the children.
  ({Size size, BoxConstraints textConstraints, double textTop}) _compute(
    BoxConstraints constraints,
    ChildLayouter layoutChild, {
    bool place = false,
  }) {
    final icon = _icon;
    final text = _text;
    final actions = _actions;
    final dismiss = _dismiss;
    final bounded = constraints.hasBoundedWidth;
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);

    Size measure(RenderBox? child, BoxConstraints c) =>
        child == null ? Size.zero : layoutChild(child, c);

    final line = layoutChild(_line, loose).height;
    final iconSize = measure(icon, loose);
    final dismissSize = measure(dismiss, loose);
    final lead = icon == null ? 0.0 : iconSize.width + gap;
    final trail = dismiss == null ? 0.0 : dismissSize.width + gap;

    // The column between the icon and the dismiss button.
    final column = bounded
        ? math.max(0, constraints.maxWidth - lead - trail).toDouble()
        : double.infinity;
    final actionsSize = measure(actions, BoxConstraints(maxWidth: column));
    final beside = actions == null ? 0.0 : gap + actionsSize.width;
    final natural = layoutChild(text, BoxConstraints(maxWidth: column));
    final inline = flow == BannerFlow.auto && natural.width + beside <= column;

    final double width;
    final double height;
    final BoxConstraints textConstraints;
    final Size textSize;
    if (inline) {
      final textWidth = bounded ? column - beside : natural.width;
      textConstraints = BoxConstraints.tightFor(width: textWidth);
      textSize = layoutChild(text, textConstraints);
      width = bounded
          ? constraints.maxWidth
          : lead + textWidth + beside + trail;
      height = [
        iconSize.height,
        textSize.height,
        actionsSize.height,
        dismissSize.height,
      ].reduce(math.max);
    } else {
      final textWidth = bounded
          ? column
          : math.max(natural.width, actionsSize.width);
      textConstraints = BoxConstraints.tightFor(width: textWidth);
      textSize = layoutChild(text, textConstraints);
      width = bounded ? constraints.maxWidth : lead + textWidth + trail;
      // The icon and the dismiss button center on the first line; what
      // reaches below the text still counts.
      double below(Size child) => (line + child.height) / 2;
      height = math.max(
        math.max(below(iconSize), below(dismissSize)),
        textSize.height +
            (actions == null ? 0 : actionSpacing + actionsSize.height),
      );
    }
    final size = constraints.constrain(Size(width, height));
    double centered(Size child) =>
        inline ? (size.height - child.height) / 2 : 0;
    final result = (
      size: size,
      textConstraints: textConstraints,
      textTop: centered(textSize),
    );
    if (!place) return result;

    final rtl = textDirection == TextDirection.rtl;
    void put(RenderBox? child, Size childSize, double x, double y) {
      if (child == null) return;
      (child.parentData! as BoxParentData).offset = Offset(
        rtl ? size.width - x - childSize.width : x,
        y,
      );
    }

    // Stacked, a side part centers on the first line, so one taller than
    // the line (a 44 px dismiss target) starts above the layout's top.
    double onLine(Size child) =>
        inline ? centered(child) : (line - child.height) / 2;
    put(_line, Size(0, line), 0, 0);
    put(icon, iconSize, 0, onLine(iconSize));
    put(text, textSize, lead, result.textTop);
    put(
      actions,
      actionsSize,
      inline ? size.width - trail - actionsSize.width : lead,
      inline ? centered(actionsSize) : textSize.height + actionSpacing,
    );
    put(
      dismiss,
      dismissSize,
      size.width - dismissSize.width,
      onLine(dismissSize),
    );
    return result;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // The dismiss button may reach above the layout (see [_compute]); its
    // whole target still takes taps.
    final dismiss = _dismiss;
    if (dismiss != null && !size.contains(position)) {
      final offset = (dismiss.parentData! as BoxParentData).offset;
      if ((offset & dismiss.size).contains(position) &&
          hitTestChildren(result, position: position)) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    return super.hitTest(result, position: position);
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
