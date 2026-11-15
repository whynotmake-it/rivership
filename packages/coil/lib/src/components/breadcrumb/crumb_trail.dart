import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How a [CrumbTrail] hides middle crumbs.
enum CrumbCollapse {
  /// Only when the row doesn't fit, as few as needed.
  overflow,

  /// Always, down to the first crumb, "…" and the last two (phones).
  always,
}

/// What the last layout of a [CrumbTrail] hid, read when "…" is pressed.
class CrumbTrailHandle {
  /// The number of hidden crumbs, counted from the second.
  int hidden = 0;
}

/// Lays out a breadcrumb in one row and decides in that same layout pass
/// which middle crumbs fit.
///
/// [children] are the "…" crumb first, then the crumbs in order (the
/// current page last). [gates] holds one focus node per child, wrapping it
/// with `Focus.withExternalFocusNode`. A hidden child (and "…" while
/// nothing is hidden) is laid out at zero size and skipped by paint, hit
/// testing and semantics; its gate stops focus from reaching it.
///
/// When even the shortest trail is too wide, the longest labels truncate
/// first. Hidden crumbs start at the second, so the first crumb, the
/// last link and the page always show.
class CrumbTrail extends MultiChildRenderObjectWidget {
  /// Creates the trail.
  const CrumbTrail({
    required this.collapse,
    required this.handle,
    required this.gates,
    required super.children,
    super.key,
  });

  /// When to hide middle crumbs.
  final CrumbCollapse collapse;

  /// Receives the number of hidden crumbs on every layout.
  final CrumbTrailHandle handle;

  /// One focus node per child, in [children] order.
  final List<FocusNode> gates;

  @override
  RenderCrumbTrail createRenderObject(BuildContext context) => RenderCrumbTrail(
    collapse: collapse,
    handle: handle,
    gates: gates,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderCrumbTrail renderObject) {
    renderObject
      ..collapse = collapse
      ..handle = handle
      ..gates = gates
      ..textDirection = Directionality.of(context);
  }
}

/// The parent data of a [RenderCrumbTrail] child.
class CrumbTrailParentData extends ContainerBoxParentData<RenderBox> {
  /// Whether the child showed in the last layout.
  bool shown = true;
}

/// The render object of [CrumbTrail].
class RenderCrumbTrail extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CrumbTrailParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CrumbTrailParentData> {
  /// Creates the render object.
  RenderCrumbTrail({
    required this._collapse,
    required this.handle,
    required this.gates,
    required this._textDirection,
  });

  /// Receives the number of hidden crumbs.
  CrumbTrailHandle handle;

  /// One focus node per child.
  List<FocusNode> gates;

  /// When to hide middle crumbs.
  CrumbCollapse get collapse => _collapse;
  CrumbCollapse _collapse;
  set collapse(CrumbCollapse value) {
    if (value == _collapse) return;
    _collapse = value;
    markNeedsLayout();
  }

  /// The reading direction of the row.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CrumbTrailParentData) {
      child.parentData = CrumbTrailParentData();
    }
  }

  List<RenderBox> get _children => getChildrenAsList();

  static double _natural(RenderBox child) =>
      child.getMaxIntrinsicWidth(double.infinity);

  /// How many crumbs to hide (from the second on) so the row fits in
  /// [maxWidth], given the "…" crumb's natural width.
  int _hiddenFor(double maxWidth, double ellipsis, List<double> widths) {
    final n = widths.length;
    final most = math.max(0, n - 3);
    if (collapse == CrumbCollapse.always) return most;
    if (widths.fold<double>(0, (a, b) => a + b) <= maxWidth) return 0;
    for (var hidden = 1; hidden < most; hidden++) {
      var total = widths.first + ellipsis;
      for (var i = hidden + 1; i < n; i++) {
        total += widths[i];
      }
      if (total <= maxWidth) return hidden;
    }
    return most;
  }

  /// The children that show, in order, for [hidden] hidden crumbs.
  List<RenderBox> _shown(List<RenderBox> all, int hidden) {
    final crumbs = all.skip(1).toList();
    if (crumbs.isEmpty) return const [];
    return [
      crumbs.first,
      if (hidden > 0) all.first,
      ...crumbs.skip(hidden + 1),
    ];
  }

  /// The widths the shown children get: their natural widths if they fit,
  /// else every child wider than a common cap is cut to it, with the cap
  /// chosen so the row fills [maxWidth]. Long labels truncate first and
  /// short ones keep their full text.
  List<double> _widths(List<RenderBox> shown, double maxWidth) {
    final natural = [for (final c in shown) _natural(c)];
    final total = natural.fold<double>(0, (a, b) => a + b);
    if (!maxWidth.isFinite || total <= maxWidth) return natural;
    final sorted = [...natural]..sort();
    var left = maxWidth;
    var cap = 0.0;
    for (final (i, w) in sorted.indexed) {
      final share = left / (sorted.length - i);
      if (w > share) {
        cap = share;
        break;
      }
      left -= w;
      cap = w;
    }
    return [for (final w in natural) math.min(w, cap)];
  }

  @override
  void performLayout() {
    final all = _children;
    final maxWidth = constraints.maxWidth;
    final crumbWidths = [for (final c in all.skip(1)) _natural(c)];
    final hidden = all.isEmpty
        ? 0
        : _hiddenFor(maxWidth, _natural(all.first), crumbWidths);
    if (hidden != handle.hidden) {
      handle.hidden = hidden;
      markNeedsSemanticsUpdate();
    }
    final shown = _shown(all, hidden);
    final widths = _widths(shown, maxWidth);

    var height = 0.0;
    for (final (i, child) in shown.indexed) {
      child.layout(
        BoxConstraints(maxWidth: widths[i], maxHeight: constraints.maxHeight),
        parentUsesSize: true,
      );
      height = math.max(height, child.size.height);
    }
    final shownSet = shown.toSet();
    for (final (i, child) in all.indexed) {
      final data = child.parentData! as CrumbTrailParentData
        ..shown = shownSet.contains(child);
      if (!data.shown) {
        child.layout(const BoxConstraints.tightFor(width: 0, height: 0));
        data.offset = Offset.zero;
      }
      // Hidden crumbs leave focus traversal; one that held focus loses it.
      if (i < gates.length) {
        gates[i]
          ..descendantsAreFocusable = data.shown
          ..descendantsAreTraversable = data.shown;
      }
    }

    height = math.max(height, constraints.minHeight);
    final total = shown.fold<double>(0, (sum, c) => sum + c.size.width);
    size = constraints.constrain(Size(total, height));
    final rtl = textDirection == TextDirection.rtl;
    var x = rtl ? size.width : 0.0;
    for (final child in shown) {
      final w = child.size.width;
      if (rtl) x -= w;
      (child.parentData! as CrumbTrailParentData).offset = Offset(
        x,
        (size.height - child.size.height) / 2,
      );
      if (!rtl) x += w;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final all = _children;
    if (all.isEmpty) return constraints.smallest;
    final crumbWidths = [for (final c in all.skip(1)) _natural(c)];
    final hidden = _hiddenFor(
      constraints.maxWidth,
      _natural(all.first),
      crumbWidths,
    );
    final shown = _shown(all, hidden);
    final widths = _widths(shown, constraints.maxWidth);
    var height = 0.0;
    var width = 0.0;
    for (final (i, child) in shown.indexed) {
      final size = child.getDryLayout(
        BoxConstraints(maxWidth: widths[i], maxHeight: constraints.maxHeight),
      );
      height = math.max(height, size.height);
      width += size.width;
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final all = _children;
    if (all.length < 2) return 0;
    // The first crumb and "…": the page may shrink to nothing.
    return all[1].getMinIntrinsicWidth(height) +
        all.first.getMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) => _children
      .skip(1)
      .fold<double>(0, (sum, c) => sum + c.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) => _children.fold<double>(
    0,
    (h, c) => math.max(h, c.getMinIntrinsicHeight(double.infinity)),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _children.fold<double>(
    0,
    (h, c) => math.max(h, c.getMaxIntrinsicHeight(double.infinity)),
  );

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    double? result;
    for (final child in _children) {
      final data = child.parentData! as CrumbTrailParentData;
      if (!data.shown) continue;
      final distance = child.getDistanceToActualBaseline(baseline);
      if (distance == null) continue;
      final value = distance + data.offset.dy;
      result = result == null ? value : math.min(result, value);
    }
    return result;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _children.reversed) {
      final data = child.parentData! as CrumbTrailParentData;
      if (!data.shown) continue;
      final hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _children) {
      final data = child.parentData! as CrumbTrailParentData;
      if (data.shown) context.paintChild(child, data.offset + offset);
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final child in _children) {
      if ((child.parentData! as CrumbTrailParentData).shown) visitor(child);
    }
  }
}
