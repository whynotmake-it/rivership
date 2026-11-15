import 'package:coil/calendar.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/select/select_style.dart';
import 'package:coil/src/components/select/select_trigger.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A field that opens a [CoilCalendar] to pick a date.
///
/// The calendar opens in a popover next to the field, or in a sheet on a
/// phone. Picking a day closes it. The field shows the date with
/// [CoilCalendarLabels.date], or [placeholder] when there is none. The
/// arrow keys on the field open the calendar with the keyboard on the
/// picked day.
///
/// With [withTime], two columns under the calendar pick the time of day,
/// and the popup stays open until dismissed.
class CoilDatePicker extends StatefulWidget {
  /// Creates a date picker.
  const CoilDatePicker({
    required this.value,
    required this.onChanged,
    super.key,
    this.placeholder = const Text('Pick a date'),
    this.icon,
    this.firstDate,
    this.lastDate,
    this.isDisabled,
    this.firstDayOfWeek = DateTime.monday,
    this.withTime = false,
    this.minuteInterval = 5,
    this.labels = const CoilCalendarLabels(),
    this.sheetTitle,
    this.presentation,
    this.size,
    this.focusNode,
    this.autofocus = false,
    this.motion,
    this.style,
    this.controller,
  });

  /// The picked date, or null.
  final DateTime? value;

  /// Called with the picked date. Null disables the picker.
  final ValueChanged<DateTime>? onChanged;

  /// Shown, muted, in the field when no date is picked. Usually a [Text].
  final Widget placeholder;

  /// A leading glyph in the field.
  final Widget? icon;

  /// The earliest day that can be picked.
  final DateTime? firstDate;

  /// The latest day that can be picked.
  final DateTime? lastDate;

  /// Returns true for days that can't be picked.
  final bool Function(DateTime day)? isDisabled;

  /// The weekday the calendar's rows start on.
  final int firstDayOfWeek;

  /// Whether a time of day is picked too, in two columns under the
  /// calendar. Picking a day then keeps the popup open.
  final bool withTime;

  /// The minute step of the time columns.
  final int minuteInterval;

  /// Month and weekday names, and how the field shows a date.
  final CoilCalendarLabels labels;

  /// A heading for the sheet presentation.
  final Widget? sheetTitle;

  /// Pins the presentation. Null decides per open.
  final CoilPresentation? presentation;

  /// Pins the field's size step.
  final CoilSize? size;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// Whether the field takes focus when first built.
  final bool autofocus;

  /// Motion tokens for the field, the calendar and the popup.
  final CoilMotion? motion;

  /// Overrides for the field's look, on top of the theme's
  /// [CoilSelectStyle].
  final CoilSelectStyle? style;

  /// Opens and closes the calendar from code.
  final CoilPopupController? controller;

  @override
  State<CoilDatePicker> createState() => _CoilDatePickerState();
}

class _CoilDatePickerState extends State<CoilDatePicker> {
  CoilPopupController? _ownPopup;
  final _states = WidgetStatesController();

  CoilPopupController get _popup =>
      widget.controller ?? (_ownPopup ??= CoilPopupController());
  bool get _enabled => widget.onChanged != null;

  @override
  void dispose() {
    _ownPopup?.dispose();
    _states.dispose();
    super.dispose();
  }

  void _open() {
    if (_enabled) _popup.open();
  }

  CoilSelectStyle _style(BuildContext context, CoilMetrics metrics) =>
      CoilSelectStyle.fallback(
        CoilTheme.of(context),
        metrics,
      ).merge(CoilTheme.styleOf<CoilSelectStyle>(context)).merge(widget.style);

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final style = _style(context, metrics);
    final value = widget.value;
    final text = value == null
        ? null
        : widget.labels.dateLabel(value, withTime: widget.withTime);
    return CoilAdaptivePopup(
      controller: _popup,
      presentation: widget.presentation,
      motion: widget.motion,
      traits: () => const CoilOverlayTraits(
        kind: CoilOverlayKind.dateTime,
        itemCount: 0,
      ),
      content: (context, popup) => Padding(
        padding: EdgeInsets.all(CoilTheme.metricsOf(context).popupInset * 2),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: _DateTimePanel(
            initial: value,
            withTime: widget.withTime,
            minuteInterval: widget.minuteInterval,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            isDisabled: widget.isDisabled,
            firstDayOfWeek: widget.firstDayOfWeek,
            labels: widget.labels,
            motion: widget.motion,
            onChanged: (date, {required bool day}) {
              widget.onChanged?.call(date);
              if (day && !widget.withTime) {
                popup.close(CoilPopupCloseReason.selected);
              }
            },
          ),
        ),
      ),
      popover: (context, content) {
        final metrics = CoilTheme.metricsOf(context);
        final style = _style(context, metrics);
        return CoilPopoverSurface(
          color: style.surface,
          radius: style.radius! + metrics.popupInset * 2,
          child: content,
        );
      },
      sheet: (context, content) =>
          CoilSheetPanel(title: widget.sheetTitle, child: content),
      child: ListenableBuilder(
        listenable: _popup,
        builder: (context, _) => Semantics(
          button: true,
          enabled: _enabled,
          expanded: _popup.isOpen,
          value: text,
          onTap: _enabled ? _open : null,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): _open,
              const SingleActivator(LogicalKeyboardKey.arrowUp): _open,
            },
            child: CoilInteraction(
              onPressed: _enabled ? _open : null,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              statesController: _states,
              excludeFromSemantics: true,
              builder: (context, states, _) => CoilSelectTrigger(
                metrics: metrics,
                style: style,
                states: {...states, if (_popup.isOpen) WidgetState.selected},
                icon: widget.icon,
                label: ExcludeSemantics(
                  excluding: value != null,
                  child: value == null
                      ? DefaultTextStyle.merge(
                          style: TextStyle(color: style.placeholder),
                          child: widget.placeholder,
                        )
                      : widget.labels.date(value, withTime: widget.withTime),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The popup's content: the calendar and, with [withTime], the time
/// columns. It keeps its own copy of the value, because a sheet doesn't
/// rebuild with the picker.
class _DateTimePanel extends StatefulWidget {
  const _DateTimePanel({
    required this.initial,
    required this.withTime,
    required this.minuteInterval,
    required this.firstDate,
    required this.lastDate,
    required this.isDisabled,
    required this.firstDayOfWeek,
    required this.labels,
    required this.motion,
    required this.onChanged,
  });

  final DateTime? initial;
  final bool withTime;
  final int minuteInterval;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool Function(DateTime day)? isDisabled;
  final int firstDayOfWeek;
  final CoilCalendarLabels labels;
  final CoilMotion? motion;

  /// Called with each change, and whether it was a day that was picked.
  final void Function(DateTime value, {required bool day}) onChanged;

  @override
  State<_DateTimePanel> createState() => _DateTimePanelState();
}

class _DateTimePanelState extends State<_DateTimePanel> {
  late DateTime? _value = widget.initial;

  void _set(DateTime value, {required bool day}) {
    setState(() => _value = value);
    widget.onChanged(value, day: day);
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final calendar = CoilCalendar(
      selected: value,
      autofocus: true,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      isDisabled: widget.isDisabled,
      firstDayOfWeek: widget.firstDayOfWeek,
      labels: widget.labels,
      motion: widget.motion,
      onSelected: (day) => _set(
        DateTime(
          day.year,
          day.month,
          day.day,
          value?.hour ?? 0,
          value?.minute ?? 0,
        ),
        day: true,
      ),
    );
    if (!widget.withTime) return calendar;
    final now = value ?? DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CoilTheme.metricsOf(context).gap * 2,
      children: [
        calendar,
        CoilTimeColumns(
          value: (hour: now.hour, minute: now.minute),
          minuteInterval: widget.minuteInterval,
          onChanged: (time) => _set(
            DateTime(now.year, now.month, now.day, time.hour, time.minute),
            day: false,
          ),
        ),
      ],
    );
  }
}
