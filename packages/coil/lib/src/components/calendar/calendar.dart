import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/calendar/calendar_layout.dart';
import 'package:coil/src/components/calendar/calendar_months.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

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
    this.monthLabel = _monthLabel,
    this.monthName = _monthName,
    this.year = _year,
    this.yearLabel = _yearLabel,
    this.chooseMonthLabel = 'Choose a month and year',
    this.showDaysLabel = _showDaysLabel,
    this.confirm = const Text('Done'),
    this.summary = _summary,
    this.summaryLabel = _summaryLabel,
    this.previousYearLabel = 'Previous year',
    this.nextYearLabel = 'Next year',
  });

  /// What a date picker's Done will confirm, on the leading side of its
  /// footer, like "Fri, Nov 22, 2019", with the time when the picker picks
  /// one ("Fri, Nov 22, 2019, 09:30"). It names the draft, so it stays
  /// readable however far the calendar has paged or zoomed;
  /// [summaryLabel] announces it.
  final Widget Function(DateTime value, {required bool withTime}) summary;

  /// [summary] for screen readers, like "Selected: Friday, November 22,
  /// 2019".
  final String Function(DateTime value, {required bool withTime}) summaryLabel;

  /// The previous-year button's label in the month view, for screen
  /// readers.
  final String previousYearLabel;

  /// The next-year button's label in the month view, for screen readers.
  final String nextYearLabel;

  /// The month title, like "November 2026". Tapping it zooms out to the
  /// month view; [monthLabel] announces it.
  ///
  /// Zooming out, the title turns into the [year]: the box narrows to it,
  /// holding the title's end in place, while this title blur-fades out
  /// over it. A month title that ends in the year, as "November 2026"
  /// does, keeps its year still and only the month leaves; one that leads
  /// with the year overlaps [year] while the zoom runs.
  final Widget Function(DateTime month) monthTitle;

  /// [monthTitle] and a month in the month view for screen readers, like
  /// "November 2026". It's announced as the month changes.
  final String Function(DateTime month) monthLabel;

  /// A month's name in the month view, like "Nov", from 1 to 12.
  final Widget Function(int month) monthName;

  /// The title in the month view, like "2026": the year in view. Tapping
  /// it zooms back into the days; [yearLabel] announces it.
  final Widget Function(int year) year;

  /// [year] for screen readers, like "2026".
  final String Function(int year) yearLabel;

  /// What the month title does, for screen readers: a hint on the button
  /// that zooms out to the month view.
  final String chooseMonthLabel;

  /// What the [year] title does, for screen readers: a hint on the button
  /// that zooms back into the days of the month it's given, like "Back to
  /// the days of November 2026".
  final String Function(DateTime month) showDaysLabel;

  /// A date picker's confirming button, "Done": it sets the picked date
  /// and closes the sheet. Only the sheet has one; a popover applies each
  /// pick at once, with or without a time.
  final Widget confirm;

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

  static Widget _monthTitle(DateTime month) => Text(_monthLabel(month));

  static String _monthLabel(DateTime month) =>
      '${_months[month.month - 1]} ${month.year}';

  static Widget _monthName(int month) =>
      Text(_months[month - 1].substring(0, 3));

  static Widget _year(int year) => Text('$year');

  static String _yearLabel(int year) => '$year';

  static String _showDaysLabel(DateTime month) =>
      'Back to the days of ${_monthLabel(month)}';

  static Widget _summary(DateTime value, {required bool withTime}) {
    final date =
        '${_weekdays[value.weekday - 1].substring(0, 3)}, '
        '${_months[value.month - 1].substring(0, 3)} ${value.day}, '
        '${value.year}';
    return Text(withTime ? '$date, ${_time(value)}' : date);
  }

  static String _summaryLabel(DateTime value, {required bool withTime}) {
    final day = 'Selected: ${_dayLabel(value)}';
    return withTime ? '$day, ${_time(value)}' : day;
  }

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  static Widget _weekday(int weekday) =>
      Text(_weekdays[weekday - 1].substring(0, 2));

  static Widget _date(DateTime value, {required bool withTime}) =>
      Text(_dateLabel(value, withTime: withTime));

  static String _dateLabel(DateTime value, {required bool withTime}) {
    final date = '${_months[value.month - 1]} ${value.day}, ${value.year}';
    return withTime ? '$date, ${_time(value)}' : date;
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
/// too. The arrow buttons turn the page on any device. The month title
/// follows the pages as they move: it changes as soon as a page is more
/// than half in view, mid-swipe, with a blur-fade.
///
/// The title is a button: it zooms out to the month view, a year's twelve
/// months per page, paging sideways like the days, opening on the shown
/// month's year. The arrows turn a year there, and the title follows the
/// year in view. Picking a month zooms back into its days.
///
/// The grid is one focus stop: the arrows move a day or a week, Home and
/// End go to the week's ends, PageUp and PageDown change the month (with
/// Shift, the year), and Enter or Space picks. Moving past the month turns
/// the page. In the month view the arrows move a month (Up and Down a row),
/// PageUp and PageDown a year, Enter or Space picks, and Escape goes back
/// to the days.
///
/// Days are always square: as tall as the tier's control height and grown
/// with the text scale. The calendar is seven cells wide when it can
/// choose. It fills a wider space it's given (a sheet on a phone) until
/// the days are 20 % bigger, and centers in anything wider; it shares a
/// narrower one, shrinking the numbers if they don't fit. Each day takes
/// taps on its whole cell, so no point of the grid misses a day.
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
    this.onSubmitted,
  }) : assert(
         firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday,
         'firstDayOfWeek must be DateTime.monday to DateTime.sunday.',
       );

  /// The picked day, or null.
  final DateTime? selected;

  /// Called with the day the user picks. Null disables the calendar.
  final ValueChanged<DateTime>? onSelected;

  /// Called after [onSelected] when Enter picks the day, which also
  /// submits it: a date picker confirms with it. Space only picks.
  final ValueChanged<DateTime>? onSubmitted;

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

  /// How far the days sit inside a calendar's box at [context]: room for
  /// the focus ring around the edge days. Content that lines up with the
  /// days (a footer, a time band) insets this much from the calendar's
  /// edges.
  static double edgeInsetOf(BuildContext context) =>
      calendarWidths(context).inset;

  @override
  State<CoilCalendar> createState() => _CoilCalendarState();
}

/// Gives [child] a [CoilCalendar]'s width: seven days when it can choose;
/// more when it's stretched, until the days are 20 % bigger; centered
/// past that. Put a calendar and what sits under it (like
/// `CoilTimeColumns`) in one so they share the width.
class CoilCalendarWidth extends StatelessWidget {
  /// Sizes [child] as wide as a calendar.
  const CoilCalendarWidth({required this.child, super.key});

  /// The calendar, and what shares its width.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final widths = calendarWidths(context);
    return CalendarWidthBox(
      natural: widths.natural,
      max: widths.max,
      child: child,
    );
  }
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

  /// The month the title shows: the page more than half in view, which
  /// changes mid-swipe, before [_month] does.
  late DateTime _title = _month;

  /// Whether the month view is zoomed out to.
  bool _monthsOpen = false;

  /// The month the title names in the month view: the keyboard's month in
  /// the year more than half in view. Zooming back in shows it.
  late DateTime _monthsTitle = _month;

  /// The open month view, new for each zoom out so it opens on the days'
  /// month.
  var _monthsView = GlobalKey<CalendarMonthViewState>();

  late PageController _pages = PageController(initialPage: _pageOf(_month));
  final _active = CoilActiveItemController();
  final _focus = FocusNode(debugLabel: 'CoilCalendar');
  final _monthsFocus = FocusNode(debugLabel: 'CoilCalendar.months');

  /// Has focus while anything in the calendar does.
  final _within = FocusNode(
    debugLabel: 'CoilCalendar.within',
    canRequestFocus: false,
    skipTraversal: true,
  );

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
    _title = month;
  }

  @override
  void dispose() {
    _pages.dispose();
    _active.dispose();
    _focus.dispose();
    _monthsFocus.dispose();
    _within.dispose();
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
    if (!_pages.hasClients) {
      _title = month;
      return;
    }
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

  /// The pager moved: the title follows the page more than half in view,
  /// and once a swipe settles, the page it landed on is the month.
  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (notification.depth != 0 || metrics.axis != Axis.horizontal) {
      return false;
    }
    final extent = metrics.viewportDimension;
    if (extent <= 0) return false;
    final month = _clamp(_monthAt((metrics.pixels / extent).round()));
    if (notification is ScrollUpdateNotification && month != _title) {
      setState(() => _title = month);
    }
    if (notification is ScrollEndNotification) {
      if (month != _month) {
        setState(() => _month = _title = month);
        _active.clear();
      } else if (month != _title) {
        setState(() => _title = month);
      }
    }
    return false;
  }

  /// Zooms out to the month view, or back into the days of the month the
  /// title names.
  void _toggleMonths() =>
      _monthsOpen ? _pickMonth(_monthsTitle) : _showMonths(open: true);

  void _showMonths({required bool open}) {
    if (open == _monthsOpen) return;
    // Focus moves with the view when it was in the calendar.
    final hadFocus = _within.hasFocus;
    setState(() {
      _monthsOpen = open;
      if (open) {
        _monthsTitle = _month;
        _monthsView = GlobalKey<CalendarMonthViewState>();
      }
    });
    if (!hadFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (open ? _monthsFocus : _focus).requestFocus();
    });
  }

  /// A month picked in the month view: zoom back into its days.
  void _pickMonth(DateTime month) {
    final target = _clamp(month);
    setState(() => _month = _title = target);
    _active.clear();
    if (_pages.hasClients) _pages.jumpToPage(_pageOf(target));
    _showMonths(open: false);
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

  void _pickCurrent({bool submit = false}) {
    final day = _current;
    if (!_enabled(day)) return;
    _pick(day, touch: false);
    if (submit) widget.onSubmitted?.call(day);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final labels = widget.labels;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // The inset is room for the focus ring around the edge cells, inside
    // the pager's clip.
    final widths = calendarWidths(context);
    final cell = widths.cell;
    final inset = widths.inset;

    // The arrows turn a month of days, or a year of months.
    VoidCallback? turn(int step) {
      if (_monthsOpen) {
        final year = _monthsTitle.year + step;
        if (!_canShow(DateTime(year, step < 0 ? 12 : 1))) return null;
        return () => _monthsView.currentState?.turn(step);
      }
      if (!_canShow(DateTime(_month.year, _month.month + step))) return null;
      return () => _showMonth(step);
    }

    final arrows = [
      CoilButton.icon(
        variant: CoilButtonVariant.ghost,
        size: CoilSize.compact,
        onPressed: turn(-1),
        semanticLabel: _monthsOpen
            ? labels.previousYearLabel
            : labels.previousMonthLabel,
        icon: const CoilIcon(CoilIconRole.chevronStart),
      ),
      CoilButton.icon(
        variant: CoilButtonVariant.ghost,
        size: CoilSize.compact,
        onPressed: turn(1),
        semanticLabel: _monthsOpen
            ? labels.nextYearLabel
            : labels.nextMonthLabel,
        icon: const CoilIcon(CoilIconRole.chevronEnd),
      ),
    ];
    // The title's text starts where the days start, and the arrows'
    // glyphs end where they end: both are ghost buttons, so their padding
    // hangs outside the grid rather than pushing the text in.
    final compact = CoilTheme.metricsOf(context, size: CoilSize.compact);
    final titleBleed = metrics.itemPaddingX;
    final arrowExtent = math.max(compact.controlHeight, compact.minHitTarget);
    final arrowGlyph = MediaQuery.textScalerOf(context).scale(compact.iconSize);
    final arrowBleed = math.max(0, (arrowExtent - arrowGlyph) / 2).toDouble();
    final direction = rtl ? -1.0 : 1.0;
    final header = Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Row(
        children: [
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Transform.translate(
                offset: Offset(-titleBleed * direction, 0),
                child: _MonthTitle(
                  title: _monthsOpen ? _monthsTitle : _title,
                  labels: labels,
                  open: _monthsOpen,
                  motion: widget.motion,
                  onPressed: widget.onSelected == null ? null : _toggleMonths,
                ),
              ),
            ),
          ),
          // A month of days in the day view, a year of months in the month
          // view.
          Transform.translate(
            offset: Offset(arrowBleed * direction, 0),
            child: Row(mainAxisSize: MainAxisSize.min, children: arrows),
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

    final pager = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      // Rows as tall as the columns are wide: every day is square.
      child: CalendarGridBox(
        cell: cell,
        inset: inset,
        child: CalendarPagerClip(
          bleed: inset,
          child: PageView.builder(
            controller: _pages,
            itemCount: _pageCount,
            pageSnapping: false,
            clipBehavior: Clip.none,
            // Hands drags off to a sheet it sits in.
            scrollBehavior: CoilSheetRoute.scrollBehaviorOf(context),
            physics: CalendarPagePhysics(motion: motion.standard),
            // A tap in the focus ring's inset picks the edge day.
            itemBuilder: (context, page) => CalendarInsetHit(
              inset: inset,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: _grid(_monthAt(page), cell: cell, motion: motion),
              ),
            ),
          ),
        ),
      ),
    );

    final days = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: metrics.gap,
      children: [
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
                const _SubmitIntent(),
            const SingleActivator(LogicalKeyboardKey.numpadEnter):
                const _SubmitIntent(),
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
              _SubmitIntent: CallbackAction<_SubmitIntent>(
                onInvoke: (_) => _pickCurrent(submit: true),
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
                    CoilInputModality.instance.value == CoilModality.keyboard) {
                  _moveTo(_current);
                }
                setState(() {});
              },
              child: Semantics(container: true, child: pager),
            ),
          ),
        ),
      ],
    );

    // Seven cells wide when the calendar can choose; it fills a wider
    // space it's given up to its max and centers past it, and shares a
    // narrower one.
    return Focus(
      focusNode: _within,
      canRequestFocus: false,
      skipTraversal: true,
      child: CoilCalendarWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: metrics.gap,
          children: [
            header,
            _CalendarZoom(
              open: _monthsOpen,
              motion: widget.motion,
              days: days,
              months: (context) => CalendarMonthView(
                key: _monthsView,
                month: _month,
                selected: widget.selected,
                firstMonth: switch (widget.firstDate) {
                  final first? => _monthOf(first),
                  null => null,
                },
                lastMonth: switch (widget.lastDate) {
                  final last? => _monthOf(last),
                  null => null,
                },
                monthName: labels.monthName,
                monthLabel: labels.monthLabel,
                inset: inset,
                focusNode: _monthsFocus,
                motion: widget.motion,
                onPicked: _pickMonth,
                onShown: (month) {
                  if (month != _monthsTitle) {
                    setState(() => _monthsTitle = month);
                  }
                },
                onClose: () => _pickMonth(_monthsTitle),
              ),
            ),
          ],
        ),
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
              inflate: theme.focusRing.extent,
              decoration: theme.focusRing.decorationAround(
                colors,
                radius: radius,
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

/// Picks the keyboard's day and submits it: Enter.
class _SubmitIntent extends Intent {
  const _SubmitIntent();
}

/// The month title: a button that zooms out to the month view, with a
/// chevron that turns as it opens. A new month's name blur-fades in as the
/// old one leaves, and the button springs to its width. In the month view
/// it shows only the year: zooming out, the month leaves and the button
/// narrows to the year ([_ZoomTitle]).
class _MonthTitle extends StatelessWidget {
  const _MonthTitle({
    required this.title,
    required this.labels,
    required this.open,
    required this.motion,
    required this.onPressed,
  });

  /// The month the title names: the days' month, or in the month view the
  /// keyboard's month, which it zooms back into.
  final DateTime title;
  final CoilCalendarLabels labels;
  final bool open;
  final CoilMotion? motion;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final compact = CoilTheme.metricsOf(context, size: CoilSize.compact);
    final text = CoilTheme.textOf(context);
    final motion = CoilTheme.motionOf(context, override: this.motion);
    final radius = theme.shape.radii(metrics.tier).item;

    // A new month or year swaps in with the blur-fade.
    Widget switcher({required Object key, required Widget child}) =>
        MotionSizeSwitcher(
          motion: motion.fade,
          exitMotion: motion.fadeExit,
          sizeMotion: motion.standard,
          // A shorter name takes its size at once; the old one fades out
          // over it.
          immediateResize: true,
          alignment: AlignmentDirectional.centerStart,
          clipBehavior: Clip.none,
          debugLabel: 'CoilCalendar.title',
          transitionBuilder: CoilBlurFade.transition(
            blur: CoilBlurFade.defaultBlur / 2,
            scale: 1,
          ),
          child: KeyedSubtree(
            key: ValueKey(key),
            child: DefaultTextStyle(
              style: text.body.copyWith(
                fontWeight: text.emphasis,
                color: colors.foreground,
              ),
              maxLines: 1,
              softWrap: false,
              // Large text in a narrow calendar shrinks the title rather
              // than cut off the year.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: child,
              ),
            ),
          ),
        );

    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      expanded: open,
      liveRegion: true,
      label: open ? labels.yearLabel(title.year) : labels.monthLabel(title),
      hint: open ? labels.showDaysLabel(title) : labels.chooseMonthLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: CoilInteraction(
        onPressed: onPressed,
        minHitTarget: compact.minHitTarget,
        excludeFromSemantics: true,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          final fill = pressed ? colors.active : colors.hover;
          return CoilFocusRing(
            visible: states.contains(WidgetState.focused),
            borderRadius: BorderRadius.circular(radius),
            child: SingleMotionBuilder(
              value: hovered || pressed ? 1 : 0,
              motion: hovered || pressed ? motion.fade : motion.fadeExit,
              debugLabel: 'CoilCalendar.title.hover',
              builder: (context, lit, child) => DecoratedBox(
                decoration: ShapeDecoration(
                  color: fill.withValues(alpha: fill.a * lit.clamp(0.0, 1.0)),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                child: child,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: compact.controlHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.itemPaddingX,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: compact.gap,
                    children: [
                      Flexible(
                        child: _ZoomTitle(
                          open: open,
                          motion: motion,
                          edge: metrics.itemPaddingX,
                          month: switcher(
                            key: title,
                            child: labels.monthTitle(title),
                          ),
                          year: switcher(
                            key: title.year,
                            child: labels.year(title.year),
                          ),
                        ),
                      ),
                      IconTheme(
                        data: IconThemeData(
                          size: compact.iconSize,
                          applyTextScaling: true,
                          color: colors.mutedForeground,
                          weight: CoilIconWeight.emphasis,
                        ),
                        child: SingleMotionBuilder(
                          value: open ? 0.5 : 0,
                          motion: open ? motion.standard : motion.standardExit,
                          debugLabel: 'CoilCalendar.title.chevron',
                          child: const CoilIcon(CoilIconRole.chevronDown),
                          builder: (context, turns, child) => Transform.rotate(
                            angle: turns * 2 * math.pi,
                            child: child,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The title's zoom between the month title ("November 2026") and the
/// year alone ("2026"). Its width springs from one to the other on
/// `standard` while the month title blur-fades out on `fade` over the
/// year, which shows at once; zooming in runs it back, the year staying
/// until the month title is in. Both hold the box's end, so the year a
/// month title ends with stays still while the month leaves past the
/// start, fading out over the button's padding ([edge]).
class _ZoomTitle extends StatelessWidget {
  const _ZoomTitle({
    required this.open,
    required this.motion,
    required this.edge,
    required this.month,
    required this.year,
  });

  final bool open;
  final CoilMotion motion;
  final double edge;
  final Widget month;
  final Widget year;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SingleMotionBuilder(
      value: open ? 1 : 0,
      motion: open ? motion.standard : motion.standardExit,
      debugLabel: 'CoilCalendar.title.zoom',
      builder: (context, width, _) => SingleMotionBuilder(
        value: open ? 1 : 0,
        motion: open ? motion.fade : motion.fadeExit,
        debugLabel: 'CoilCalendar.title.zoomFade',
        builder: (context, fade, _) {
          final gone = fade.clamp(0.0, 1.0);
          final sigma = reduce ? 0.0 : CoilBlurFade.defaultBlur / 2 * gone;
          // At rest, only the title in view is built.
          final monthShown = !open || gone < 1 || width < 1;
          final yearShown = open || gone > 0 || width > 0;
          return _ZoomTitleBox(
            progress: width,
            edge: edge,
            textDirection: Directionality.of(context),
            children: [
              if (yearShown) year else const SizedBox.shrink(),
              // CoilBlurFade's blur-fade, drawn here so the title keeps one
              // blur-fade, the switcher's, while it's at rest.
              if (monthShown)
                Opacity(
                  opacity: 1 - gone,
                  child: ImageFiltered(
                    enabled: sigma > 0.01,
                    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: month,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          );
        },
      ),
    );
  }
}

/// Lays out the year and the month title at their own widths and takes a
/// width [progress] of the way from the month title's (0) to the year's
/// (1), both at its end. What reaches past its start fades out over
/// [edge].
class _ZoomTitleBox extends MultiChildRenderObjectWidget {
  const _ZoomTitleBox({
    required this.progress,
    required this.edge,
    required this.textDirection,
    required super.children,
  });

  final double progress;
  final double edge;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderZoomTitleBox(
    progress: progress,
    edge: edge,
    textDirection: textDirection,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderZoomTitleBox renderObject,
  ) {
    renderObject
      ..progress = progress
      ..edge = edge
      ..textDirection = textDirection;
  }
}

class _ZoomTitleParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderZoomTitleBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ZoomTitleParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ZoomTitleParentData> {
  _RenderZoomTitleBox({
    required this._progress,
    required this._edge,
    required this._textDirection,
  });

  double _progress;
  double get progress => _progress;
  set progress(double value) {
    if (value == _progress) return;
    _progress = value;
    markNeedsLayout();
  }

  double _edge;
  double get edge => _edge;
  set edge(double value) {
    if (value == _edge) return;
    _edge = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  final _clip = LayerHandle<ClipRectLayer>();
  final _mask = LayerHandle<ShaderMaskLayer>();

  /// Whether a child reaches past the start, which then fades out.
  bool _overflows = false;

  @override
  bool get alwaysNeedsCompositing => _overflows;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ZoomTitleParentData) {
      child.parentData = _ZoomTitleParentData();
    }
  }

  RenderBox get _year => firstChild!;
  RenderBox get _month => lastChild!;

  double _width(double year, double month) =>
      month + (year - month) * _progress;

  @override
  double computeMinIntrinsicWidth(double height) => _width(
    _year.getMinIntrinsicWidth(height),
    _month.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => _width(
    _year.getMaxIntrinsicWidth(height),
    _month.getMaxIntrinsicWidth(height),
  );

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
    _year.getMinIntrinsicHeight(width),
    _month.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(
    _year.getMaxIntrinsicHeight(width),
    _month.getMaxIntrinsicHeight(width),
  );

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  Size _sizeFor(BoxConstraints constraints, Size year, Size month) =>
      constraints.constrain(
        Size(
          math.max(0, _width(year.width, month.width)),
          math.max(year.height, month.height),
        ),
      );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final loose = constraints.loosen();
    return _sizeFor(
      constraints,
      _year.getDryLayout(loose),
      _month.getDryLayout(loose),
    );
  }

  @override
  void performLayout() {
    final loose = constraints.loosen();
    _year.layout(loose, parentUsesSize: true);
    _month.layout(loose, parentUsesSize: true);
    size = _sizeFor(constraints, _year.size, _month.size);
    for (final child in [_year, _month]) {
      (child.parentData! as _ZoomTitleParentData).offset = Offset(
        _textDirection == TextDirection.rtl ? 0 : size.width - child.size.width,
        (size.height - child.size.height) / 2,
      );
    }
    final overflows =
        _year.size.width > size.width || _month.size.width > size.width;
    if (overflows != _overflows) {
      _overflows = overflows;
      markNeedsCompositingBitsUpdate();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_overflows) {
      _clip.layer = null;
      _mask.layer = null;
      defaultPaint(context, offset);
      return;
    }
    // Past the start, a gradient over the edge fades the leaving month
    // out; nothing shows beyond it. The other sides leave room for the
    // blur.
    final rtl = _textDirection == TextDirection.rtl;
    final spread = size.height;
    final rect = rtl
        ? Rect.fromLTRB(
            -spread,
            -spread,
            size.width + edge,
            size.height + spread,
          )
        : Rect.fromLTRB(
            -edge,
            -spread,
            size.width + spread,
            size.height + spread,
          );
    final fade = edge / rect.width;
    _mask.layer = (_mask.layer ?? ShaderMaskLayer())
      ..shader = LinearGradient(
        begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
        end: rtl ? Alignment.centerLeft : Alignment.centerRight,
        colors: const [Color(0x00000000), Color(0xFF000000)],
        stops: [0, fade],
      ).createShader(Offset.zero & rect.size)
      ..maskRect = rect.shift(offset)
      ..blendMode = BlendMode.dstIn;
    // The mask only fades inside its rect; the clip drops the rest.
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      rect,
      (context, offset) =>
          context.pushLayer(_mask.layer!, defaultPaint, offset),
      oldLayer: _clip.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;

  @override
  void dispose() {
    _clip.layer = null;
    _mask.layer = null;
    super.dispose();
  }
}

/// The day grid and the month view in one place: zooming out, the days
/// shrink toward the title and fade as the months settle in from a little
/// larger; zooming in runs it back. The scale springs on `standard` (none
/// under reduced motion) and the opacity on `fade`. Whichever is hidden
/// takes no pointer, focus or semantics; the month view is only built
/// while it shows. The days keep their layout, so the calendar's height
/// never changes.
class _CalendarZoom extends StatelessWidget {
  const _CalendarZoom({
    required this.open,
    required this.motion,
    required this.days,
    required this.months,
  });

  final bool open;
  final CoilMotion? motion;
  final Widget days;
  final WidgetBuilder months;

  /// How much the leaving view shrinks, and the arriving one starts larger.
  static const depth = 0.1;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context, override: this.motion);
    // The title's corner: the top start.
    final origin = Directionality.of(context) == TextDirection.rtl
        ? Alignment.topRight
        : Alignment.topLeft;
    return SingleMotionBuilder(
      value: open ? 1 : 0,
      motion: open ? motion.standard : motion.standardExit,
      debugLabel: 'CoilCalendar.zoom',
      builder: (context, zoom, _) => SingleMotionBuilder(
        value: open ? 1 : 0,
        motion: open ? motion.fade : motion.fadeExit,
        debugLabel: 'CoilCalendar.zoomFade',
        builder: (context, fade, _) {
          final shown = fade.clamp(0.0, 1.0);
          return Stack(
            children: [
              IgnorePointer(
                ignoring: open,
                child: ExcludeFocus(
                  excluding: open,
                  child: ExcludeSemantics(
                    excluding: open,
                    child: Opacity(
                      opacity: 1 - shown,
                      child: Transform.scale(
                        scale: 1 - depth * zoom,
                        alignment: origin,
                        filterQuality: zoom == 0 ? null : FilterQuality.medium,
                        child: days,
                      ),
                    ),
                  ),
                ),
              ),
              if (open || shown > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !open,
                    child: ExcludeFocus(
                      excluding: !open,
                      child: ExcludeSemantics(
                        excluding: !open,
                        child: Opacity(
                          opacity: shown,
                          child: Transform.scale(
                            scale: 1 + depth * (1 - zoom),
                            alignment: origin,
                            filterQuality: zoom == 1
                                ? null
                                : FilterQuality.medium,
                            child: Builder(builder: months),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
