import 'dart:async';

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/calendar/calendar_layout.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What a [CoilCalendar] (and a `CoilDatePicker`) shows and announces.
/// English by default.
///
/// The builders return what's shown, usually a [Text] that the calendar
/// styles. The `*Label` functions and strings are for screen readers.
@immutable
class CoilCalendarLabels {
  /// Creates calendar labels.
  const CoilCalendarLabels({
    this.monthTitle = _monthTitle,
    this.weekday = _weekday,
    this.date = _date,
    this.dateLabel = _dateLabel,
    this.dayLabel = _dayLabel,
    this.previousMonthLabel = 'Previous month',
    this.nextMonthLabel = 'Next month',
  });

  /// The month title, like "November 2026". It's announced as the month
  /// changes.
  final Widget Function(DateTime month) monthTitle;

  /// A weekday's column heading, like "Mo", from [DateTime.weekday].
  final Widget Function(int weekday) weekday;

  /// A picked date in a date picker's trigger, like "November 14, 2026",
  /// with the time when the picker picks one.
  final Widget Function(DateTime value, {required bool withTime}) date;

  /// [date] for screen readers.
  final String Function(DateTime value, {required bool withTime}) dateLabel;

  /// A day's name for screen readers, like "Saturday, November 14, 2026".
  final String Function(DateTime day) dayLabel;

  /// The previous-month button's label for screen readers.
  final String previousMonthLabel;

  /// The next-month button's label for screen readers.
  final String nextMonthLabel;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
    'Sunday',
  ];

  static Widget _monthTitle(DateTime month) =>
      Text('${_months[month.month - 1]} ${month.year}');

  static Widget _weekday(int weekday) =>
      Text(_weekdays[weekday - 1].substring(0, 2));

  static Widget _date(DateTime value, {required bool withTime}) =>
      Text(_dateLabel(value, withTime: withTime));

  static String _dateLabel(DateTime value, {required bool withTime}) {
    final date = '${_months[value.month - 1]} ${value.day}, ${value.year}';
    if (!withTime) return date;
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$date, $hour:$minute';
  }

  static String _dayLabel(DateTime day) =>
      '${_weekdays[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day}, '
      '${day.year}';
}

/// A month of days to pick one from.
///
/// A hovering pointer lights days with a gliding highlight, and the picked
/// day's fill glides to the next pick. On touch, the months page
/// horizontally under the finger and settle on the theme's `standard`
/// spring with the fling's velocity; a trackpad's horizontal scroll pages
/// too. The arrow buttons turn the page on any device.
///
/// The grid is one focus stop: the arrows move a day or a week, Home and
/// End go to the week's ends, PageUp and PageDown change the month (with
/// Shift, the year), and Enter or Space picks. Moving past the month turns
/// the page.
///
/// Cells are square, as tall as the tier's control height and grown with
/// the text scale. The calendar is seven cells wide when it can choose,
/// fills a wider space it's given (a sheet on a phone), and shares a
/// narrower one, shrinking the numbers if they don't fit.
///
/// Days before [firstDate], after [lastDate] or for which [isDisabled]
/// returns true can't be picked. Dates are compared by day; their time is
/// ignored.
class CoilCalendar extends StatefulWidget {
  /// Creates a calendar.
  const CoilCalendar({
    required this.selected,
    required this.onSelected,
    super.key,
    this.initialMonth,
    this.firstDate,
    this.lastDate,
    this.isDisabled,
    this.firstDayOfWeek = DateTime.monday,
    this.labels = const CoilCalendarLabels(),
    this.autofocus = false,
    this.motion,
  }) : assert(
         firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday,
         'firstDayOfWeek must be DateTime.monday to DateTime.sunday.',
       );

  /// The picked day, or null.
  final DateTime? selected;

  /// Called with the day the user picks. Null disables the calendar.
  final ValueChanged<DateTime>? onSelected;

  /// The month shown first; the selected day's month, or today's, if null.
  final DateTime? initialMonth;

  /// The earliest day that can be picked.
  final DateTime? firstDate;

  /// The latest day that can be picked.
  final DateTime? lastDate;

  /// Returns true for days that can't be picked.
  final bool Function(DateTime day)? isDisabled;

  /// The weekday the rows start on, [DateTime.monday] to [DateTime.sunday].
  final int firstDayOfWeek;

  /// Month and weekday names.
  final CoilCalendarLabels labels;

  /// Whether the grid takes focus when first built.
  final bool autofocus;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  State<CoilCalendar> createState() => _CoilCalendarState();
}

/// The day of [date], at midnight.
DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

bool _sameDay(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

/// The earliest month the pager can reach without a `firstDate`.
final _earliest = DateTime(1);

class _CoilCalendarState extends State<CoilCalendar> {
  /// The month the pager shows, or is turning to.
  late DateTime _month = _clamp(
    _monthOf(widget.initialMonth ?? widget.selected ?? DateTime.now()),
  );

  /// The month on page 0.
  late DateTime _base = _firstMonth;

  late PageController _pages = PageController(initialPage: _pageOf(_month));
  final _active = CoilActiveItemController();
  final _focus = FocusNode(debugLabel: 'CoilCalendar');

  DateTime get _firstMonth => switch (widget.firstDate) {
    final first? => _monthOf(first),
    null => _earliest,
  };

  int _pageOf(DateTime month) =>
      (month.year - _base.year) * 12 + month.month - _base.month;

  DateTime _monthAt(int page) => DateTime(_base.year, _base.month + page);

  int? get _pageCount => switch (widget.lastDate) {
    final last? => _pageOf(_monthOf(last)) + 1,
    null => null,
  };

  @override
  void didUpdateWidget(CoilCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final month = _clamp(_month);
    if (_firstMonth != _base) {
      // Page 0 moved: start a pager on the same month.
      _base = _firstMonth;
      final old = _pages;
      _pages = PageController(initialPage: _pageOf(month));
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    } else if (month != _month) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(_pageOf(_month));
      });
    }
    _month = month;
  }

  @override
  void dispose() {
    _pages.dispose();
    _active.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// How many days of the previous month lead [month]'s grid.
  int _lead(DateTime month) => (month.weekday - widget.firstDayOfWeek) % 7;

  /// The day in cell [index] of [month]'s 6-week grid.
  DateTime _cell(DateTime month, int index) =>
      DateTime(month.year, month.month, 1 - _lead(month) + index);

  int _indexOf(DateTime month, DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(month.year, month.month, 1 - _lead(month))).inDays;

  bool _enabled(DateTime day) {
    if (widget.onSelected == null) return false;
    if (widget.firstDate case final first?
        when _day(day).isBefore(_day(first))) {
      return false;
    }
    if (widget.lastDate case final last? when _day(day).isAfter(_day(last))) {
      return false;
    }
    return !(widget.isDisabled?.call(day) ?? false);
  }

  bool _canShow(DateTime month) {
    if (widget.firstDate case final first?
        when month.isBefore(_monthOf(first))) {
      return false;
    }
    if (widget.lastDate case final last? when month.isAfter(_monthOf(last))) {
      return false;
    }
    return true;
  }

  DateTime _clamp(DateTime month) {
    if (widget.firstDate case final first?
        when month.isBefore(_monthOf(first))) {
      return _monthOf(first);
    }
    if (widget.lastDate case final last? when month.isAfter(_monthOf(last))) {
      return _monthOf(last);
    }
    return month;
  }

  /// Turns the pager to [month]: on the `standard` spring to a neighbor,
  /// in one step further away.
  void _turnTo(DateTime month) {
    if (!_pages.hasClients) return;
    final position = _pages.position;
    final extent = position.viewportDimension;
    final target = _pageOf(month) * extent;
    if (position is! ScrollPositionWithSingleContext ||
        (target - position.pixels).abs() > extent * 1.5) {
      position.jumpTo(target);
      return;
    }
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    position.beginActivity(
      BallisticScrollActivity(
        position,
        motion.standard.createSimulation(start: position.pixels, end: target),
        position.context.vsync,
        false,
      ),
    );
  }

  /// A swipe settled: the page it landed on is the month.
  bool _onScrollEnd(ScrollEndNotification notification) {
    final metrics = notification.metrics;
    if (notification.depth != 0 || metrics.axis != Axis.horizontal) {
      return false;
    }
    final extent = metrics.viewportDimension;
    if (extent <= 0) return false;
    final month = _monthAt((metrics.pixels / extent).round());
    if (month != _month) {
      setState(() => _month = month);
      _active.clear();
      unawaited(CoilHaptics.play(context, CoilHapticEvent.toggle));
    }
    return false;
  }

  void _showMonth(int step) {
    final month = DateTime(_month.year, _month.month + step);
    if (!_canShow(month)) return;
    setState(() => _month = month);
    _active.clear();
    _turnTo(month);
  }

  void _pick(DateTime day, {required bool touch}) {
    if (!_enabled(day)) return;
    // A finger's pick ticks, as a platform picker does (iOS only by
    // default; see CoilHaptics.platform). Enter, Space and clicks don't.
    if (touch) unawaited(CoilHaptics.play(context, CoilHapticEvent.pick));
    widget.onSelected?.call(day);
  }

  /// The day the keyboard acts on: the active cell, else the selected day
  /// or the first of the month.
  DateTime get _current {
    if (_active.index case final i?) return _cell(_month, i);
    final selected = widget.selected;
    if (selected != null && _monthOf(selected) == _month) return selected;
    return _month;
  }

  void _moveTo(DateTime day) {
    final month = _monthOf(day);
    if (!_canShow(month)) return;
    if (month != _month) {
      setState(() => _month = month);
      _turnTo(month);
    }
    _active.activate(_indexOf(_month, day), via: CoilModality.keyboard);
  }

  void _moveDays(int days) {
    final day = _current;
    _moveTo(DateTime(day.year, day.month, day.day + days));
  }

  void _moveMonths(int months) {
    final day = _current;
    final month = DateTime(day.year, day.month + months);
    final last = DateTime(month.year, month.month + 1, 0).day;
    _moveTo(DateTime(month.year, month.month, day.day.clamp(1, last)));
  }

  void _pickCurrent() => _pick(_current, touch: false);

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final labels = widget.labels;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final cell = calendarCellExtent(context, metrics, text.body);
    // Room for the focus ring around the edge cells, inside the pager's
    // clip.
    final inset = 1 + theme.focusRing.width;

    final header = Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: metrics.itemPaddingX),
              child: Semantics(
                liveRegion: true,
                child: DefaultTextStyle(
                  style: text.body.copyWith(fontWeight: text.emphasis),
                  child: labels.monthTitle(_month),
                ),
              ),
            ),
          ),
          CoilButton.icon(
            variant: CoilButtonVariant.ghost,
            size: CoilSize.compact,
            onPressed: _canShow(DateTime(_month.year, _month.month - 1))
                ? () => _showMonth(-1)
                : null,
            semanticLabel: labels.previousMonthLabel,
            icon: const CoilDrawnGlyph(CoilGlyph.chevronStart),
          ),
          CoilButton.icon(
            variant: CoilButtonVariant.ghost,
            size: CoilSize.compact,
            onPressed: _canShow(DateTime(_month.year, _month.month + 1))
                ? () => _showMonth(1)
                : null,
            semanticLabel: labels.nextMonthLabel,
            icon: const CoilDrawnGlyph(CoilGlyph.chevronEnd),
          ),
        ],
      ),
    );

    final weekdays = Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DefaultTextStyle(
                      textAlign: TextAlign.center,
                      style: text.muted.caption,
                      maxLines: 1,
                      softWrap: false,
                      child: labels.weekday(
                        (widget.firstDayOfWeek - 1 + i) % 7 + 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final pager = NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      // Rows as tall as the columns are wide, up to the cell's extent: a
      // narrow calendar gets shorter rather than tall, thin cells.
      child: CalendarGridBox(
        cell: cell,
        inset: inset,
        child: PageView.builder(
          controller: _pages,
          itemCount: _pageCount,
          pageSnapping: false,
          physics: CalendarPagePhysics(motion: motion.standard),
          itemBuilder: (context, page) => Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: _grid(_monthAt(page), cell: cell, motion: motion),
          ),
        ),
      ),
    );

    // Seven cells wide when the calendar can choose; it fills a wider
    // space it's given, and shares a narrower one.
    return SizedBox(
      width: cell * 7 + inset * 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: metrics.gap,
        children: [
          header,
          weekdays,
          Shortcuts(
            shortcuts: {
              SingleActivator(
                rtl
                    ? LogicalKeyboardKey.arrowRight
                    : LogicalKeyboardKey.arrowLeft,
              ): const _DaysIntent(
                -1,
              ),
              SingleActivator(
                rtl
                    ? LogicalKeyboardKey.arrowLeft
                    : LogicalKeyboardKey.arrowRight,
              ): const _DaysIntent(
                1,
              ),
              const SingleActivator(LogicalKeyboardKey.arrowUp):
                  const _DaysIntent(-7),
              const SingleActivator(LogicalKeyboardKey.arrowDown):
                  const _DaysIntent(7),
              const SingleActivator(LogicalKeyboardKey.home):
                  const _WeekEdgeIntent(last: false),
              const SingleActivator(LogicalKeyboardKey.end):
                  const _WeekEdgeIntent(last: true),
              const SingleActivator(LogicalKeyboardKey.pageUp):
                  const _MonthsIntent(-1),
              const SingleActivator(LogicalKeyboardKey.pageDown):
                  const _MonthsIntent(1),
              const SingleActivator(LogicalKeyboardKey.pageUp, shift: true):
                  const _MonthsIntent(-12),
              const SingleActivator(LogicalKeyboardKey.pageDown, shift: true):
                  const _MonthsIntent(12),
              const SingleActivator(LogicalKeyboardKey.enter):
                  const ActivateIntent(),
              const SingleActivator(LogicalKeyboardKey.space):
                  const ActivateIntent(),
            },
            child: Actions(
              actions: {
                _DaysIntent: CallbackAction<_DaysIntent>(
                  onInvoke: (intent) => _moveDays(intent.days),
                ),
                _WeekEdgeIntent: CallbackAction<_WeekEdgeIntent>(
                  onInvoke: (intent) {
                    final fromStart =
                        (_current.weekday - widget.firstDayOfWeek) % 7;
                    _moveDays(intent.last ? 6 - fromStart : -fromStart);
                    return null;
                  },
                ),
                _MonthsIntent: CallbackAction<_MonthsIntent>(
                  onInvoke: (intent) => _moveMonths(intent.months),
                ),
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) => _pickCurrent(),
                ),
              },
              child: Focus(
                focusNode: _focus,
                autofocus: widget.autofocus,
                canRequestFocus: widget.onSelected != null,
                onFocusChange: (focused) {
                  // The ring shows where the keyboard is; it starts on the
                  // selected day.
                  if (focused &&
                      _active.index == null &&
                      CoilInputModality.instance.value ==
                          CoilModality.keyboard) {
                    _moveTo(_current);
                  }
                  setState(() {});
                },
                child: Semantics(container: true, child: pager),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One page: [month]'s six weeks. Only the shown month's page follows
  /// the keyboard.
  Widget _grid(
    DateTime month, {
    required double cell,
    required CoilMotion motion,
  }) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final radius = theme.shape.radii(metrics.tier).item;
    final current = month == _month;
    final selectedIndex = switch (widget.selected) {
      final day? when _indexOf(month, day) >= 0 && _indexOf(month, day) < 42 =>
        _indexOf(month, day),
      _ => null,
    };
    final days = Column(
      children: [
        for (var week = 0; week < 6; week++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: _cellAt(
                      month,
                      week * 7 + weekday,
                      cell,
                      selectedIndex,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    return CoilHoverRegion(
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
              debugLabel: 'CoilCalendar.selected',
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
              debugLabel: 'CoilCalendar.ring',
              target: current && _focus.hasFocus && _active.keyboardDriven
                  ? _active.index
                  : null,
              fadeIn: false,
              motion: motion.quick,
              exitMotion: motion.fadeExit,
              exitTravelMotion: motion.quick,
              fade: motion.fade,
              inflate: 1 + theme.focusRing.width,
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(
                    theme.shape.radii(metrics.tier).focusRing,
                  ),
                  side: BorderSide(
                    color: theme.focusRing.colorOf(colors),
                    width: theme.focusRing.width,
                  ),
                ),
              ),
            ),
          ],
          child: child!,
        ),
        child: days,
      ),
    );
  }

  Widget _cellAt(DateTime month, int index, double cell, int? selected) {
    final day = _cell(month, index);
    final enabled = _enabled(day);
    return _Day(
      index: index,
      day: day,
      extent: cell,
      label: widget.labels.dayLabel(day),
      outside: day.month != month.month,
      today: _sameDay(day, DateTime.now()),
      selected: index == selected,
      onPressed: enabled
          ? () => _pick(
              day,
              touch: !CoilInputModality.canHover(
                CoilInputModality.instance.lastPointerKind ??
                    PointerDeviceKind.touch,
              ),
            )
          : null,
    );
  }
}

/// One day's cell: its number, muted outside the month, semibold today and
/// inverted when selected. The grid's layer paints the fills on a square
/// of [extent] (smaller in a narrower column) in the middle of the cell;
/// the whole cell takes the tap.
class _Day extends StatefulWidget {
  const _Day({
    required this.index,
    required this.day,
    required this.extent,
    required this.label,
    required this.outside,
    required this.today,
    required this.selected,
    required this.onPressed,
  });

  final int index;
  final DateTime day;
  final double extent;
  final String label;
  final bool outside;
  final bool today;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  State<_Day> createState() => _DayState();
}

class _DayState extends State<_Day> {
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
    final color = widget.selected
        ? colors.background
        : widget.outside
        ? colors.mutedForeground
        : colors.foreground;
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
        child: Center(
          child: SizedBox.square(
            dimension: widget.extent,
            child: CoilHoverItem(
              index: widget.index,
              enabled: enabled,
              child: Opacity(
                opacity: enabled ? 1 : metrics.disabledOpacity,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${widget.day.day}',
                      maxLines: 1,
                      softWrap: false,
                      style: text.body.tabular.copyWith(
                        fontWeight: widget.today || widget.selected
                            ? text.emphasis
                            : text.body.fontWeight,
                        color: color,
                      ),
                    ),
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

/// Moves the keyboard's day by [days]: the arrow keys.
class _DaysIntent extends Intent {
  const _DaysIntent(this.days);

  final int days;
}

/// Moves the keyboard's day to the start or [last] day of its week: Home
/// and End.
class _WeekEdgeIntent extends Intent {
  const _WeekEdgeIntent({required this.last});

  final bool last;
}

/// Moves the keyboard's day by [months], turning the page: Page Up and
/// Page Down, with Shift for a year.
class _MonthsIntent extends Intent {
  const _MonthsIntent(this.months);

  final int months;
}
