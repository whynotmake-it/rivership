import 'dart:async';
import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/calendar/calendar_layout.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The month view a calendar zooms out to: a vertical scroll of years, each
/// year's twelve months three across and four down, four rows to the year
/// and the viewport exactly one year tall. It scrolls like the days do, and
/// lands on a year boundary (`CalendarSnapPhysics`). The calendar's title
/// names the year, so the months take the room.
///
/// It opens on [month]'s year. Months outside [firstMonth] and [lastMonth]
/// are dimmed and can't be picked; the scroll ends at their years. The
/// month of [selected] is filled like a selected day, and this month is
/// semibold, like today. The keyboard's month, which the title zooms back
/// into, has the pressed wash while it isn't the selected one.
///
/// The view keeps a month the keyboard acts on (it starts on [month]) and
/// reports the month a calendar's title names with [onShown]: that month in
/// the year in the middle of the view, so it changes mid-scroll.
///
/// It's one focus stop: the arrows move a month (Up and Down a row of
/// three), PageUp and PageDown a year, Enter or Space picks, and Escape
/// calls [onClose]. A keyboard move into another year scrolls to it.
class CalendarMonthView extends StatefulWidget {
  /// Creates the month view.
  const CalendarMonthView({
    required this.month,
    required this.selected,
    required this.firstMonth,
    required this.lastMonth,
    required this.monthName,
    required this.monthLabel,
    required this.inset,
    required this.focusNode,
    required this.onPicked,
    required this.onShown,
    required this.onClose,
    super.key,
    this.motion,
  });

  /// The month the day grid shows: its year opens, and the keyboard starts
  /// on it.
  final DateTime month;

  /// The picked day, if any.
  final DateTime? selected;

  /// The earliest month that can be picked, or null.
  final DateTime? firstMonth;

  /// The latest month that can be picked, or null.
  final DateTime? lastMonth;

  /// A month's name in its cell, from 1 to 12.
  final Widget Function(int month) monthName;

  /// A month's name for screen readers.
  final String Function(DateTime month) monthLabel;

  /// The room for the focus ring on each side.
  final double inset;

  /// The focus node of the view's single focus stop.
  final FocusNode focusNode;

  /// Called with the month the user picks.
  final ValueChanged<DateTime> onPicked;

  /// Called with the month the title names when it changes: the
  /// keyboard's month in the year more than half in view.
  final ValueChanged<DateTime> onShown;

  /// Called on Escape.
  final VoidCallback onClose;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  State<CalendarMonthView> createState() => CalendarMonthViewState();
}

/// The state of a [CalendarMonthView]: a calendar's arrows scroll it a year
/// at a time with [turn].
class CalendarMonthViewState extends State<CalendarMonthView> {
  /// The month the keyboard acts on.
  late DateTime _cursor = _clamp(widget.month);

  /// The year in the middle of the view.
  late int _shownYear = _cursor.year;

  /// The height of a year: the view's, from the last layout.
  double _extent = 0;

  late final _snap = CalendarSnap(
    offsetOf: (index) => index * _extent,
    indexAt: (offset) =>
        _extent > 0 ? math.max(0, (offset / _extent + 1e-6).floor()) : 0,
  );
  late final _scroll = CalendarScrollController(
    snap: _snap,
    initialOffset: () => _pageOf(_cursor.year) * _extent,
  );
  final _active = CoilActiveItemController();

  int get _firstYear => widget.firstMonth?.year ?? 1;

  /// The last year; the years go on without a last month, as the days do.
  int? get _lastYear => widget.lastMonth?.year;

  bool _hasYear(int year) => year == _clampYear(year);

  int _clampYear(int year) {
    if (year < _firstYear) return _firstYear;
    if (_lastYear case final last? when year > last) return last;
    return year;
  }

  /// The index of [year]'s chunk.
  int _pageOf(int year) => year - _firstYear;

  @override
  void dispose() {
    _scroll.dispose();
    _active.dispose();
    super.dispose();
  }

  bool _enabled(DateTime month) {
    if (widget.firstMonth case final first? when month.isBefore(first)) {
      return false;
    }
    if (widget.lastMonth case final last? when month.isAfter(last)) {
      return false;
    }
    return true;
  }

  DateTime _clamp(DateTime month) {
    if (widget.firstMonth case final first? when month.isBefore(first)) {
      return first;
    }
    if (widget.lastMonth case final last? when month.isAfter(last)) {
      return last;
    }
    return month;
  }

  /// Scrolls by [years], taking the keyboard's month along: the calendar's
  /// arrows.
  void turn(int years) {
    final year = _shownYear + years;
    if (!_hasYear(year)) return;
    _active.clear();
    _setCursor(_clamp(DateTime(year, _cursor.month)));
  }

  void _move(int months) {
    final next = _clamp(DateTime(_cursor.year, _cursor.month + months));
    _setCursor(next);
    _active.activate(next.month - 1, via: CoilModality.keyboard);
  }

  /// Moves the keyboard's month to [month], scrolling to its year.
  void _setCursor(DateTime month) {
    setState(() => _cursor = month);
    if (month.year != _shownYear) {
      _shownYear = month.year;
      _turnTo(month.year);
    }
    widget.onShown(month);
  }

  /// Scrolls to [year]: on the `standard` spring to a neighbor, keeping the
  /// speed it's moving at, in one step (a cut) further away.
  void _turnTo(int year) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position as CalendarScrollPosition;
    final index = _pageOf(year);
    if ((index - _snap.nearestIndex(position.pixels)).abs() > 1) {
      position.jumpTo(_snap.offsetOf(index));
      return;
    }
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    position.glideTo(_snap.offsetOf(index), motion.standard);
  }

  /// The view moved: the title follows the year in the middle of it, and
  /// once it settles, the keyboard's month moves into that year.
  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (notification.depth != 0 ||
        metrics.axis != Axis.vertical ||
        _extent <= 0) {
      return false;
    }
    // The middle of the view is half a year down: its year is the nearest
    // boundary's.
    final year = _clampYear(_firstYear + _snap.nearestIndex(metrics.pixels));
    if (year != _shownYear) {
      _shownYear = year;
      widget.onShown(_clamp(DateTime(year, _cursor.month)));
    }
    if (notification is ScrollEndNotification && year != _cursor.year) {
      // A wheel's tick ends before the spring that follows it begins.
      final settled = _snap.nearestIndex(metrics.pixels);
      if ((metrics.pixels - _snap.offsetOf(settled)).abs() > 1) return false;
      setState(() => _cursor = _clamp(DateTime(year, _cursor.month)));
      _active.clear();
    }
    return false;
  }

  void _pick(DateTime month, {required bool touch}) {
    if (!_enabled(month)) return;
    if (touch) unawaited(CoilHaptics.play(context, CoilHapticEvent.pick));
    widget.onPicked(month);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    return Shortcuts(
      shortcuts: {
        SingleActivator(
          rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft,
        ): const _MoveIntent(
          -1,
        ),
        SingleActivator(
          rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
        ): const _MoveIntent(
          1,
        ),
        const SingleActivator(LogicalKeyboardKey.arrowUp): const _MoveIntent(
          -3,
        ),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const _MoveIntent(
          3,
        ),
        const SingleActivator(LogicalKeyboardKey.pageUp): const _MoveIntent(
          -12,
        ),
        const SingleActivator(LogicalKeyboardKey.pageDown): const _MoveIntent(
          12,
        ),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const _CloseIntent(),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (intent) => _move(intent.months),
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _pick(_cursor, touch: false),
          ),
          _CloseIntent: CallbackAction<_CloseIntent>(
            onInvoke: (_) => widget.onClose(),
          ),
        },
        child: Focus(
          focusNode: widget.focusNode,
          onFocusChange: (focused) {
            // The ring starts on the month the grid showed.
            if (focused &&
                CoilInputModality.instance.value == CoilModality.keyboard) {
              _active.activate(_cursor.month - 1, via: .keyboard);
            }
            setState(() {});
          },
          child: Semantics(
            container: true,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final extent = constraints.maxHeight;
                  if (_scroll.hasClients && _extent > 0 && extent != _extent) {
                    // Another height: the same year, the same place in it.
                    _scroll.position.correctPixels(
                      _scroll.position.pixels * extent / _extent,
                    );
                  }
                  _extent = extent;
                  _snap
                    ..motion = motion.standard
                    ..wheelThreshold = extent / 8;
                  // The view is exactly a year tall; each year clips
                  // itself (CalendarWindowClip), so the focus ring can
                  // reach out.
                  return CustomScrollView(
                    controller: _scroll,
                    clipBehavior: Clip.none,
                    scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                    // Hands drags off to a sheet it sits in.
                    scrollBehavior: CoilSheetRoute.scrollBehaviorOf(context),
                    physics: CalendarSnapPhysics(snap: _snap),
                    slivers: [
                      SliverFixedExtentList(
                        itemExtent: extent,
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _year(_firstYear + index),
                          childCount: switch (_lastYear) {
                            final last? => last - _firstYear + 1,
                            null => null,
                          },
                          addAutomaticKeepAlives: false,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [year]'s twelve months.
  Widget _year(int year) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final radius = theme.shape.radii(metrics.tier).item;
    final current = year == _cursor.year;
    final selected = widget.selected;
    final selectedIndex = selected != null && selected.year == year
        ? selected.month - 1
        : null;
    // Where the title zooms back into, when it isn't the selected month.
    final cursorIndex = current && _cursor.month - 1 != selectedIndex
        ? _cursor.month - 1
        : null;
    final now = DateTime.now();
    final grid = Column(
      children: [
        for (var row = 0; row < 4; row++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < 3; column++)
                  Expanded(
                    child: _cell(
                      DateTime(year, row * 3 + column + 1),
                      selected: selectedIndex == row * 3 + column,
                      thisMonth:
                          now.year == year && now.month == row * 3 + column + 1,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    final ring = current && widget.focusNode.hasFocus && _active.keyboardDriven;
    return CalendarWindowClip(
      controller: _scroll,
      offset: _pageOf(year) * _extent,
      height: _extent,
      bleed: ring ? widget.inset : 0,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.inset),
        child: CoilHoverRegion(
          axis: CoilHoverAxis.xy,
          activeItem: current ? _active : null,
          followFocus: false,
          child: ListenableBuilder(
            listenable: _active,
            builder: (context, child) => CoilHoverHighlight(
              radius: radius,
              motion: widget.motion,
              background: [
                CoilHighlight(
                  debugLabel: 'CalendarMonthView.cursor',
                  target: cursorIndex,
                  motion: motion.quick,
                  exitMotion: motion.fadeExit,
                  exitTravelMotion: motion.quick,
                  fade: motion.fade,
                  decoration: ShapeDecoration(
                    color: colors.active,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
                CoilHighlight(
                  debugLabel: 'CalendarMonthView.selected',
                  target: selectedIndex,
                  fadeIn: false,
                  motion: motion.standard,
                  exitMotion: motion.fadeExit,
                  exitTravelMotion: motion.standard,
                  fade: motion.fade,
                  decoration: ShapeDecoration(
                    color: colors.foreground,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
              ],
              foreground: [
                CoilHighlight(
                  debugLabel: 'CalendarMonthView.ring',
                  target:
                      current &&
                          widget.focusNode.hasFocus &&
                          _active.keyboardDriven
                      ? _active.index
                      : null,
                  fadeIn: false,
                  motion: motion.quick,
                  exitMotion: motion.fadeExit,
                  exitTravelMotion: motion.quick,
                  fade: motion.fade,
                  inflate: theme.focusRing.extent,
                  decoration: theme.focusRing.decorationAround(
                    colors,
                    radius: radius,
                  ),
                ),
              ],
              child: child!,
            ),
            child: grid,
          ),
        ),
      ),
    );
  }

  Widget _cell(
    DateTime month, {
    required bool selected,
    required bool thisMonth,
  }) {
    final enabled = _enabled(month);
    return _MonthCell(
      index: month.month - 1,
      label: widget.monthLabel(month),
      selected: selected,
      thisMonth: thisMonth,
      gap: CoilTheme.metricsOf(context).gap / 2,
      onPressed: enabled
          ? () => _pick(
              month,
              touch: !CoilInputModality.canHover(
                CoilInputModality.instance.lastPointerKind ??
                    PointerDeviceKind.touch,
              ),
            )
          : null,
      child: widget.monthName(month.month),
    );
  }
}

/// One month's cell: its name, semibold for this month and inverted when
/// selected. The layer paints the fills inside [gap] on each side; the
/// whole cell takes the tap.
class _MonthCell extends StatefulWidget {
  const _MonthCell({
    required this.index,
    required this.label,
    required this.selected,
    required this.thisMonth,
    required this.gap,
    required this.onPressed,
    required this.child,
  });

  final int index;
  final String label;
  final bool selected;
  final bool thisMonth;
  final double gap;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_MonthCell> createState() => _MonthCellState();
}

class _MonthCellState extends State<_MonthCell> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: CoilInteractionDetector(
        states: _states,
        enabled: enabled,
        onTap: widget.onPressed,
        excludeFromSemantics: true,
        child: Padding(
          padding: EdgeInsets.all(widget.gap),
          child: CoilHoverItem(
            index: widget.index,
            enabled: enabled,
            child: Opacity(
              opacity: enabled ? 1 : metrics.disabledOpacity,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: DefaultTextStyle(
                    maxLines: 1,
                    softWrap: false,
                    style: text.body.copyWith(
                      fontWeight: widget.thisMonth || widget.selected
                          ? text.emphasis
                          : text.body.fontWeight,
                      color: widget.selected
                          ? colors.background
                          : colors.foreground,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Moves the keyboard's month by [months].
class _MoveIntent extends Intent {
  const _MoveIntent(this.months);

  final int months;
}

/// Goes back to the day grid: Escape.
class _CloseIntent extends Intent {
  const _CloseIntent();
}
