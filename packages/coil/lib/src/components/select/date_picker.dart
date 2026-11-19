import 'package:coil/button.dart';
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
/// phone. The field shows the date with [CoilCalendarLabels.date], or
/// [placeholder] when there is none. The arrow keys on the field open the
/// calendar with the keyboard on the picked day.
///
/// What's picked in the open calendar is a draft until it's confirmed;
/// closing it any other way (the sheet's close button, the scrim, a drag
/// down, back, Escape, a tap outside a popover) leaves [value] as it was:
///
/// - **Popover, date only:** a day is the whole answer, so picking one
///   confirms it and closes the popover, as iOS's compact picker and the
///   web's date pickers do.
/// - **Popover with time, and every sheet:** a pinned **Done** button
///   ([CoilCalendarLabels.confirm]) confirms. A day and a time are two
///   answers, and a sheet takes a whole screen's attention, so there is no
///   tap that could close it without cutting a choice short; Material's
///   modal pickers confirm with OK for the same reason.
///   The footer names what Done will confirm on its leading side
///   ([CoilCalendarLabels.summary]), so the draft stays readable however
///   far the calendar has paged or zoomed; before a pick it shows
///   [placeholder], muted.
/// - **Keyboard:** Enter confirms the draft (on the grid, it picks the
///   focused day first); Space only picks; Escape cancels.
///
/// With [withTime], two columns under the calendar pick the time of day.
/// In a short, wide window (a phone in landscape) they sit beside the
/// calendar instead.
///
/// The popover is as wide as the calendar's seven cells. A sheet's
/// calendar fills the sheet up to days 20 % bigger than their natural
/// size, and centers in a wider one: days are always square. Either
/// scrolls when the window is too short for it.
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

  /// Called with the confirmed date. Null disables the picker.
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
  /// calendar. The popover then confirms with a button, like the sheet.
  final bool withTime;

  /// The minute step of the time columns.
  final int minuteInterval;

  /// Month and weekday names, how the field shows a date, and the confirm
  /// button's label.
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

  /// What the open calendar has picked, not yet confirmed. Each open
  /// starts it from [CoilDatePicker.value]; the sheet's footer and the
  /// panel both follow it.
  final _draft = ValueNotifier<DateTime?>(null);

  /// The open popup that has confirmed, so a confirm reports once.
  CoilPopupHandle? _confirmed;

  bool _wasOpen = false;

  CoilPopupController get _popup =>
      widget.controller ?? (_ownPopup ??= CoilPopupController());
  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _popup.addListener(_onPopup);
  }

  @override
  void didUpdateWidget(CoilDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? _ownPopup;
    if (old != _popup) {
      old?.removeListener(_onPopup);
      _popup.addListener(_onPopup);
      _wasOpen = _popup.isOpen;
    }
  }

  @override
  void dispose() {
    _popup.removeListener(_onPopup);
    _ownPopup?.dispose();
    _states.dispose();
    _draft.dispose();
    super.dispose();
  }

  /// A fresh draft for each open.
  void _onPopup() {
    final open = _popup.isOpen;
    if (open && !_wasOpen) _draft.value = widget.value;
    _wasOpen = open;
  }

  void _open() {
    if (_enabled) _popup.open();
  }

  /// Sets the draft as the value and closes [popup].
  void _confirm(CoilPopupHandle popup) {
    final draft = _draft.value;
    if (draft == null || identical(_confirmed, popup)) return;
    _confirmed = popup;
    if (draft != widget.value) widget.onChanged?.call(draft);
    popup.close(CoilPopupCloseReason.selected);
  }

  CoilSelectStyle _style(BuildContext context, CoilMetrics metrics) =>
      CoilSelectStyle.fallback(
        CoilTheme.of(context),
        metrics,
      ).merge(CoilTheme.styleOf<CoilSelectStyle>(context)).merge(widget.style);

  /// The footer: what Done will confirm on the leading side, and Done,
  /// which confirms once something is picked, on the trailing side.
  Widget _footer(CoilPopupHandle popup) => ValueListenableBuilder<DateTime?>(
    valueListenable: _draft,
    builder: (context, draft, _) => _DraftFooter(
      summary: draft == null
          ? null
          : Semantics(
              label: widget.labels.summaryLabel(
                draft,
                withTime: widget.withTime,
              ),
              excludeSemantics: true,
              child: widget.labels.summary(draft, withTime: widget.withTime),
            ),
      action: CoilButton(
        onPressed: draft == null ? null : () => _confirm(popup),
        child: widget.labels.confirm,
      ),
    ),
  );

  Widget _content(BuildContext context, CoilPopupHandle popup) {
    final sheet = popup.presentation == CoilPresentation.sheet;
    // Only a popover picking a date alone has a tap that is the whole
    // answer.
    final confirmOnPick = !sheet && !widget.withTime;
    final metrics = CoilTheme.metricsOf(context);
    final panel = _DateTimePanel(
      draft: _draft,
      withTime: widget.withTime,
      minuteInterval: widget.minuteInterval,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      isDisabled: widget.isDisabled,
      firstDayOfWeek: widget.firstDayOfWeek,
      labels: widget.labels,
      motion: widget.motion,
      onDayPicked: () {
        if (confirmOnPick) _confirm(popup);
      },
      onSubmitted: () => _confirm(popup),
    );
    // Everything lines up with the days, which sit [edge] inside the
    // calendar's box: in a sheet, on the sheet's text inset (where its
    // title and footer start); in a popover, [edge] inside its padding.
    final edge = CoilCalendar.edgeInsetOf(context);
    final touch = CoilTheme.of(
      context,
    ).metrics.resolve(CoilTier.touch, CoilSize.regular);
    final side = touch.popupInset + touch.itemPaddingX;
    // Scrolls when the window is too short for it (a phone in landscape,
    // large text). The popover hugs the calendar's width; a sheet's width
    // is the calendar's to fill.
    final scroll = SingleChildScrollView(
      // A popover's scroll view isn't the page's primary one; a sheet's is
      // the sheet's, so a drag hands off to dismissing it.
      primary: sheet ? null : false,
      child: Padding(
        padding: sheet
            ? EdgeInsets.symmetric(
                horizontal: side - edge,
                vertical: metrics.popupInset * 2,
              )
            : EdgeInsets.all(metrics.popupInset * 2),
        child: sheet || !widget.withTime
            ? panel
            : CoilCalendarWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: metrics.gap * 2,
                  children: [
                    panel,
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: edge),
                      child: _footer(popup),
                    ),
                  ],
                ),
              ),
      ),
    );
    // Enter anywhere in the popup confirms; the grid picks its focused day
    // first, and a focused button presses itself. Escape cancels, from a
    // sheet too (the month view takes it first, to go back to the days).
    final content = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): _ConfirmIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _ConfirmIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
      },
      child: Actions(
        actions: {
          _ConfirmIntent: CallbackAction<_ConfirmIntent>(
            onInvoke: (_) => _confirm(popup),
          ),
          _CancelIntent: CallbackAction<_CancelIntent>(
            onInvoke: (_) => popup.close(CoilPopupCloseReason.escape),
          ),
        },
        child: scroll,
      ),
    );
    if (!sheet) return content;
    // The sheet pins the footer under the calendar, on the same edge as
    // the title and the days.
    return CoilSheetPanel(
      title: widget.sheetTitle,
      footer: Padding(
        padding: EdgeInsets.symmetric(horizontal: side),
        child: _footer(popup),
      ),
      child: content,
    );
  }

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
      // The popover hugs the calendar, not the field: a calendar centered
      // in a field-wide popover has edges nothing else lines up with.
      minWidth: 0,
      traits: () => const CoilOverlayTraits(
        kind: CoilOverlayKind.dateTime,
        itemCount: 0,
      ),
      content: _content,
      popover: (context, content) {
        final metrics = CoilTheme.metricsOf(context);
        final style = _style(context, metrics);
        return CoilPopoverSurface(
          color: style.surface,
          radius: style.radius! + metrics.popupInset * 2,
          child: content,
        );
      },
      // The content builds its own panel, with the footer that confirms.
      sheet: (context, content) => content,
      child: ListenableBuilder(
        listenable: _popup,
        builder: (context, _) => Semantics(
          button: true,
          enabled: _enabled,
          expanded: _popup.isOpen,
          value: text,
          onTap: _enabled ? _open : null,
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.arrowDown): _OpenIntent(),
              SingleActivator(LogicalKeyboardKey.arrowUp): _OpenIntent(),
            },
            child: Actions(
              actions: {
                _OpenIntent: CallbackAction<_OpenIntent>(
                  onInvoke: (_) => _open(),
                ),
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
      ),
    );
  }
}

/// A date picker's footer: the [summary] of what [action] confirms on the
/// leading side, nothing before anything is picked, and [action] on the
/// trailing side at its own width (DESIGN.md §13.5).
///
/// [action] never gives up width: the summary takes what's left, wraps
/// onto a second line and then ends in an ellipsis, so large text on a
/// narrow phone squeezes the date, never the button. The summary isn't a
/// button; tapping it does nothing.
class _DraftFooter extends StatelessWidget {
  const _DraftFooter({required this.summary, required this.action});

  /// What [action] will confirm, or null when nothing is picked.
  final Widget? summary;

  /// The confirming button.
  final Widget action;

  /// The summary's lines before it ends in an ellipsis.
  static const maxLines = 2;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final summary = this.summary;
    return Row(
      spacing: CoilTheme.metricsOf(context).gap * 2,
      children: [
        Expanded(
          child: DefaultTextStyle(
            style: text.body.tabular,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            child: summary ?? const SizedBox.shrink(),
          ),
        ),
        CoilActionBar(layout: CoilActionBarLayout.row, actions: [action]),
      ],
    );
  }
}

/// Opens the popup from the keyboard: Up or Down on the trigger.
class _OpenIntent extends Intent {
  const _OpenIntent();
}

/// Confirms the draft: Enter in the popup.
class _ConfirmIntent extends Intent {
  const _ConfirmIntent();
}

/// Closes the popup without confirming: Escape.
class _CancelIntent extends Intent {
  const _CancelIntent();
}

/// The popup's content: the calendar and, with [withTime], the time
/// columns, editing [draft].
class _DateTimePanel extends StatefulWidget {
  const _DateTimePanel({
    required this.draft,
    required this.withTime,
    required this.minuteInterval,
    required this.firstDate,
    required this.lastDate,
    required this.isDisabled,
    required this.firstDayOfWeek,
    required this.labels,
    required this.motion,
    required this.onDayPicked,
    required this.onSubmitted,
  });

  final ValueNotifier<DateTime?> draft;
  final bool withTime;
  final int minuteInterval;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool Function(DateTime day)? isDisabled;
  final int firstDayOfWeek;
  final CoilCalendarLabels labels;
  final CoilMotion? motion;

  /// Called after a day is picked into [draft].
  final VoidCallback onDayPicked;

  /// Called when Enter picks a day on the grid.
  final VoidCallback onSubmitted;

  @override
  State<_DateTimePanel> createState() => _DateTimePanelState();
}

class _DateTimePanelState extends State<_DateTimePanel> {
  /// On the touch tier, windows wider than tall and shorter than this (a
  /// phone in landscape) put the time beside the calendar.
  static const sideBySideHeight = 600.0;

  /// The time the columns show before anything is picked: when it opened,
  /// on the minute step below.
  late final ({int hour, int minute}) _openedTime = () {
    final now = DateTime.now();
    return (
      hour: now.hour,
      minute: now.minute - now.minute % widget.minuteInterval,
    );
  }();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime?>(
    valueListenable: widget.draft,
    builder: (context, value, _) => _build(context, value),
  );

  Widget _build(BuildContext context, DateTime? value) {
    final time = value == null
        ? _openedTime
        : (hour: value.hour, minute: value.minute);
    final calendar = CoilCalendar(
      selected: value,
      autofocus: true,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      isDisabled: widget.isDisabled,
      firstDayOfWeek: widget.firstDayOfWeek,
      labels: widget.labels,
      motion: widget.motion,
      onSelected: (day) {
        widget.draft.value = DateTime(
          day.year,
          day.month,
          day.day,
          widget.withTime ? time.hour : 0,
          widget.withTime ? time.minute : 0,
        );
        widget.onDayPicked();
      },
      onSubmitted: (_) => widget.onSubmitted(),
    );
    if (!widget.withTime) return calendar;
    final day = value ?? DateTime.now();
    final gap = CoilTheme.metricsOf(context).gap * 2;
    final columns = CoilTimeColumns(
      value: time,
      minuteInterval: widget.minuteInterval,
      motion: widget.motion,
      onChanged: (time) => widget.draft.value = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      ),
    );
    // A phone in landscape has no room for the columns under the
    // calendar, and room beside it. A short desktop window keeps them
    // under it and scrolls, as a resized window shouldn't reflow the
    // picker.
    final window = MediaQuery.sizeOf(context);
    if (CoilTheme.tierOf(context) == CoilTier.touch &&
        window.width > window.height &&
        window.height < sideBySideHeight) {
      return Row(
        spacing: gap,
        children: [
          Expanded(child: calendar),
          columns,
        ],
      );
    }
    // The time band is as wide as the calendar, which a wide sheet
    // centers.
    return CoilCalendarWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          calendar,
          // On the days' edge, inside the calendar's focus-ring room.
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: CoilCalendar.edgeInsetOf(context),
            ),
            child: columns,
          ),
        ],
      ),
    );
  }
}
