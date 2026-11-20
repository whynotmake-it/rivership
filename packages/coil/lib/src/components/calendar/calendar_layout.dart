import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The side of a calendar cell or a time row for [style] at [context]:
/// the control height, grown by as much as the text scale grows the line
/// box. The padding around the line stays the same, as gaps don't scale.
double calendarCellExtent(
  BuildContext context,
  CoilMetrics metrics,
  TextStyle style,
) {
  final fontSize = style.fontSize ?? 14;
  final scaled =
      MediaQuery.textScalerOf(context).scale(fontSize) * (style.height ?? 1);
  return math.max(
    metrics.controlHeight,
    metrics.controlHeight - style.lineHeight + scaled,
  );
}

/// The spring a scroll view snaps with: [motion]'s, or a stiff critically
/// damped one when [motion] isn't a spring (reduced motion).
SpringDescription calendarSnapSpring(Motion motion) => switch (motion) {
  final SpringMotion spring => spring.description,
  _ => SpringDescription.withDampingRatio(mass: 1, stiffness: 4000),
};

/// Pages a horizontal pager one page per swipe on [motion], keeping the
/// fling's velocity. A swipe past half a page, or a fling either way, turns
/// the page; anything less springs back.
class CalendarPagePhysics extends ScrollPhysics {
  /// Creates paging physics on [motion].
  const CalendarPagePhysics({required this.motion, super.parent});

  /// The spring the page settles with.
  final Motion motion;

  @override
  CalendarPagePhysics applyTo(ScrollPhysics? ancestor) =>
      CalendarPagePhysics(motion: motion, parent: buildParent(ancestor));

  @override
  SpringDescription get spring => calendarSnapSpring(motion);

  @override
  bool get allowImplicitScrolling => false;

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Past either end, the platform's overscroll brings it back.
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final extent = position.viewportDimension;
    if (extent <= 0) return null;
    final tolerance = toleranceFor(position);
    var page = position.pixels / extent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    final target = (page.roundToDouble() * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    return motion.createSimulation(
      start: position.pixels,
      end: target,
      velocity: velocity,
    );
  }
}

/// Snaps a wheel of fixed-extent rows to a row, landing with the fling's
/// momentum and springing back on [motion].
class CalendarWheelPhysics extends FixedExtentScrollPhysics {
  /// Creates wheel physics on [motion].
  const CalendarWheelPhysics({required this.motion, super.parent});

  /// The spring a row settles with.
  final Motion motion;

  @override
  CalendarWheelPhysics applyTo(ScrollPhysics? ancestor) =>
      CalendarWheelPhysics(motion: motion, parent: buildParent(ancestor));

  @override
  SpringDescription get spring => calendarSnapSpring(motion);
}

/// The height of a time column's row for [style] at [context]: the line
/// box grown with the text scale, and the tier's gap around it. Tighter
/// than a control (28 pointer, 34 touch at 1×): the column, not a row, is
/// the touch target.
double calendarTimeRowExtent(
  BuildContext context,
  CoilMetrics metrics,
  TextStyle style,
) {
  final fontSize = style.fontSize ?? 14;
  final line =
      MediaQuery.textScalerOf(context).scale(fontSize) * (style.height ?? 1);
  return (line + metrics.gap).roundToDouble();
}

/// How much bigger than its natural side a day may grow when the calendar
/// is given more room than seven cells (a sheet): 30 %, so a sheet fills
/// with it on phones up to the widest (430); a wider sheet centers the
/// calendar rather than stretch it.
const calendarMaxCellScale = 1.3;

/// A calendar's widths at [context]: the natural side of a day (`cell`),
/// the room for the focus ring on each side (`inset`), seven cells and the
/// insets (`natural`), and the widest it grows (`max`, seven cells of
/// `cell` × [calendarMaxCellScale]).
({double cell, double inset, double natural, double max}) calendarWidths(
  BuildContext context,
) {
  final metrics = CoilTheme.metricsOf(context);
  final cell = calendarCellExtent(
    context,
    metrics,
    CoilTheme.textOf(context).body,
  );
  final inset = CoilTheme.of(context).focusRing.extent;
  return (
    cell: cell,
    inset: inset,
    natural: cell * 7 + inset * 2,
    max: cell * calendarMaxCellScale * 7 + inset * 2,
  );
}

/// Sizes a calendar's six weeks: as wide as it's given (seven [cell]s and
/// the insets when unbounded) and six rows as tall as the columns inside
/// [inset] on each side are wide, so every day is square. It answers
/// intrinsic sizes itself, so the pager inside (a viewport, which can't)
/// fits in a popover that hugs its content.
class CalendarGridBox extends SingleChildRenderObjectWidget {
  /// Sizes [child] as a calendar grid of [cell]-sized days.
  const CalendarGridBox({
    required this.cell,
    super.key,
    this.inset = 0,
    super.child,
  });

  /// The natural side of a day.
  final double cell;

  /// The horizontal space on each side that isn't cells.
  final double inset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCalendarGridBox(cell, inset);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarGridBox renderObject,
  ) => renderObject
    ..cell = cell
    ..inset = inset;
}

/// The render object of a [CalendarGridBox].
class RenderCalendarGridBox extends RenderProxyBox {
  /// Creates the box for [cell]-sized days with [inset] on each side.
  RenderCalendarGridBox(this._cell, this._inset);

  /// The natural side of a day.
  double get cell => _cell;
  double _cell;
  set cell(double value) {
    if (value == _cell) return;
    _cell = value;
    markNeedsLayout();
  }

  /// The horizontal space on each side that isn't cells.
  double get inset => _inset;
  double _inset;
  set inset(double value) {
    if (value == _inset) return;
    _inset = value;
    markNeedsLayout();
  }

  double get _naturalWidth => cell * 7 + inset * 2;

  /// Six rows of cells as tall as the columns inside the insets are wide.
  double _heightFor(double width) =>
      width.isFinite ? math.max(0, width - inset * 2) * 6 / 7 : cell * 6;

  @override
  double computeMinIntrinsicWidth(double height) => _naturalWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(_naturalWidth);
    return constraints.constrain(Size(width, _heightFor(width)));
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}

/// Hands a hit in the [inset] at either side of [child] (room for the
/// focus ring, not a day) to the nearest day, so every point of the grid
/// picks one.
class CalendarInsetHit extends SingleChildRenderObjectWidget {
  /// Moves hits in [inset] onto the edge columns of [child].
  const CalendarInsetHit({required this.inset, super.key, super.child});

  /// The horizontal space on each side that isn't cells.
  final double inset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCalendarInsetHit(inset);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarInsetHit renderObject,
  ) => renderObject.inset = inset;
}

/// The render object of a [CalendarInsetHit].
class RenderCalendarInsetHit extends RenderProxyBox {
  /// Creates the box that moves hits in [inset] onto its child's cells.
  RenderCalendarInsetHit(this.inset);

  /// The horizontal space on each side that isn't cells.
  double inset;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    // Half a pixel inside the edge columns.
    final left = inset + 0.5;
    final right = math.max(left, size.width - inset - 0.5);
    final inside = Offset(position.dx.clamp(left, right), position.dy);
    if (hitTestChildren(result, position: inside)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// Gives [child] (a calendar, or a calendar and its time columns) its
/// width: [natural] when the parent lets it choose; more when the parent
/// asks for more (a sheet's stretch), up to [max]; less when that's all
/// there is. Past [max], [child] centers in the width it's asked to fill.
class CalendarWidthBox extends SingleChildRenderObjectWidget {
  /// Sizes [child] between [natural] and [max].
  const CalendarWidthBox({
    required this.natural,
    required this.max,
    super.key,
    super.child,
  });

  /// The width when the calendar can choose.
  final double natural;

  /// The widest the calendar grows.
  final double max;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCalendarWidthBox(natural, max);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarWidthBox renderObject,
  ) => renderObject
    ..natural = natural
    ..max = max;
}

/// The render object of a [CalendarWidthBox].
class RenderCalendarWidthBox extends RenderShiftedBox {
  /// Creates the box sizing its child between [natural] and [max].
  RenderCalendarWidthBox(this._natural, this._max) : super(null);

  /// The width when the calendar can choose.
  double get natural => _natural;
  double _natural;
  set natural(double value) {
    if (value == _natural) return;
    _natural = value;
    markNeedsLayout();
  }

  /// The widest the calendar grows.
  double get max => _max;
  double _max;
  set max(double value) {
    if (value == _max) return;
    _max = value;
    markNeedsLayout();
  }

  /// The child's width in [constraints].
  double _childWidth(BoxConstraints constraints) {
    if (constraints.minWidth > natural) {
      return math.min(constraints.minWidth, math.max(natural, max));
    }
    return constraints.constrainWidth(natural);
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      BoxConstraints.tightFor(
        width: _childWidth(constraints),
      ).enforce(constraints.loosen().copyWith(minWidth: 0));

  @override
  double computeMinIntrinsicWidth(double height) => natural;

  @override
  double computeMaxIntrinsicWidth(double height) => natural;

  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(
        _childWidth(BoxConstraints(minWidth: width, maxWidth: width)),
      ) ??
      0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(
        _childWidth(BoxConstraints(minWidth: width, maxWidth: width)),
      ) ??
      0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final childSize = child.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(childSize);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
    (child.parentData! as BoxParentData).offset = Offset(
      (size.width - child.size.width) / 2,
      (size.height - child.size.height) / 2,
    );
  }
}

/// Clips a calendar's pager to its width, so the pages beside the shown
/// one stay hidden, but lets the focus ring around the top and bottom rows
/// paint [bleed] above and below it. Give the pager `Clip.none`.
class CalendarPagerClip extends StatelessWidget {
  /// Clips [child] sideways only, with [bleed] of room above and below.
  const CalendarPagerClip({
    required this.bleed,
    required this.child,
    super.key,
  });

  /// How far the focus ring reaches outside the rows.
  final double bleed;

  /// The pager.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ClipRect(clipper: _PagerClipper(bleed), child: child);
}

class _PagerClipper extends CustomClipper<Rect> {
  const _PagerClipper(this.bleed);

  final double bleed;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -bleed, size.width, size.height + bleed);

  @override
  bool shouldReclip(_PagerClipper oldClipper) => oldClipper.bleed != bleed;
}
