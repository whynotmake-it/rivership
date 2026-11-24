/// @docImport 'package:coil/calendar.dart';
library;

import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/calendar/calendar_layout.dart';
import 'package:coil/src/components/calendar/time_entry.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A time of day, picked in snapping columns: hours and minutes, and AM or
/// PM on a 12-hour clock.
///
/// The clock follows the locale ([MediaQuery.alwaysUse24HourFormatOf]):
/// hours 00 to 23, or 1 to 12 with a short AM and PM column after the
/// minutes.
///
/// **Touch.** Drag or flick a column: it keeps its momentum, lands on a
/// row, and wraps around (AM and PM don't). Each row that passes the band
/// ticks a haptic. Tap a number above or below the band and it glides into
/// it on the same spring. Tap the picked hour or minute, or the band, and
/// the number pad opens, as in iOS's time picker: type the digits of the
/// time ("1", "4", "3", "0" is 14:30), and the columns turn to show what's
/// typed. A ring around the band says the digits go there; Done on the
/// keyboard, or a tap elsewhere, ends it. On a 12-hour clock the digits fill
/// the hour and the minute, and AM or PM stays.
///
/// **Keyboard.** Tab reaches the columns, one stop each. Up and Down step a
/// column (the hour, one hour; the minute, [minuteInterval]), Page Up and
/// Page Down step 6 hours or 15 minutes, Home and End go to the first and
/// last value, and Left and Right move between the columns (mirrored in
/// right-to-left text). Digits type into the column: two digits make a
/// number ("1" then "4" is 14), and one that can't start a two-digit number
/// ("7" for an hour) is the whole number at once; a pause of a second starts
/// over. On a 12-hour clock "a" and "p" set AM and PM.
///
/// Minutes step by [minuteInterval]; a [value] between steps shows the step
/// below it, and a minute typed between steps lands on the nearest one.
/// Screen readers adjust each column up and down, named by [hourLabel],
/// [minuteLabel] and [periodLabel].
///
/// The columns show [visibleRows] rows, each a line of body text (tabular
/// figures) and the tier's gap, grown with the text scale: 28 tall on
/// pointer, 34 on touch. The picked row sits in an `active` band with the
/// day cells' radius; the rows fade out toward the top and bottom edges.
///
/// A pointer has [CoilTimeField] to type in instead.
class CoilTimeColumns extends StatefulWidget {
  /// Creates the time columns.
  const CoilTimeColumns({
    required this.value,
    required this.onChanged,
    super.key,
    this.minuteInterval = 5,
    this.hourLabel = 'Hour',
    this.minuteLabel = 'Minute',
    this.periodLabel = 'AM/PM',
    this.motion,
  }) : assert(
         minuteInterval > 0 && 60 % minuteInterval == 0,
         'minuteInterval must divide 60.',
       );

  /// The time shown, in 24-hour form.
  final ({int hour, int minute}) value;

  /// Called as a column settles on a new value, in 24-hour form.
  final ValueChanged<({int hour, int minute})>? onChanged;

  /// The minute step.
  final int minuteInterval;

  /// The hour column's name for screen readers.
  final String hourLabel;

  /// The minute column's name for screen readers.
  final String minuteLabel;

  /// The AM and PM column's name for screen readers.
  final String periodLabel;

  /// Overrides the theme's motion tokens; a column settles on
  /// [CoilMotion.standard].
  final CoilMotion? motion;

  /// How many rows the columns show: the picked one and two on each side.
  static const visibleRows = 5;

  @override
  State<CoilTimeColumns> createState() => _CoilTimeColumnsState();
}

class _CoilTimeColumnsState extends State<CoilTimeColumns> {
  /// How long a pause lasts before typed digits start a new number.
  static const _typeTimeout = Duration(seconds: 1);

  final _focus = {
    for (final part in TimeSegment.values)
      part: FocusNode(debugLabel: 'CoilTimeColumns ${part.name}'),
  };
  final _input = TextEditingController();
  final _inputFocus = FocusNode(debugLabel: 'CoilTimeColumns number pad');

  /// Whether the number pad is up, and the digits go to the band.
  var _typing = false;

  /// The time when the number pad came up: the digits fill in from it.
  var _start = (hour: 0, minute: 0);

  /// Digits typed on a hardware keyboard into [_bufferPart], waiting for a
  /// second one.
  var _buffer = '';
  TimeSegment? _bufferPart;
  Timer? _bufferTimer;

  @override
  void initState() {
    super.initState();
    _inputFocus.addListener(_onInputFocus);
  }

  @override
  void dispose() {
    _bufferTimer?.cancel();
    _inputFocus
      ..removeListener(_onInputFocus)
      ..dispose();
    _input.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onInputFocus() {
    if (_typing == _inputFocus.hasFocus) return;
    setState(() => _typing = _inputFocus.hasFocus);
  }

  bool get _use24 => MediaQuery.alwaysUse24HourFormatOf(context);

  void _report(({int hour, int minute}) time) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    if (time == widget.value) return;
    onChanged(time);
  }

  void _beginTyping() {
    if (widget.onChanged == null) return;
    _start = widget.value;
    _input.clear();
    if (_inputFocus.hasFocus) {
      // Typing already, the keyboard may have been put away.
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    } else {
      _inputFocus.requestFocus();
    }
  }

  void _endTyping() {
    if (_inputFocus.hasFocus) _inputFocus.unfocus();
  }

  /// The number pad's digits: the hour first, then the minute.
  void _onDigits(String digits) => _report(
    _snapped(
      timeFromDigits(digits, start: _start, use24HourFormat: _use24),
    ),
  );

  ({int hour, int minute}) _snapped(({int hour, int minute}) time) => (
    hour: time.hour,
    minute: snapMinute(time.minute, interval: widget.minuteInterval),
  );

  void _setPeriod({required bool pm}) {
    final value = widget.value;
    _report((hour: value.hour % 12 + (pm ? 12 : 0), minute: value.minute));
  }

  /// A digit on a hardware keyboard, into [part]'s column.
  void _typeDigit(TimeSegment part, int digit) {
    if (_bufferPart != part) _buffer = '';
    _bufferPart = part;
    final entry = typeDigit(
      _buffer,
      digit,
      segment: part,
      use24HourFormat: _use24,
    );
    _buffer = entry.buffer;
    _bufferTimer?.cancel();
    _bufferTimer = Timer(_typeTimeout, () => _buffer = '');
    final value = entry.value;
    if (value == null) return;
    final time = widget.value;
    _report(
      part == TimeSegment.hour
          ? (
              hour: _use24
                  ? value
                  : hourFrom12HourClock(value, pm: time.hour >= 12),
              minute: time.minute,
            )
          : _snapped((hour: time.hour, minute: value)),
    );
  }

  /// Moves focus [by] columns along the row, as the arrows read on screen.
  void _moveFocus(TimeSegment from, int by) {
    final parts = [
      TimeSegment.hour,
      TimeSegment.minute,
      if (!_use24) TimeSegment.period,
    ];
    final next = parts.indexOf(from) + by;
    if (next < 0 || next >= parts.length) return;
    _buffer = '';
    _focus[parts[next]]!.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
    final extent = calendarTimeRowExtent(context, metrics, text.body);
    // As wide as a calendar day and a half: the two digits, with room to
    // grab either column.
    final width = calendarWidths(context).cell * 1.5;
    final radius = BorderRadius.circular(theme.shape.radii(metrics.tier).item);
    final use24 = _use24;
    final value = widget.value;
    final interval = widget.minuteInterval;
    final minuteSteps = 60 ~/ interval;
    final enabled = widget.onChanged != null;
    final hour = value.hour;

    _Column column({
      required TimeSegment part,
      required String label,
      required int count,
      required int index,
      required String Function(int index) text,
      required ValueChanged<int> onChanged,
      required int page,
      bool loop = true,
    }) => _Column(
      // A column of another length starts over.
      key: ValueKey((part, use24, count)),
      label: label,
      count: count,
      loop: loop,
      index: index,
      page: page,
      extent: extent,
      width: width,
      motion: widget.motion,
      text: text,
      focusNode: _focus[part]!,
      onChanged: enabled ? onChanged : null,
      onDigit: part == TimeSegment.period
          ? null
          : (digit) => _typeDigit(part, digit),
      onPeriod: use24 ? null : (pm) => _setPeriod(pm: pm),
      onMove: (by) => _moveFocus(part, by),
      onCenterTap: part == TimeSegment.period ? null : _beginTyping,
      onRowTap: _endTyping,
    );

    return TapRegion(
      enabled: _typing,
      onTapOutside: (_) => _endTyping(),
      child: SizedBox(
        height: extent * CoilTimeColumns.visibleRows,
        child: Stack(
          alignment: Alignment.center,
          // The ring around the band reaches past it.
          clipBehavior: Clip.none,
          children: [
            // The band the picked values sit in: the selected fill, with the
            // day cells' corners. A tap on it types, as one on the picked
            // numbers does.
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _beginTyping,
                  child: SizedBox(
                    height: extent,
                    width: double.infinity,
                    // Typing is on while the number pad is up, whatever
                    // brought it.
                    child: CoilFocusRing(
                      visible: _typing,
                      borderRadius: radius,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: theme.colors.active,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: radius,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // On the narrowest windows (a floating panel's margins take 16 of
            // 240) the columns shrink with their numbers, as the days do.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                height: extent * CoilTimeColumns.visibleRows,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (use24)
                      column(
                        part: TimeSegment.hour,
                        label: widget.hourLabel,
                        count: 24,
                        index: hour,
                        page: 6,
                        text: (i) => hourText(i, use24HourFormat: true),
                        onChanged: (i) =>
                            _report((hour: i, minute: value.minute)),
                      )
                    else
                      column(
                        part: TimeSegment.hour,
                        label: widget.hourLabel,
                        count: 12,
                        index: hourOn12HourClock(hour) - 1,
                        page: 6,
                        text: (i) => '${i + 1}',
                        onChanged: (i) => _report((
                          hour: hourFrom12HourClock(i + 1, pm: hour >= 12),
                          minute: value.minute,
                        )),
                      ),
                    ExcludeSemantics(
                      child: Text(
                        ':',
                        style: text.body.tabular.copyWith(
                          fontWeight: text.emphasis,
                        ),
                      ),
                    ),
                    column(
                      part: TimeSegment.minute,
                      label: widget.minuteLabel,
                      count: minuteSteps,
                      index: value.minute ~/ interval,
                      page: (15 ~/ interval).clamp(1, minuteSteps),
                      text: (i) => minuteText(i * interval),
                      onChanged: (i) =>
                          _report((hour: hour, minute: i * interval)),
                    ),
                    if (!use24)
                      column(
                        part: TimeSegment.period,
                        label: widget.periodLabel,
                        count: 2,
                        index: hour >= 12 ? 1 : 0,
                        page: 1,
                        loop: false,
                        text: (i) => periodNames[i],
                        onChanged: (i) => _setPeriod(pm: i == 1),
                      ),
                  ],
                ),
              ),
            ),
            // Where the number pad's digits go. It is never seen: the band
            // and the columns show what's typed.
            IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 0,
                  child: SizedBox.square(
                    dimension: 1,
                    child: CoilTextFieldCore(
                      controller: _input,
                      focusNode: _inputFocus,
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      keyboardAppearance: theme.brightness,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: _onDigits,
                      onSubmitted: (_) => _endTyping(),
                      // A hardware keyboard sets AM and PM here too.
                      shortcuts: use24 ? const {} : _periodShortcuts,
                      actions: {
                        _PeriodIntent: CallbackAction<_PeriodIntent>(
                          onInvoke: (intent) => _setPeriod(pm: intent.pm),
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "a" and "p", in either case: AM and PM.
const _periodShortcuts = <ShortcutActivator, Intent>{
  CharacterActivator('a'): _PeriodIntent(pm: false),
  CharacterActivator('A'): _PeriodIntent(pm: false),
  CharacterActivator('p'): _PeriodIntent(pm: true),
  CharacterActivator('P'): _PeriodIntent(pm: true),
};

/// One column of [count] values that snaps to a row.
class _Column extends StatefulWidget {
  const _Column({
    required super.key,
    required this.label,
    required this.count,
    required this.loop,
    required this.index,
    required this.page,
    required this.extent,
    required this.width,
    required this.text,
    required this.focusNode,
    required this.onChanged,
    required this.onDigit,
    required this.onPeriod,
    required this.onMove,
    required this.onCenterTap,
    required this.onRowTap,
    required this.motion,
  });

  final CoilMotion? motion;
  final String label;
  final int count;

  /// Whether the column wraps around.
  final bool loop;
  final int index;

  /// How many rows Page Up and Page Down move.
  final int page;
  final double extent;
  final double width;
  final String Function(int index) text;
  final FocusNode focusNode;
  final ValueChanged<int>? onChanged;

  /// A digit typed on the keyboard.
  ///
  /// Null: the column takes none.
  final ValueChanged<int>? onDigit;

  /// "a" or "p" typed on the keyboard.
  ///
  /// Null: the column takes none.
  final ValueChanged<bool>? onPeriod;

  /// Left or Right: to the previous or the next column, -1 or 1.
  final ValueChanged<int> onMove;

  /// A tap on the picked row.
  ///
  /// Null: it does nothing.
  final VoidCallback? onCenterTap;

  /// A tap on another row.
  final VoidCallback onRowTap;

  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> {
  late final _scroll = FixedExtentScrollController(
    initialItem: widget.index,
  );

  /// The last row the wheel itself settled on, as opposed to one the value
  /// moved it to.
  int? _reported;

  /// Whether a glide that [_follow] started is under way: the value already
  /// has its end, so the rows it passes only tick.
  bool _gliding = false;

  /// Whether the wheel was already moving when the pointer came down: a tap
  /// that stops a fling isn't a tap on a row.
  bool _wasMoving = false;

  @override
  void didUpdateWidget(_Column oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follows a value changed from outside, the short way round.
    if (widget.index != oldWidget.index && widget.index != _reported) {
      _follow();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow() {
    if (!_scroll.hasClients) return;
    final shown = widget.loop
        ? _scroll.selectedItem % widget.count
        : _scroll.selectedItem;
    if (shown == widget.index) return;
    var delta = widget.index - shown;
    if (widget.loop) {
      if (delta > widget.count / 2) delta -= widget.count;
      if (delta < -widget.count / 2) delta += widget.count;
    }
    unawaited(_glideTo(_scroll.selectedItem + delta));
  }

  /// Springs to [item] on the theme's [CoilMotion.standard] spring.
  Future<void> _glideTo(int item) async {
    final motion = calendarSnapMotion(
      CoilTheme.motionOf(context, override: widget.motion).standard,
    );
    final simulation = motion.createSimulation();
    var seconds = 0.0;
    while (!simulation.isDone(seconds) && seconds < 3) {
      seconds += 1 / 120;
    }
    _gliding = true;
    try {
      await _scroll.animateToItem(
        item,
        duration: Duration(microseconds: (seconds * 1e6).round()),
        curve: _SpringCurve(simulation, seconds),
      );
    } finally {
      _gliding = false;
    }
  }

  void _step(int by) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    final next = widget.loop
        ? (widget.index + by) % widget.count
        : (widget.index + by).clamp(0, widget.count - 1);
    if (next != widget.index) onChanged(next);
  }

  void _stepTo(int index) {
    if (index != widget.index) widget.onChanged?.call(index);
  }

  /// A tap [dy] down the column: a row is jumped to, and the picked one
  /// types.
  void _tap(double dy) {
    if (_wasMoving || widget.onChanged == null) return;
    final rows =
        ((dy - widget.extent * CoilTimeColumns.visibleRows / 2) / widget.extent)
            .round();
    if (rows == 0) {
      widget.onCenterTap?.call();
      return;
    }
    widget.onRowTap();
    if (widget.loop) {
      widget.onChanged!((widget.index + rows) % widget.count);
    } else if (widget.index + rows >= 0 && widget.index + rows < widget.count) {
      widget.onChanged!(widget.index + rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final enabled = widget.onChanged != null;
    final canIncrease =
        enabled && (widget.loop || widget.index < widget.count - 1);
    final canDecrease = enabled && (widget.loop || widget.index > 0);
    final onDigit = widget.onDigit;
    final onPeriod = widget.onPeriod;
    return Semantics(
      label: widget.label,
      value: widget.text(widget.index),
      increasedValue: canIncrease
          ? widget.text((widget.index + 1) % widget.count)
          : null,
      decreasedValue: canDecrease
          ? widget.text((widget.index - 1) % widget.count)
          : null,
      onIncrease: canIncrease ? () => _step(1) : null,
      onDecrease: canDecrease ? () => _step(-1) : null,
      child: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): const _StepIntent(
            -1,
          ),
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              const _StepIntent(1),
          const SingleActivator(LogicalKeyboardKey.pageUp): _StepIntent(
            -widget.page,
          ),
          const SingleActivator(LogicalKeyboardKey.pageDown): _StepIntent(
            widget.page,
          ),
          const SingleActivator(LogicalKeyboardKey.home): const _EdgeIntent(
            last: false,
          ),
          const SingleActivator(LogicalKeyboardKey.end): const _EdgeIntent(
            last: true,
          ),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(
            rtl ? 1 : -1,
          ),
          const SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(
            rtl ? -1 : 1,
          ),
          if (onDigit != null)
            for (var digit = 0; digit < 10; digit++)
              CharacterActivator('$digit'): _DigitIntent(digit),
          if (onPeriod != null) ..._periodShortcuts,
        },
        child: Actions(
          actions: {
            _StepIntent: CallbackAction<_StepIntent>(
              onInvoke: (intent) => _step(intent.by),
            ),
            _EdgeIntent: CallbackAction<_EdgeIntent>(
              onInvoke: (intent) => _stepTo(intent.last ? widget.count - 1 : 0),
            ),
            _MoveIntent: CallbackAction<_MoveIntent>(
              onInvoke: (intent) => widget.onMove(intent.by),
            ),
            _DigitIntent: CallbackAction<_DigitIntent>(
              onInvoke: (intent) => onDigit?.call(intent.digit),
            ),
            _PeriodIntent: CallbackAction<_PeriodIntent>(
              onInvoke: (intent) => onPeriod?.call(intent.pm),
            ),
          },
          child: Focus(
            focusNode: widget.focusNode,
            canRequestFocus: enabled,
            child: ListenableBuilder(
              listenable: widget.focusNode,
              builder: (context, child) => CoilFocusRing(
                visible:
                    widget.focusNode.hasFocus &&
                    CoilInputModality.instance.value == CoilModality.keyboard,
                borderRadius: BorderRadius.circular(
                  theme.shape.radii(metrics.tier).item,
                ),
                child: child!,
              ),
              child: SizedBox(
                width: widget.width,
                child: Listener(
                  onPointerDown: (_) => _wasMoving =
                      _scroll.hasClients &&
                      _scroll.position.isScrollingNotifier.value,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _tap(details.localPosition.dy),
                    child: ExcludeSemantics(
                      // The rows fade out over two rows toward each edge.
                      child: CoilScrollEdgeFade(
                        extent: widget.extent * 2,
                        child: ListWheelScrollView.useDelegate(
                          controller: _scroll,
                          itemExtent: widget.extent,
                          // Hands drags off to a sheet it sits in.
                          scrollBehavior: CoilSheetRoute.scrollBehaviorOf(
                            context,
                          ),
                          physics: CalendarWheelPhysics(
                            motion: CoilTheme.motionOf(
                              context,
                              override: widget.motion,
                            ).standard,
                          ),
                          // Nearly flat rows, as the design asks: no 3D drum.
                          diameterRatio: 8,
                          onSelectedItemChanged: (i) {
                            final index = widget.loop ? i % widget.count : i;
                            if (index == widget.index) return;
                            unawaited(
                              CoilHaptics.play(
                                context,
                                CoilHapticEvent.toggle,
                              ),
                            );
                            // A glide's end is already the value.
                            if (_gliding) return;
                            _reported = index;
                            widget.onChanged?.call(index);
                          },
                          childDelegate: _delegate(text),
                        ),
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

  ListWheelChildDelegate _delegate(CoilTextTheme text) {
    final rows = [
      for (var i = 0; i < widget.count; i++)
        Center(
          child: Text(
            widget.text(i),
            maxLines: 1,
            softWrap: false,
            style: i == widget.index
                ? text.body.tabular.copyWith(fontWeight: text.emphasis)
                : text.muted.body.tabular,
          ),
        ),
    ];
    return widget.loop
        ? ListWheelChildLoopingListDelegate(children: rows)
        : ListWheelChildListDelegate(children: rows);
  }
}

/// A spring's run from 0 to 1 as a curve over its [seconds] to rest.
class _SpringCurve extends Curve {
  const _SpringCurve(this.simulation, this.seconds);

  final Simulation simulation;
  final double seconds;

  @override
  double transformInternal(double t) => simulation.x(t * seconds);
}

/// Steps a column [by] rows: Up, Down, Page Up and Page Down.
class _StepIntent extends Intent {
  const _StepIntent(this.by);

  final int by;
}

/// Goes to a column's first or [last] row: Home and End.
class _EdgeIntent extends Intent {
  const _EdgeIntent({required this.last});

  final bool last;
}

/// Moves to the previous or the next column, [by] -1 or 1.
class _MoveIntent extends Intent {
  const _MoveIntent(this.by);

  final int by;
}

/// A [digit] typed on the keyboard.
class _DigitIntent extends Intent {
  const _DigitIntent(this.digit);

  final int digit;
}

/// "a" or "p" typed on the keyboard: AM, or [pm].
class _PeriodIntent extends Intent {
  const _PeriodIntent({required this.pm});

  final bool pm;
}
