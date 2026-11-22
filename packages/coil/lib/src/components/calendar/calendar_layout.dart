import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
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

/// [motion] as the spring a snap settles on: itself when it is one, else
/// (reduced motion) the stiff critically damped spring of
/// [calendarSnapSpring], so a snap still ends on a spring, not a cut.
Motion calendarSnapMotion(Motion motion) => switch (motion) {
  final SpringMotion spring => spring,
  _ => SpringMotion(calendarSnapSpring(motion)),
};

/// The boundaries a calendar's scroll view snaps to: the top of each month
/// (the days) or of each year (the month view), as a function of the index
/// of the chunk, plus the spring a snap settles on.
///
/// A scroll position keeps the physics it was created with, so the
/// calendar creates one snap and keeps it current (`motion`,
/// `wheelThreshold`, and the geometry its functions read) instead of
/// passing the physics new values.
class CalendarSnap {
  /// Creates the boundaries from [offsetOf] and [indexAt].
  CalendarSnap({required this.offsetOf, required this.indexAt});

  /// The scroll offset of chunk `index`'s top.
  final double Function(int index) offsetOf;

  /// The last chunk whose top is at or above `offset`; 0 before the first.
  final int Function(double offset) indexAt;

  /// The spring a snap settles on: the theme's `standard`.
  Motion motion = const Motion.instant();

  /// How far a mouse wheel has to move before it steps to the next
  /// boundary: half a row of cells. A notch is never less than a row (53 px
  /// at the least, a day row is 28 to 57), so every notch steps; the finer
  /// events of a smooth wheel add up to it.
  double wheelThreshold = 0;

  /// Closer than this, an offset is at a boundary: half a pixel.
  static const _epsilon = 0.5;

  /// The chunk whose top is nearest to [offset].
  int nearestIndex(double offset) {
    final index = indexAt(offset);
    return offset - offsetOf(index) <= offsetOf(index + 1) - offset
        ? index
        : index + 1;
  }

  /// The boundary nearest to [offset].
  double nearest(double offset) => offsetOf(nearestIndex(offset));

  /// The first boundary below [offset] (past it by more than a pixel).
  double after(double offset) {
    final index = indexAt(offset);
    final next = offsetOf(index + 1);
    return next - offset > _epsilon ? next : offsetOf(index + 2);
  }

  /// The last boundary above [offset] (before it by more than a pixel), or
  /// the first.
  double before(double offset) {
    final index = indexAt(offset);
    final at = offsetOf(index);
    return offset - at > _epsilon ? at : offsetOf(math.max(0, index - 1));
  }
}

/// Lands a vertical scroll view on a boundary of [snap], as the end of its
/// own momentum.
///
/// - **A fling** coasts on the platform's own friction: the parent physics'
///   simulation says where it would have stopped, and the boundary nearest
///   to that is where this one stops. It's the same curve aimed at the
///   boundary, an exponential decay `start + v/k · (1 − e^(−kt))` with
///   `k = v / (target − start)`: it leaves the finger at the release
///   velocity and stops on the boundary without a spring's tail.
/// - **Anything the decay wouldn't suit** springs there on the snap's
///   motion from the release velocity: a release in the middle of a chunk (no
///   velocity), a short fling that lands back where it began, a fling whose
///   nearest boundary is behind it, and a decay that would be unnaturally
///   slow or snappy. Reduced motion springs on a stiff critically damped
///   one ([calendarSnapMotion]); the coasting stays, as it's the user's own
///   momentum.
/// - **Overscroll** at either end is the parent's.
///
/// A mouse wheel doesn't come through here: see `CalendarScrollPosition`.
class CalendarSnapPhysics extends ScrollPhysics {
  /// Creates snapping physics onto [snap].
  const CalendarSnapPhysics({required this.snap, super.parent});

  /// The boundaries.
  final CalendarSnap snap;

  /// Slower than this, a decay takes more than 2.4 s to reach 95 %
  /// (`ln 20 / k`): the platform's friction takes about 1.5 s to, so this
  /// allows for 60 % of its pace; slower would hang. Per second.
  static const slowestDecay = 1.25;

  /// Quicker than this, a decay has gone 95 % of the way in 120 ms, which is
  /// a stop, not a coast: the spring does it better. Per second.
  static const quickestDecay = 25.0;

  /// The platform's friction, for a parent that gives no simulation:
  /// the drag of iOS's scroll view.
  static const _friction = 0.135;

  @override
  CalendarSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      CalendarSnapPhysics(snap: snap, parent: buildParent(ancestor));

  @override
  SpringDescription get spring => calendarSnapSpring(snap.motion);

  @override
  bool get allowImplicitScrolling => false;

  @override
  bool operator ==(Object other) =>
      other is CalendarSnapPhysics &&
      other.snap == snap &&
      other.parent == parent;

  @override
  int get hashCode => Object.hash(snap, parent);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Past either end, the platform's overscroll brings it back.
    if (position.outOfRange ||
        (velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final start = position.pixels;
    final fling =
        velocity.abs() >= math.max(tolerance.velocity, kMinFlingVelocity);

    // Where the platform's friction would have stopped it.
    var landing = start;
    if (fling) {
      final natural = parent?.createBallisticSimulation(position, velocity);
      // Evaluated far past its end: every platform simulation holds its
      // final position.
      landing =
          natural?.x(1000) ??
          FrictionSimulation(_friction, start, velocity).finalX;
    }
    final target = snap
        .nearest(landing)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    final distance = target - start;
    if (distance.abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }

    // A fling with a boundary ahead of it, by at least half a row (a
    // twelfth of the six rows in view), coasts to it.
    final ahead =
        distance * velocity > 0 &&
        distance.abs() > position.viewportDimension / 12;
    if (fling && ahead) {
      final decay = velocity / distance;
      if (decay >= slowestDecay && decay <= quickestDecay) {
        return _SnapDecay(
          start: start,
          velocity: velocity,
          decay: decay,
          target: target,
          tolerance: tolerance,
        );
      }
    }
    return calendarSnapMotion(snap.motion).createSimulation(
      start: start,
      end: target,
      velocity: velocity,
    );
  }
}

/// A fling's friction aimed at [target]: `x(t) = start + v/k · (1 − e^(−kt))`
/// with `k = decay = v / (target − start)`, so it starts at [velocity],
/// slows exponentially and stops on [target]. It is done, and exactly on
/// [target], once what's left is under half a pixel, where a platform scroll
/// view stops too: an exponential never arrives, and a scroll view ignores
/// taps on its content while it moves, so a longer tail would leave the days
/// untappable for seconds after a fling.
class _SnapDecay extends Simulation {
  _SnapDecay({
    required this.start,
    required this.velocity,
    required this.decay,
    required this.target,
    super.tolerance,
  }) : _end = math.log((target - start).abs() / _rest) / decay;

  final double start;
  final double velocity;
  final double decay;
  final double target;

  /// The distance left to the target at which the decay is done: less than
  /// a physical pixel on any screen, so the last step doesn't show.
  static const _rest = 0.5;

  /// When the decay is done.
  final double _end;

  @override
  double x(double time) => time >= _end
      ? target
      : start + velocity / decay * (1 - math.exp(-decay * time));

  @override
  double dx(double time) =>
      time >= _end ? 0 : velocity * math.exp(-decay * time);

  @override
  bool isDone(double time) => time >= _end;
}

/// The scroll controller of a calendar's vertical views: its positions snap
/// as [CalendarSnapPhysics] does, answer a mouse wheel and arrow buttons,
/// and start at [initialOffset], which it asks for when the view is first
/// laid out (a calendar's offsets depend on the width it's given).
class CalendarScrollController extends ScrollController {
  /// Creates a controller whose positions use [snap].
  CalendarScrollController({required this.snap, required this.initialOffset});

  /// The boundaries a position snaps to.
  final CalendarSnap snap;

  /// Where the view starts.
  final double Function() initialOffset;

  @override
  double get initialScrollOffset => initialOffset();

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => CalendarScrollPosition(
    snap: snap,
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

/// The scroll position of a calendar's vertical views.
///
/// **A mouse wheel** moves a calendar a month (or a year) per notch. Flutter
/// jumps by the wheel's delta and then calls [goBallistic] with no
/// velocity, which would spring to the nearest boundary: a notch is less
/// than half a month, so it would spring straight back. Here a wheel moves
/// the boundary it's heading for instead: from the one it started on, each
/// time the wheel has moved [CalendarSnap.wheelThreshold] the same way, it
/// steps to the next in that direction, then springs there on
/// [CalendarSnap.motion]. A following tick continues from where the
/// position is (Flutter stops the spring and jumps by the delta), with the
/// target kept, so ticks add up (two notches, two months) and a spring
/// that is half way never counts as a boundary passed. Finer events of a
/// smooth wheel add up to a step; less than one springs back.
class CalendarScrollPosition extends ScrollPositionWithSingleContext {
  /// Creates a position that snaps to [snap].
  CalendarScrollPosition({
    required this.snap,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.oldPosition,
    super.debugLabel,
  }) : super(keepScrollOffset: false);

  /// The boundaries.
  final CalendarSnap snap;

  /// Whether a wheel event is being handled.
  bool _wheel = false;

  /// The boundary the wheel is heading for, and what the wheel has moved
  /// towards the next one.
  double? _wheelTarget;
  double _wheelPending = 0;

  @override
  void pointerScroll(double delta) {
    if (delta == 0) {
      super.pointerScroll(delta);
      return;
    }
    final target = _wheelTarget ?? snap.nearest(pixels);
    if (_wheelPending * delta < 0) _wheelPending = 0;
    _wheelPending += delta;
    var next = target;
    if (_wheelPending.abs() >= snap.wheelThreshold) {
      next = delta > 0 ? snap.after(target) : snap.before(target);
      _wheelPending = 0;
    }
    _wheelTarget = next.clamp(minScrollExtent, maxScrollExtent);
    _wheel = true;
    try {
      super.pointerScroll(delta);
    } finally {
      _wheel = false;
    }
  }

  @override
  void goBallistic(double velocity) {
    if (_wheel && _wheelTarget != null) {
      glideTo(_wheelTarget!, snap.motion);
      return;
    }
    super.goBallistic(velocity);
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    // Whatever isn't the wheel's own moves ends its run.
    if (!_wheel) {
      _wheelTarget = null;
      _wheelPending = 0;
    }
    super.beginActivity(newActivity);
  }

  /// Animates to [target] on [motion], from the velocity the position has
  /// now, if something moves it: an arrow pressed in the middle of a snap
  /// carries the snap's speed on.
  void glideTo(double target, Motion motion) {
    final velocity = activity?.velocity ?? 0;
    beginActivity(
      BallisticScrollActivity(
        this,
        motion.createSimulation(start: pixels, end: target, velocity: velocity),
        context.vsync,
        false,
      ),
    );
  }
}

/// Clips one chunk of a calendar's scroll view to the window of rows in
/// view: [height] from the top of the box, wherever [controller] has
/// scrolled to, and nothing else of it.
///
/// A scroll view that clipped to its box would cut the focus ring around
/// the first and last rows, and one that clipped past it would show a
/// sliver of the row beyond each edge (a selected day's fill, with its
/// corners) above and below the grid at rest. So the view doesn't clip, and
/// each chunk does: to the window exactly, or [bleed] past it when the
/// ring is in this chunk, which is the only thing that reaches out of the
/// box. Rows scrolling out are cut at the box's edge, and what's cut is
/// also left out of semantics.
class CalendarWindowClip extends StatelessWidget {
  /// Clips [child], which begins [offset] into the list, to a window of
  /// [height] with [bleed] around it.
  const CalendarWindowClip({
    required this.controller,
    required this.offset,
    required this.height,
    required this.bleed,
    required this.child,
    super.key,
  });

  /// The scroll view's controller: where the window is.
  final ScrollController controller;

  /// How far into the list the chunk begins.
  final double offset;

  /// The window's height: the rows in view.
  final double height;

  /// How far past the window the chunk may paint: the focus ring's reach
  /// when the ring is in the chunk, else none.
  final double bleed;

  /// The chunk.
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    clipper: _WindowClipper(controller, offset, height, bleed),
    child: child,
  );
}

class _WindowClipper extends CustomClipper<Rect> {
  _WindowClipper(this.controller, this.offset, this.height, this.bleed)
    : super(reclip: controller);

  final ScrollController controller;
  final double offset;
  final double height;
  final double bleed;

  @override
  Rect getClip(Size size) {
    final pixels = controller.hasClients
        ? controller.position.pixels
        : controller.initialScrollOffset;
    final top = pixels - offset;
    return Rect.fromLTRB(0, top - bleed, size.width, top + height + bleed);
  }

  @override
  bool shouldReclip(_WindowClipper oldClipper) =>
      oldClipper.controller != controller ||
      oldClipper.offset != offset ||
      oldClipper.height != height ||
      oldClipper.bleed != bleed;
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
/// intrinsic sizes itself, so the scroll view inside (a viewport, which can't)
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
    // A calendar given its height (CalendarHeightBox) fills it: its rows
    // share it, and its days stay square in the middle of cells that are
    // wider than they are tall.
    final height = constraints.hasTightHeight
        ? constraints.maxHeight
        : _heightFor(width);
    return constraints.constrain(Size(width, height));
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

/// Tells a `CoilCalendar` below it that it is given its height (by a
/// [CalendarHeightBox]) and fills it, its rows sharing what the caption and
/// weekday row leave, instead of being as tall as square cells make it.
class CalendarFillsHeight extends InheritedWidget {
  /// Marks [child]'s calendar as sized from its height.
  const CalendarFillsHeight({required super.child, super.key});

  /// Whether the calendar at [context] is sized from its height.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CalendarFillsHeight>() != null;

  @override
  bool updateShouldNotify(CalendarFillsHeight oldWidget) => false;
}

/// Sizes a calendar from the [height] it has: its caption, weekday row and
/// six weeks fill exactly [height] (and a little more only where the days
/// would otherwise get smaller than [minCell]).
///
/// Its width follows from the rows. Where the width is plentiful the
/// columns are wider than the rows are tall, up to a day's natural side
/// ([natural] is seven of them and the insets), but never more than the
/// parent allows; the days themselves stay square, centered in their
/// cells. Past [max] the days stop growing.
///
/// A phone in landscape has height to spare for nothing, and width to
/// spare for the time beside the calendar: the calendar takes the height
/// and as much width as the rest leaves it.
class CalendarHeightBox extends SingleChildRenderObjectWidget {
  /// Sizes [child] to [height].
  const CalendarHeightBox({
    required this.height,
    required this.natural,
    required this.inset,
    required this.minCell,
    required this.max,
    super.key,
    super.child,
  });

  /// The height the calendar fills.
  final double height;

  /// The width of seven days of their natural side, with the insets.
  final double natural;

  /// The room for the focus ring on each side.
  final double inset;

  /// The smallest a row gets before the box is taller than [height].
  final double minCell;

  /// The widest the calendar grows.
  final double max;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCalendarHeightBox(height, natural, inset, minCell, max);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarHeightBox renderObject,
  ) => renderObject
    ..height = height
    ..natural = natural
    ..inset = inset
    ..minCell = minCell
    ..max = max;
}

/// The render object of a [CalendarHeightBox].
class RenderCalendarHeightBox extends RenderShiftedBox {
  /// Creates the box filling [height] with a calendar.
  RenderCalendarHeightBox(
    this._height,
    this._natural,
    this._inset,
    this._minCell,
    this._max,
  ) : super(null);

  double _height;
  double _natural;
  double _inset;
  double _minCell;
  double _max;

  /// The height the calendar fills.
  double get height => _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  /// The width of seven natural days with the insets.
  double get natural => _natural;
  set natural(double value) {
    if (value == _natural) return;
    _natural = value;
    markNeedsLayout();
  }

  /// The room for the focus ring on each side.
  double get inset => _inset;
  set inset(double value) {
    if (value == _inset) return;
    _inset = value;
    markNeedsLayout();
  }

  /// The smallest a row gets.
  double get minCell => _minCell;
  set minCell(double value) {
    if (value == _minCell) return;
    _minCell = value;
    markNeedsLayout();
  }

  /// The widest the calendar grows.
  double get max => _max;
  set max(double value) {
    if (value == _max) return;
    _max = value;
    markNeedsLayout();
  }

  /// A row's height when the calendar is [height] tall: what the caption
  /// and weekday row leave, measured on the child, over six.
  double _row() {
    final child = this.child;
    if (child == null) return minCell;
    final measured = child.getMaxIntrinsicHeight(natural);
    final chrome = measured - (natural - inset * 2) * 6 / 7;
    return math.max(minCell, (height - chrome) / 6);
  }

  /// The height the box takes: [height], or more where rows hit [minCell].
  double _boxHeight(double row) {
    final child = this.child;
    if (child == null) return height;
    final measured = child.getMaxIntrinsicHeight(natural);
    final chrome = measured - (natural - inset * 2) * 6 / 7;
    return math.max(height, chrome + row * 6);
  }

  /// The width: square days of the row's height, or wider columns where
  /// [available] allows, up to the natural side.
  double _width(double row, double available) {
    final square = (row * 7 + inset * 2).clamp(0.0, max);
    final wide = math.min(available, math.max(natural, square));
    return math.max(square, wide);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _width(_row(), double.negativeInfinity);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _width(_row(), double.negativeInfinity);

  @override
  double computeMinIntrinsicHeight(double width) => _boxHeight(_row());

  @override
  double computeMaxIntrinsicHeight(double width) => _boxHeight(_row());

  BoxConstraints _childConstraints(BoxConstraints constraints) {
    final row = _row();
    return BoxConstraints.tightFor(
      width: _width(row, constraints.maxWidth),
      height: _boxHeight(row),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(
      child.getDryLayout(_childConstraints(constraints)),
    );
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
    (child.parentData! as BoxParentData).offset = Offset.zero;
  }
}
