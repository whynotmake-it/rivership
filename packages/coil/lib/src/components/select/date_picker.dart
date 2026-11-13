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
class CoilDatePicker extends StatefulWidget {
  /// Creates a date picker.
  const CoilDatePicker({
    required this.value,
    required this.onChanged,
    super.key,
    this.placeholder = 'Pick a date',
    this.icon,
    this.firstDate,
    this.lastDate,
    this.isDisabled,
    this.firstDayOfWeek = DateTime.monday,
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

  /// Shown in the field when no date is picked.
  final String placeholder;

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
    final text = value == null ? null : widget.labels.date(value);
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
          child: CoilCalendar(
            selected: value,
            autofocus: true,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            isDisabled: widget.isDisabled,
            firstDayOfWeek: widget.firstDayOfWeek,
            labels: widget.labels,
            motion: widget.motion,
            onSelected: (day) {
              widget.onChanged?.call(day);
              popup.close(CoilPopupCloseReason.selected);
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
          hint: text == null ? widget.placeholder : null,
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
                label: Text(
                  text ?? widget.placeholder,
                  style: text == null
                      ? TextStyle(color: style.placeholder)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
