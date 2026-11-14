import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
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
/// day's fill glides to the next pick. The grid is one focus stop: the
/// arrows move a day or a week, Home and End go to the week's ends,
/// PageUp and PageDown change the month (with Shift, the year), and Enter
/// or Space picks. Moving past the month turns the page.
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
  });

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

bool _sameDay(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

class _CoilCalendarState extends State<CoilCalendar> {
  late DateTime _month = _monthOf(
    widget.initialMonth ?? widget.selected ?? DateTime.now(),
  );
  final _active = CoilActiveItemController();
  final _focus = FocusNode(debugLabel: 'CoilCalendar');

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  @override
  void dispose() {
    _active.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// How many days of the previous month lead the grid.
  int get _lead => (_month.weekday - widget.firstDayOfWeek) % 7;

  /// The day in cell [index] of the 6-week grid.
  DateTime _cell(int index) =>
      DateTime(_month.year, _month.month, 1 - _lead + index);

  int _indexOf(DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(_month.year, _month.month, 1 - _lead)).inDays;

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

  void _showMonth(int step) {
    final month = DateTime(_month.year, _month.month + step);
    if (!_canShow(month)) return;
    setState(() => _month = month);
    _active.clear();
  }

  void _pick(DateTime day) {
    if (_enabled(day)) widget.onSelected?.call(day);
  }

  /// The day the keyboard acts on: the active cell, else the selected day
  /// or the first of the month.
  DateTime get _current {
    if (_active.index case final i?) return _cell(i);
    final selected = widget.selected;
    if (selected != null && _monthOf(selected) == _month) return selected;
    return _month;
  }

  void _moveTo(DateTime day) {
    final month = _monthOf(day);
    if (!_canShow(month)) return;
    if (month != _month) setState(() => _month = month);
    _active.activate(_indexOf(day), via: CoilModality.keyboard);
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

  void _pickCurrent() => _pick(_current);

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final labels = widget.labels;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final cell = metrics.controlHeight;
    final radius = theme.shape.radii(metrics.tier).item;
    final selectedIndex = switch (widget.selected) {
      final day? when _indexOf(day) >= 0 && _indexOf(day) < 42 => _indexOf(day),
      _ => null,
    };

    final header = Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: metrics.itemPaddingX),
            child: Semantics(
              liveRegion: true,
              child: DefaultTextStyle(
                style: theme.typography.style(
                  metrics.body,
                  weight: CoilWeight.semibold,
                  color: colors.foreground,
                ),
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
    );

    final weekdays = Row(
      children: [
        for (var i = 0; i < 7; i++)
          _Column(
            width: cell,
            child: ExcludeSemantics(
              child: DefaultTextStyle(
                textAlign: TextAlign.center,
                style: theme.typography.style(
                  metrics.caption,
                  color: colors.mutedForeground,
                ),
                child: labels.weekday((widget.firstDayOfWeek - 1 + i) % 7 + 1),
              ),
            ),
          ),
      ],
    );

    final days = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++)
                _Column(
                  width: cell,
                  child: _cellAt(week * 7 + weekday, metrics, selectedIndex),
                ),
            ],
          ),
      ],
    );

    final grid = CoilHoverRegion(
      axis: CoilHoverAxis.xy,
      activeItem: _active,
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
              target: _focus.hasFocus && _active.keyboardDriven
                  ? _active.index
                  : null,
              fadeIn: false,
              motion: motion.quick,
              exitMotion: motion.fadeExit,
              exitTravelMotion: motion.quick,
              fade: motion.fade,
              inflate: 1 + theme.focusRingWidth,
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(
                    theme.shape.radii(metrics.tier).focusRing,
                  ),
                  side: BorderSide(
                    color: colors.focusRing,
                    width: theme.focusRingWidth,
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

    // As wide as seven cells, or as the room allows: on a phone the
    // columns share a narrower width and rows keep the control height.
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: metrics.gap,
        children: [
          header,
          weekdays,
          CallbackShortcuts(
            bindings: {
              SingleActivator(
                rtl
                    ? LogicalKeyboardKey.arrowRight
                    : LogicalKeyboardKey.arrowLeft,
              ): () =>
                  _moveDays(-1),
              SingleActivator(
                rtl
                    ? LogicalKeyboardKey.arrowLeft
                    : LogicalKeyboardKey.arrowRight,
              ): () =>
                  _moveDays(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _moveDays(-7),
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _moveDays(7),
              const SingleActivator(LogicalKeyboardKey.home): () =>
                  _moveDays(-((_current.weekday - widget.firstDayOfWeek) % 7)),
              const SingleActivator(LogicalKeyboardKey.end): () =>
                  _moveDays(6 - (_current.weekday - widget.firstDayOfWeek) % 7),
              const SingleActivator(LogicalKeyboardKey.pageUp): () =>
                  _moveMonths(-1),
              const SingleActivator(LogicalKeyboardKey.pageDown): () =>
                  _moveMonths(1),
              const SingleActivator(
                LogicalKeyboardKey.pageUp,
                shift: true,
              ): () =>
                  _moveMonths(-12),
              const SingleActivator(
                LogicalKeyboardKey.pageDown,
                shift: true,
              ): () =>
                  _moveMonths(12),
              const SingleActivator(LogicalKeyboardKey.enter): _pickCurrent,
              const SingleActivator(LogicalKeyboardKey.space): _pickCurrent,
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
              child: Semantics(container: true, child: grid),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellAt(int index, CoilMetrics metrics, int? selected) {
    final day = _cell(index);
    final enabled = _enabled(day);
    return CoilHoverItem(
      index: index,
      enabled: enabled,
      child: _Day(
        day: day,
        metrics: metrics,
        label: widget.labels.dayLabel(day),
        outside: day.month != _month.month,
        today: _sameDay(day, DateTime.now()),
        selected: index == selected,
        onPressed: enabled ? () => _pick(day) : null,
      ),
    );
  }
}

/// One day's cell: its number, muted outside the month, semibold today and
/// inverted when selected. The grid's layer paints the fills.
class _Day extends StatefulWidget {
  const _Day({
    required this.day,
    required this.metrics,
    required this.label,
    required this.outside,
    required this.today,
    required this.selected,
    required this.onPressed,
  });

  final DateTime day;
  final CoilMetrics metrics;
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
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
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
        child: Opacity(
          opacity: enabled ? 1 : widget.metrics.disabledOpacity,
          child: SizedBox(
            height: widget.metrics.controlHeight,
            child: Center(
              child: Text(
                '${widget.day.day}',
                style: theme.typography.style(
                  widget.metrics.body,
                  weight: widget.today || widget.selected
                      ? CoilWeight.semibold
                      : CoilWeight.normal,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the grid's seven columns: [width] wide, or an equal share of a
/// narrower row.
class _Column extends StatelessWidget {
  const _Column({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => Flexible(
    child: SizedBox(width: width, child: child),
  );
}
