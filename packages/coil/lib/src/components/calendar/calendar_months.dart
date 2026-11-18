import 'dart:async';
import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The month view a calendar zooms out to: each year's twelve months,
/// three across and four down under the year, in a list that scrolls
/// through the years.
///
/// It opens with [month]'s year in the middle. Months outside [firstMonth]
/// and [lastMonth] are dimmed and can't be picked; the list ends at their
/// years. The month of [selected] is filled like a selected day, and this
/// month is semibold, like today.
///
/// It's one focus stop: the arrows move a month (Up and Down a row of
/// three), PageUp and PageDown a year, Enter or Space picks, and Escape
/// calls [onClose].
class CalendarMonthView extends StatefulWidget {
  /// Creates the month view.
  const CalendarMonthView({
    required this.month,
    required this.selected,
    required this.firstMonth,
    required this.lastMonth,
    required this.monthName,
    required this.year,
    required this.monthLabel,
    required this.inset,
    required this.focusNode,
    required this.onPicked,
    required this.onClose,
    super.key,
    this.motion,
  });

  /// The month the day grid shows: its year opens in the middle, and the
  /// keyboard starts on it.
  final DateTime month;

  /// The picked day, if any.
  final DateTime? selected;

  /// The earliest month that can be picked, or null.
  final DateTime? firstMonth;

  /// The latest month that can be picked, or null.
  final DateTime? lastMonth;

  /// A month's name in its cell, from 1 to 12.
  final Widget Function(int month) monthName;

  /// A year's heading.
  final Widget Function(int year) year;

  /// A month's name for screen readers.
  final String Function(DateTime month) monthLabel;

  /// The room for the focus ring on each side.
  final double inset;

  /// The focus node of the view's single focus stop.
  final FocusNode focusNode;

  /// Called with the month the user picks.
  final ValueChanged<DateTime> onPicked;

  /// Called on Escape.
  final VoidCallback onClose;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// The latest year the list reaches without a [lastMonth].
  static const lastYear = 9999;

  @override
  State<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends State<CalendarMonthView> {
  ScrollController? _scroll;
  final _active = CoilActiveItemController();
  late DateTime _cursor = _clamp(widget.month);

  /// The height of a row of months, and of a year's heading.
  double _row = 0;

  int get _firstYear => widget.firstMonth?.year ?? 1;
  int get _lastYear => widget.lastMonth?.year ?? CalendarMonthView.lastYear;

  @override
  void dispose() {
    _scroll?.dispose();
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

  /// A year's heading and four rows of months.
  double get _sectionExtent => _row * 5;

  void _move(int months) {
    final next = _clamp(DateTime(_cursor.year, _cursor.month + months));
    setState(() => _cursor = next);
    _active.activate(next.month - 1, via: CoilModality.keyboard);
    _reveal(next);
  }

  /// Scrolls just enough to show [month]'s row, with its year's heading
  /// when it's the first row, on the `standard` spring.
  void _reveal(DateTime month) {
    final scroll = _scroll;
    if (scroll == null || !scroll.hasClients) return;
    final position = scroll.position;
    final section = (month.year - _firstYear) * _sectionExtent;
    final rowTop = section + _row * (1 + (month.month - 1) ~/ 3);
    final top = (month.month - 1) < 3 ? section : rowTop;
    final bottom = rowTop + _row;
    final double target;
    if (top < position.pixels) {
      target = top;
    } else if (bottom > position.pixels + position.viewportDimension) {
      target = bottom - position.viewportDimension;
    } else {
      return;
    }
    final end = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    if (position is! ScrollPositionWithSingleContext) {
      position.jumpTo(end);
      return;
    }
    position.beginActivity(
      BallisticScrollActivity(
        position,
        motion.standard.createSimulation(start: position.pixels, end: end),
        position.context.vsync,
        false,
      ),
    );
  }

  void _pick(DateTime month, {required bool touch}) {
    if (!_enabled(month)) return;
    if (touch) unawaited(CoilHaptics.play(context, CoilHapticEvent.pick));
    widget.onPicked(month);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Rows as tall as the day grid's, so the months fill the space the
        // weeks did; whole pixels, so thousands of years add up exactly.
        _row = (math.max(0, constraints.maxWidth - widget.inset * 2) / 7)
            .roundToDouble();
        final extent = _sectionExtent;
        final count = _lastYear - _firstYear + 1;
        final viewport = constraints.maxHeight;
        // The month's own row in the middle (a year is about as tall as
        // the view, so centering the year can leave the month off it).
        final month = _clamp(widget.month);
        final rowTop =
            (month.year - _firstYear) * extent +
            _row * (1 + (month.month - 1) ~/ 3);
        _scroll ??= ScrollController(
          initialScrollOffset: (rowTop + _row / 2 - viewport / 2)
              .clamp(0, math.max(0, count * extent - viewport))
              .toDouble(),
        );
        return Shortcuts(
          shortcuts: {
            SingleActivator(
              rtl
                  ? LogicalKeyboardKey.arrowRight
                  : LogicalKeyboardKey.arrowLeft,
            ): const _MoveIntent(
              -1,
            ),
            SingleActivator(
              rtl
                  ? LogicalKeyboardKey.arrowLeft
                  : LogicalKeyboardKey.arrowRight,
            ): const _MoveIntent(
              1,
            ),
            const SingleActivator(LogicalKeyboardKey.arrowUp):
                const _MoveIntent(-3),
            const SingleActivator(LogicalKeyboardKey.arrowDown):
                const _MoveIntent(3),
            const SingleActivator(LogicalKeyboardKey.pageUp): const _MoveIntent(
              -12,
            ),
            const SingleActivator(LogicalKeyboardKey.pageDown):
                const _MoveIntent(12),
            const SingleActivator(LogicalKeyboardKey.enter):
                const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.numpadEnter):
                const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.space):
                const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.escape):
                const _CloseIntent(),
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
                child: CoilScrollEdgeFade(
                  extent: _row,
                  // Hands drags off to a sheet it sits in.
                  child: ScrollConfiguration(
                    behavior: CoilSheetRoute.scrollBehaviorOf(context),
                    child: ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.zero,
                      itemExtent: extent,
                      itemCount: count,
                      itemBuilder: (context, i) => _year(_firstYear + i),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// [year]'s heading and its twelve months.
  Widget _year(int year) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final radius = theme.shape.radii(metrics.tier).item;
    final current = year == _cursor.year;
    final selected = widget.selected;
    final selectedIndex = selected != null && selected.year == year
        ? selected.month - 1
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _row,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: metrics.itemPaddingX),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  header: true,
                  child: DefaultTextStyle(
                    style: text.muted.caption.copyWith(
                      fontWeight: text.emphasis,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: widget.year(year),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
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
                child: grid,
              ),
            ),
          ),
        ],
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
