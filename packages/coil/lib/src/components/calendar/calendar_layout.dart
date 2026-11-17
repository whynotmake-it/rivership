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

/// Sizes a calendar's six weeks of [cell]-sized days: as wide as it's
/// given (seven cells when unbounded) and as tall as six rows of square
/// cells, at most [cell] each. It answers intrinsic sizes itself, so the
/// pager inside (a viewport, which can't) fits in a popover that hugs its
/// content.
class CalendarGridBox extends SingleChildRenderObjectWidget {
  /// Sizes [child] as a calendar grid of [cell]-sized days.
  const CalendarGridBox({required this.cell, super.key, super.child});

  /// The natural side of a day.
  final double cell;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCalendarGridBox(cell);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarGridBox renderObject,
  ) => renderObject.cell = cell;
}

/// The render object of a [CalendarGridBox].
class RenderCalendarGridBox extends RenderProxyBox {
  /// Creates the box for [cell]-sized days.
  RenderCalendarGridBox(this._cell);

  /// The natural side of a day.
  double get cell => _cell;
  double _cell;
  set cell(double value) {
    if (value == _cell) return;
    _cell = value;
    markNeedsLayout();
  }

  double _heightFor(double width) =>
      width.isFinite ? math.min(cell * 6, width * 6 / 7) : cell * 6;

  @override
  double computeMinIntrinsicWidth(double height) => cell * 7;

  @override
  double computeMaxIntrinsicWidth(double height) => cell * 7;

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(cell * 7);
    return constraints.constrain(Size(width, _heightFor(width)));
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}
