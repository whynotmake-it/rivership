import 'dart:math' as math;

import 'package:coil/button.dart';
import 'package:coil/calendar.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/select/select_style.dart';
import 'package:coil/src/components/select/select_trigger.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A field that opens a [CoilCalendar] to pick a date.
///
/// The calendar opens in a popover next to the field, or on a phone in a
/// floating panel, centered over the page. The field shows the date with
/// [CoilCalendarLabels.date], or [placeholder] when there is none. The arrow
/// keys on the field open the calendar with the keyboard on the picked day.
///
/// - **Popover:** what's picked applies at once. The field's label
///   follows every day and time picked, and closing the popover (a tap
///   outside, Escape, Enter) is done; there is nothing to confirm or
///   cancel, as in iOS's compact picker, macOS's and MUI's desktop
///   pickers. Picking a day closes a date-only popover; with time it stays
///   open for the time.
/// - **Floating panel or sheet:** what's picked is a draft until the
///   pinned **Done** ([CoilCalendarLabels.confirm]) confirms it; every other
///   way out (the close button, the scrim, a swipe away, back, Escape)
///   leaves [value] as it was. The panel hugs the calendar and is swiped
///   away sideways, so the calendar's vertical scroll is its own; a sheet
///   (pinned with [presentation]) takes a whole screen and is dragged down.
///   The footer names what Done will confirm on its leading side
///   ([CoilCalendarLabels.summary]), so the draft stays readable however
///   far the calendar has scrolled or zoomed.
/// - **Keyboard:** Enter is done: it confirms a draft and closes
///   a popover (on the grid, it picks the focused day first); Space only
///   picks; Escape closes.
///
/// With [withTime], two columns under the calendar pick the time of day.
/// In a short, wide window (a phone in landscape) they sit beside the
/// calendar instead, with the footer under them: the panel's calendar then
/// takes its size from the window's height, so the whole picker fits
/// without scrolling.
///
/// The popover is as wide as the calendar's seven cells. A panel's or
/// sheet's calendar fills it up to days 30 % bigger than their natural
/// size, and centers in a wider one: days are always square. The popover
/// and a portrait panel or sheet scroll when the window is too short for
/// them.
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

  /// Called with each date a popover applies, or the one the Done of a panel or
  /// sheet confirms.
  ///
  /// Null disables the picker.
  final ValueChanged<DateTime>? onChanged;

  /// Shown, muted, in the field when no date is picked.
  ///
  /// Usually a [Text].
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

  /// Whether a time of day is picked too, in two columns under the calendar.
  ///
  /// The popover then stays open after a day is picked, for the time; every
  /// pick still applies at once, and closing it is done. Only the panel and the
  /// sheet have a Done button.
  final bool withTime;

  /// The minute step of the time columns.
  final int minuteInterval;

  /// Month and weekday names, how the field shows a date, and the label
  /// of the Done button.
  final CoilCalendarLabels labels;

  /// A heading for the floating panel and sheet presentations.
  final Widget? sheetTitle;

  /// Pins the presentation.
  ///
  /// Null decides per open.
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

  /// What the open calendar has picked.
  ///
  /// Each open starts it from [CoilDatePicker.value]. A popover reports it as
  /// it changes; a panel or sheet holds it until Done, its footer following it.
  final _draft = ValueNotifier<DateTime?>(null);

  /// Whether the open calendar is a popover, which applies picks at once.
  bool _live = false;

  /// The value last reported through [CoilDatePicker.onChanged] during
  /// this open (or the value it opened with), so each pick reports once
  /// even before the parent rebuilds with it.
  DateTime? _reported;

  void _report(DateTime value) {
    if (value == _reported) return;
    _reported = value;
    widget.onChanged?.call(value);
  }

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
    _draft.addListener(_onDraft);
  }

  /// A popover applies each pick as it's made.
  void _onDraft() {
    final draft = _draft.value;
    if (!_live || !_popup.isOpen || draft == null) return;
    _report(draft);
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
    if (open && !_wasOpen) {
      _reported = widget.value;
      _draft.value = widget.value;
    }
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
    _report(draft);
    popup.close(CoilPopupCloseReason.selected);
  }

  CoilSelectStyle _style(BuildContext context, CoilMetrics metrics) =>
      CoilSelectStyle.fallback(
        CoilTheme.of(context),
        metrics,
      ).merge(CoilTheme.styleOf<CoilSelectStyle>(context)).merge(widget.style);

  /// The footer: what Done will confirm on the leading side, and Done,
  /// which confirms once something is picked, on the trailing side.
  Widget _footer(
    CoilPopupHandle popup, {
    bool stackable = false,
    bool oneLine = false,
  }) => ValueListenableBuilder<DateTime?>(
    valueListenable: _draft,
    builder: (context, draft, _) => _DraftFooter(
      stackable: stackable,
      oneLine: oneLine,
      summary: draft == null
          ? null
          : Semantics(
              label: widget.labels.summaryLabel(
                draft,
                withTime: widget.withTime,
                use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
              ),
              excludeSemantics: true,
              child: widget.labels.summary(
                draft,
                withTime: widget.withTime,
                use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
              ),
            ),
      action: CoilButton(
        onPressed: draft == null ? null : () => _confirm(popup),
        child: widget.labels.confirm,
      ),
    ),
  );

  Widget _content(BuildContext context, CoilPopupHandle popup) {
    final sheet = popup.presentation.usesSheetPanel;
    _live = !sheet;
    // Only a popover picking a date alone has a tap that is the whole
    // answer.
    final confirmOnPick = !sheet && !widget.withTime;
    final metrics = CoilTheme.metricsOf(context);
    final landscape = sheet && _DateTimePanelState.isLandscapePhone(context);
    final panel = _DateTimePanel(
      landscape: landscape,
      typed: !sheet,
      // A phone in landscape has no room under the calendar for the footer
      // either: it joins the time in the column beside the calendar.
      footer: landscape
          ? _footer(popup, stackable: true, oneLine: !widget.withTime)
          : null,
      closeInCorner: landscape,
      title: landscape ? widget.sheetTitle : null,
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
    // Scrolls when the window is too short for it (a desktop window, large
    // text on a portrait phone). The popover hugs the calendar's width; a
    // sheet's width is the calendar's to fill. A panel on a phone in
    // landscape sizes the calendar to the height instead, and scrolls only
    // as the last resort (_LandscapeBody).
    final scroll = landscape
        ? panel
        // No platform scrollbar: on desktop it would show beside the days
        // whenever anything inside scrolls, though the picker rarely does.
        : ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              // A popover's scroll view isn't the page's primary one; a
              // sheet's is the sheet's, so a drag hands off to dismissing it.
              primary: sheet ? null : false,
              child: Padding(
                padding: sheet
                    ? EdgeInsets.symmetric(
                        horizontal: side - edge,
                        vertical: metrics.popupInset * 2,
                      )
                    : EdgeInsets.all(metrics.popupInset * 2),
                child: panel,
              ),
            ),
          );
    // Enter anywhere in the popup confirms; the grid picks its focused day
    // first, and a focused button presses itself. Escape closes: a sheet
    // without its draft, a popover with what it already applied (the month
    // view takes Escape first, to go back to the days).
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
    // A phone in landscape lays the footer out itself, beside the calendar,
    // with the close button and the title on one line in the column's top
    // corner: a header line would cost the calendar its height.
    if (landscape) return content;
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
        : widget.labels.dateLabel(
            value,
            withTime: widget.withTime,
            use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
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
      // A phone's picker floats in the middle of the page, hugging the
      // calendar.
      floatingAnchor: CoilModalAnchor.center,
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
                        : widget.labels.date(
                            value,
                            withTime: widget.withTime,
                            use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                              context,
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

/// A date picker's footer: the [summary] of what [action] confirms on the
/// leading side, nothing before anything is picked, and [action] on the
/// trailing side at its own width (DESIGN.md §13.5).
///
/// [action] never gives up width: the summary takes what's left, wraps
/// onto a second line and then ends in an ellipsis, so large text on a
/// narrow phone squeezes the date, never the button. The summary isn't a
/// button; tapping it does nothing.
///
/// With [stackable] (the column beside a landscape calendar, which can be
/// too narrow for both), a summary that wouldn't fit two lines beside the
/// button sits above it instead, on the leading side, with [action] under
/// it on the trailing side.
class _DraftFooter extends StatelessWidget {
  const _DraftFooter({
    required this.summary,
    required this.action,
    this.stackable = false,
    this.oneLine = false,
  });

  /// What [action] will confirm, or null when nothing is picked.
  final Widget? summary;

  /// The confirming button.
  final Widget action;

  /// Whether a summary that doesn't fit beside [action] goes above it.
  final bool stackable;

  /// With [stackable], whether a summary that would take two lines beside
  /// [action] but fits one above it goes above it: for a column with height
  /// to spare.
  final bool oneLine;

  /// The summary's lines before it ends in an ellipsis.
  static const maxLines = 2;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final metrics = CoilTheme.metricsOf(context);
    Widget summaryWith(int lines) => DefaultTextStyle(
      style: text.body.tabular,
      maxLines: lines,
      overflow: TextOverflow.ellipsis,
      child: this.summary ?? const SizedBox.shrink(),
    );
    final summary = summaryWith(maxLines);
    final action = CoilActionBar(
      layout: CoilActionBarLayout.row,
      actions: [this.action],
    );
    if (stackable) {
      return _FooterLayout(
        sideGap: metrics.gap,
        oneLine: oneLine,
        stackGap: CoilTheme.of(
          context,
        ).metrics.resolve(CoilTier.touch, CoilSize.compact).gap,
        children: {
          _FooterSlot.summary: summary,
          // A line more than the summary has, to know if it needs it.
          _FooterSlot.probe: ExcludeSemantics(
            child: summaryWith(maxLines + 1),
          ),
          _FooterSlot.action: action,
        },
      );
    }
    return Row(
      spacing: metrics.gap * 2,
      children: [
        Expanded(child: summary),
        action,
      ],
    );
  }
}

enum _FooterSlot { summary, probe, action }

/// Lays out a [_DraftFooter]'s summary and action: side by side while the
/// summary fits [_DraftFooter.maxLines] lines in what the action leaves,
/// the summary above the action when it doesn't.
class _FooterLayout
    extends SlottedMultiChildRenderObjectWidget<_FooterSlot, RenderBox> {
  const _FooterLayout({
    required this.oneLine,
    required this.sideGap,
    required this.stackGap,
    required this.children,
  });

  final bool oneLine;
  final double sideGap;
  final double stackGap;
  final Map<_FooterSlot, Widget> children;

  @override
  Iterable<_FooterSlot> get slots => _FooterSlot.values;

  @override
  Widget? childForSlot(_FooterSlot slot) => children[slot];

  @override
  _RenderFooterLayout createRenderObject(BuildContext context) =>
      _RenderFooterLayout(
        oneLine: oneLine,
        sideGap: sideGap,
        stackGap: stackGap,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFooterLayout renderObject,
  ) => renderObject
    ..oneLine = oneLine
    ..sideGap = sideGap
    ..stackGap = stackGap;
}

class _RenderFooterLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<_FooterSlot, RenderBox> {
  _RenderFooterLayout({
    required this._oneLine,
    required this._sideGap,
    required this._stackGap,
  });

  bool _oneLine;
  bool get oneLine => _oneLine;
  set oneLine(bool value) {
    if (value == _oneLine) return;
    _oneLine = value;
    markNeedsLayout();
  }

  double _sideGap;
  double get sideGap => _sideGap;
  set sideGap(double value) {
    if (value == _sideGap) return;
    _sideGap = value;
    markNeedsLayout();
  }

  double _stackGap;
  double get stackGap => _stackGap;
  set stackGap(double value) {
    if (value == _stackGap) return;
    _stackGap = value;
    markNeedsLayout();
  }

  RenderBox get _summary => childForSlot(_FooterSlot.summary)!;
  RenderBox get _probe => childForSlot(_FooterSlot.probe)!;
  RenderBox get _action => childForSlot(_FooterSlot.action)!;

  /// The width the summary gets next to the action, or null when it goes
  /// above: when it would need more than [_DraftFooter.maxLines] lines in
  /// the room the action leaves (the probe, which has a line more, is
  /// taller than the summary then).
  double? _sideWidth(double width, double action) {
    final natural = _summary.getMaxIntrinsicWidth(double.infinity);
    if (natural == 0) return width;
    final room = width - action - _sideGap;
    if (natural <= room) return room;
    if (oneLine && natural <= width) return null;
    if (room <= 0) return null;
    final fits =
        _probe.getMaxIntrinsicHeight(room) <=
        _summary.getMaxIntrinsicHeight(room);
    return fits ? room : null;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final result = _layout(constraints, ChildLayoutHelper.layoutChild);
    size = result.size;
    (_summary.parentData! as BoxParentData).offset = result.summary;
    (_action.parentData! as BoxParentData).offset = result.action;
  }

  ({Size size, Offset summary, Offset action}) _layout(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild,
  ) {
    final width = constraints.maxWidth;
    layoutChild(_probe, const BoxConstraints.tightFor(width: 0, height: 0));
    final action = layoutChild(_action, BoxConstraints(maxWidth: width));
    final side = _sideWidth(width, action.width);
    if (side != null) {
      final summary = layoutChild(
        _summary,
        BoxConstraints(maxWidth: math.max(0, side)),
      );
      final height = math.max(summary.height, action.height);
      return (
        size: constraints.constrain(Size(width, height)),
        summary: Offset(0, (height - summary.height) / 2),
        action: Offset(width - action.width, (height - action.height) / 2),
      );
    }
    final summary = layoutChild(_summary, BoxConstraints(maxWidth: width));
    return (
      size: constraints.constrain(
        Size(width, summary.height + _stackGap + action.height),
      ),
      summary: Offset.zero,
      action: Offset(width - action.width, summary.height + _stackGap),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  double _intrinsicHeight(double width) {
    final action = _action.getMaxIntrinsicWidth(double.infinity);
    final actionHeight = _action.getMaxIntrinsicHeight(action);
    final side = _sideWidth(width, action);
    if (side != null) {
      return math.max(_summary.getMaxIntrinsicHeight(side), actionHeight);
    }
    return _summary.getMaxIntrinsicHeight(width) + _stackGap + actionHeight;
  }

  /// What the footer needs: the action and half the summary (two lines),
  /// or the whole summary (one) where [oneLine].
  @override
  double computeMinIntrinsicWidth(double height) {
    final action = _action.getMaxIntrinsicWidth(height);
    final summary = _summary.getMaxIntrinsicWidth(height);
    return math.max(
      action + (summary == 0 ? 0 : _sideGap + summary / 2),
      oneLine ? summary : 0,
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _summary.getMaxIntrinsicWidth(height) +
      _sideGap +
      _action.getMaxIntrinsicWidth(height);

  @override
  void paint(PaintingContext context, Offset offset) {
    // The probe is never seen.
    for (final child in [_summary, _action]) {
      context.paintChild(
        child,
        (child.parentData! as BoxParentData).offset + offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [_action, _summary]) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
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

/// Closes the popup without confirming anything further: Escape.
class _CancelIntent extends Intent {
  const _CancelIntent();
}

/// The popup's content: the calendar and, with [withTime], the time
/// columns, editing [draft].
class _DateTimePanel extends StatefulWidget {
  const _DateTimePanel({
    required this.landscape,
    required this.typed,
    required this.footer,
    required this.closeInCorner,
    required this.title,
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

  /// Whether this is a panel on a phone in landscape: the calendar sizes
  /// to the height, with the time and [footer] in a column beside it, and
  /// nothing scrolls.
  final bool landscape;

  /// Whether the time is typed into a [CoilTimeField] (a popover, where a
  /// keyboard and a pointer are at hand) rather than turned in the snap
  /// columns (a sheet or floating panel, for the thumb).
  final bool typed;

  /// The footer of a landscape panel, in the column beside the calendar.
  final Widget? footer;

  /// Whether a landscape panel puts the close button in the corner of its
  /// column (it has no header line).
  final bool closeInCorner;

  /// The panel's heading, on the close button's line in a landscape panel.
  final Widget? title;

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

  /// Whether the window is a phone in landscape: the touch tier, wider than
  /// tall and shorter than [sideBySideHeight].
  static bool isLandscapePhone(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    return CoilTheme.tierOf(context) == CoilTier.touch &&
        window.width > window.height &&
        window.height < sideBySideHeight;
  }

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

  Widget _timeColumns(DateTime? value, ({int hour, int minute}) time) {
    final day = value ?? DateTime.now();
    return CoilTimeColumns(
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
  }

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
    if (widget.landscape) {
      return _LandscapeBody(
        calendar: calendar,
        time: widget.withTime ? _timeColumns(value, time) : null,
        footer: widget.footer!,
        closeInCorner: widget.closeInCorner,
        title: widget.title,
      );
    }
    if (!widget.withTime) return calendar;
    final gap = CoilTheme.metricsOf(context).gap * 2;
    if (widget.typed) {
      final day = value ?? DateTime.now();
      // Under the calendar, on the days' edges: the label leading, the
      // field trailing, as a date and time popover lays them out on macOS.
      return CoilCalendarWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            calendar,
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: CoilCalendar.edgeInsetOf(context),
              ),
              child: Row(
                spacing: CoilTheme.metricsOf(context).gap,
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: DefaultTextStyle(
                        style: CoilTheme.textOf(context).muted.body,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        child: widget.labels.time,
                      ),
                    ),
                  ),
                  CoilTimeField(
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
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final columns = _timeColumns(value, time);
    // A phone in landscape has no room for the columns under the
    // calendar, and room beside it. A short desktop window keeps them
    // under it and scrolls, as a resized window shouldn't reflow the
    // picker.
    if (isLandscapePhone(context)) {
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

/// A phone in landscape: the calendar on the leading side, sized from the
/// height so its six rows, caption and weekday row fill it exactly, and a
/// column beside it with the [time] centered in what the footer leaves and
/// the [footer] at the bottom.
///
/// Nothing scrolls while it fits, which it does on every phone at ordinary
/// text sizes; text so large that the column outgrows the height scrolls
/// the whole body rather than clip it.
///
/// The days start where a sheet's text starts (the calendar's focus-ring
/// room inside it) and the footer ends there on the other side. The close
/// button, in the corner of the column if [closeInCorner], is concentric
/// with the panel's corner, and the calendar's caption row is centered on
/// the same line.
class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({
    required this.calendar,
    required this.time,
    required this.footer,
    required this.closeInCorner,
    required this.title,
  });

  final Widget calendar;
  final Widget? time;
  final Widget footer;
  final bool closeInCorner;
  final Widget? title;

  /// [title] as a sheet's header shows it: the touch title, one line.
  Widget _titleText(BuildContext context, Widget title) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(
      context,
      tier: CoilTier.touch,
      size: CoilSize.regular,
    );
    return Semantics(
      header: true,
      child: DefaultTextStyle(
        style: theme.typography
            .resolve(metrics.tier, metrics.size)
            .title
            .copyWith(color: theme.colors.foreground),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        child: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final touch = CoilTheme.of(
      context,
    ).metrics.resolve(CoilTier.touch, CoilSize.regular);
    final side = touch.popupInset + touch.itemPaddingX;
    final edge = CoilCalendar.edgeInsetOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // The caption row's middle runs through the close button's, which is
    // centered on the panel's corner.
    final top = closeInCorner
        ? CoilSheetCloseSlot.edgeOf(context)
        : touch.popupInset * 2;
    final bottom = math.max<double>(
      8,
      CoilSheetPanel.footerBottomGap - safeBottom,
    );
    // How far the close button reaches into the column from its end: its
    // slot, less what the column's inset already keeps, and a gap.
    final cornerWidth =
        CoilSheetCloseSlot.extentOf(context) +
        CoilSheetCloseSlot.edgeOf(context) -
        side +
        touch.gap;
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight - top - bottom;
          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: time == null
                    ? const SizedBox.shrink()
                    : _TimeSlot(
                        // Clear of the close button where they'd meet.
                        cornerWidth: cornerWidth,
                        // A title spans the corner's line, so the time goes
                        // below it as far as there's room.
                        pushDown: true,
                        cornerHeight: CoilSheetCloseSlot.extentOf(context),
                        child: time,
                      ),
              ),
              footer,
            ],
          );
          final heading = title;
          final trailing = heading == null
              ? column
              : Stack(
                  children: [
                    column,
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: cornerWidth,
                      height: CoilSheetCloseSlot.extentOf(context),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _titleText(context, heading),
                      ),
                    ),
                  ],
                );
          return Stack(
            children: [
              SingleChildScrollView(
                primary: false,
                padding: EdgeInsets.fromLTRB(side - edge, top, side, bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: height),
                  child: IntrinsicHeight(
                    child: _LandscapeRow(
                      gap: side - edge,
                      calendar: CoilCalendarHeight(
                        height: height,
                        child: calendar,
                      ),
                      trailing: trailing,
                    ),
                  ),
                ),
              ),
              if (closeInCorner)
                PositionedDirectional(
                  top: CoilSheetCloseSlot.edgeOf(context),
                  end: 0,
                  child: const CoilSheetCloseSlot(),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Puts the time in the middle of the room the column leaves it, and keeps
/// it off the close button in the column's top corner: where the time would
/// reach up into the corner's [cornerHeight], it also stays [cornerWidth]
/// short of the column's end, off-center if that's what it takes, and
/// narrower still (the columns shrink to fit) if it has to be.
class _TimeSlot extends SingleChildRenderObjectWidget {
  const _TimeSlot({
    required this.cornerWidth,
    required this.cornerHeight,
    required this.pushDown,
    super.child,
  });

  final double cornerWidth;
  final double cornerHeight;

  /// Whether the time goes down out of the corner instead of beside it.
  final bool pushDown;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTimeSlot(
    cornerWidth: cornerWidth,
    cornerHeight: cornerHeight,
    pushDown: pushDown,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTimeSlot renderObject,
  ) => renderObject
    ..cornerWidth = cornerWidth
    ..cornerHeight = cornerHeight
    ..pushDown = pushDown;
}

class _RenderTimeSlot extends RenderShiftedBox {
  _RenderTimeSlot({
    required this._cornerWidth,
    required this._cornerHeight,
    required this._pushDown,
  }) : super(null);

  bool _pushDown;
  bool get pushDown => _pushDown;
  set pushDown(bool value) {
    if (value == _pushDown) return;
    _pushDown = value;
    markNeedsLayout();
  }

  double _cornerWidth;
  double get cornerWidth => _cornerWidth;
  set cornerWidth(double value) {
    if (value == _cornerWidth) return;
    _cornerWidth = value;
    markNeedsLayout();
  }

  double _cornerHeight;
  double get cornerHeight => _cornerHeight;
  set cornerHeight(double value) {
    if (value == _cornerHeight) return;
    _cornerHeight = value;
    markNeedsLayout();
  }

  /// The room [height] leaves above the time's top when it's centered.
  double _top(double height, double child) =>
      math.max<double>(0, (height - child) / 2);

  /// The child's constraints in [constraints], and where it goes.
  ({BoxConstraints child, Size size, Offset Function(Size child) offset}) _plan(
    BoxConstraints constraints,
    Size Function(BoxConstraints) measure,
  ) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    // Measured at the full width first: only a time that reaches the
    // corner has to give way to it.
    final natural = measure(BoxConstraints(maxWidth: width));
    final top = pushDown
        ? math.max<double>(
            _top(height, natural.height),
            math.min(cornerHeight, height - natural.height),
          )
        : _top(height, natural.height);
    // Pushed down as far as it goes, it may still reach the corner.
    final reaches = top < cornerHeight - 0.5 && cornerWidth > 0;
    final room = reaches ? math.max<double>(0, width - cornerWidth) : width;
    return (
      child: BoxConstraints(maxWidth: room),
      size: constraints.constrain(Size(width, height)),
      offset: (child) => Offset(
        math.max<double>(
          0,
          math.min((width - child.width) / 2, room - child.width),
        ),
        pushDown
            ? math.max<double>(
                _top(height, child.height),
                math.min(cornerHeight, height - child.height),
              )
            : _top(height, child.height),
      ),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _plan(constraints, (c) => child?.getDryLayout(c) ?? Size.zero).size;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final plan = _plan(constraints, (c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    child.layout(plan.child, parentUsesSize: true);
    size = plan.size;
    (child.parentData! as BoxParentData).offset = plan.offset(child.size);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width) ?? 0;
}

enum _RowSlot { calendar, trailing }

/// The calendar and, beside it, the trailing column: the column gets what
/// it needs (its minimum intrinsic width) and the calendar everything else,
/// so its columns can be wider than its rows are tall; the column then
/// takes what the calendar leaves.
class _LandscapeRow
    extends SlottedMultiChildRenderObjectWidget<_RowSlot, RenderBox> {
  const _LandscapeRow({
    required this.gap,
    required this.calendar,
    required this.trailing,
  });

  final double gap;
  final Widget calendar;
  final Widget trailing;

  @override
  Iterable<_RowSlot> get slots => _RowSlot.values;

  @override
  Widget? childForSlot(_RowSlot slot) => switch (slot) {
    _RowSlot.calendar => calendar,
    _RowSlot.trailing => trailing,
  };

  @override
  _RenderLandscapeRow createRenderObject(BuildContext context) =>
      _RenderLandscapeRow(gap: gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLandscapeRow renderObject,
  ) => renderObject.gap = gap;
}

class _RenderLandscapeRow extends RenderBox
    with SlottedContainerRenderObjectMixin<_RowSlot, RenderBox> {
  _RenderLandscapeRow({required this._gap});

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  RenderBox get _calendar => childForSlot(_RowSlot.calendar)!;
  RenderBox get _trailing => childForSlot(_RowSlot.trailing)!;

  /// The width the calendar may take: all but the column's minimum.
  double _calendarRoom(double width) {
    final need = _trailing.getMinIntrinsicWidth(double.infinity);
    // The days are never narrower than square, whatever the column needs.
    final square = _calendar.getMinIntrinsicWidth(double.infinity);
    return math.min(
      math.max<double>(width - gap - need, square),
      math.max<double>(0, width - gap),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final result = _layout(constraints, ChildLayoutHelper.layoutChild);
    size = result.size;
    (_trailing.parentData! as BoxParentData).offset = result.trailing;
  }

  ({Size size, Offset trailing}) _layout(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild,
  ) {
    final width = constraints.maxWidth;
    final calendar = layoutChild(
      _calendar,
      BoxConstraints(maxWidth: _calendarRoom(width)),
    );
    final trailingWidth = math.max<double>(0, width - gap - calendar.width);
    final height = constraints.hasTightHeight
        ? constraints.maxHeight
        : constraints.constrainHeight(
            math.max(
              calendar.height,
              _trailing.getMaxIntrinsicHeight(trailingWidth),
            ),
          );
    layoutChild(
      _trailing,
      BoxConstraints.tight(Size(trailingWidth, height)),
    );
    return (
      size: constraints.constrain(Size(width, height)),
      trailing: Offset(calendar.width + gap, 0),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _calendar.getMinIntrinsicWidth(height) +
      gap +
      _trailing.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _calendar.getMaxIntrinsicWidth(height) +
      gap +
      _trailing.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  double _intrinsicHeight(double width) {
    final calendar = _calendar.getMaxIntrinsicWidth(double.infinity);
    final calendarWidth = math.min(calendar, _calendarRoom(width));
    return math.max(
      _calendar.getMaxIntrinsicHeight(calendarWidth),
      _trailing.getMaxIntrinsicHeight(
        math.max<double>(0, width - gap - calendarWidth),
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in [_calendar, _trailing]) {
      context.paintChild(
        child,
        (child.parentData! as BoxParentData).offset + offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [_trailing, _calendar]) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
