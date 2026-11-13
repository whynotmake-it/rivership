import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/input.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/select/option_list.dart';
import 'package:coil/src/components/select/select_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A text field that filters a list of [options] as the user types, to
/// pick one.
///
/// Typing opens the list and narrows it to labels that contain the text;
/// the first match is active. The arrows move through the matches and
/// Enter picks one, while focus stays in the field. An Enter that only
/// commits an IME composition picks nothing. Escape closes the list, and
/// leaving the field puts the picked option's label back.
///
/// On a phone the field opens a sheet with its own field and the list, so
/// the keyboard doesn't cover the matches. [presentation] pins one.
class CoilCombobox<T> extends StatefulWidget {
  /// Creates a combobox.
  const CoilCombobox({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
    this.placeholder = 'Search…',
    this.emptyLabel = 'No results',
    this.sheetTitle,
    this.presentation,
    this.size,
    this.focusNode,
    this.motion,
    this.style,
    this.controller,
  });

  /// The choices.
  final List<CoilOption<T>> options;

  /// The picked value, or null for none.
  final T? value;

  /// Called with the picked value. Null disables the combobox.
  final ValueChanged<T>? onChanged;

  /// Shown in the empty field.
  final String placeholder;

  /// Shown in the list when nothing matches.
  final String emptyLabel;

  /// A heading for the sheet presentation.
  final Widget? sheetTitle;

  /// Pins the presentation. Null decides per open.
  final CoilPresentation? presentation;

  /// Pins the field's size step.
  final CoilSize? size;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// Motion tokens for the field and the list.
  final CoilMotion? motion;

  /// Overrides for the list's look, on top of the theme's
  /// [CoilSelectStyle].
  final CoilSelectStyle? style;

  /// Opens and closes the list from code.
  final CoilPopupController? controller;

  @override
  State<CoilCombobox<T>> createState() => _CoilComboboxState<T>();
}

class _CoilComboboxState<T> extends State<CoilCombobox<T>> {
  final _text = TextEditingController();

  /// What the user typed since the field last showed the picked label; the
  /// list filters by it, so a reopened list shows every option.
  final _query = ValueNotifier('');
  final _active = CoilActiveItemController();
  final _states = WidgetStatesController();
  CoilPopupController? _ownPopup;
  FocusNode? _ownFocus;

  CoilPopupController get _popup =>
      widget.controller ?? (_ownPopup ??= CoilPopupController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _showPicked();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(CoilCombobox<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (oldWidget.value != widget.value) _showPicked();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    _ownPopup?.dispose();
    _text.dispose();
    _query.dispose();
    _active.dispose();
    _states.dispose();
    super.dispose();
  }

  String _labelOf(T? value) {
    for (final option in widget.options) {
      if (option.value == value) return option.label;
    }
    return '';
  }

  List<CoilOption<T>> _matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return [
      for (final option in widget.options)
        if (option.label.toLowerCase().contains(q)) option,
    ];
  }

  /// Puts the picked option's label in the field and stops filtering.
  void _showPicked() {
    final label = _labelOf(widget.value);
    if (_text.text != label) {
      _text.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
    }
    _query.value = '';
  }

  /// Leaving the field closes an anchored list and drops unpicked text.
  void _onFocus() {
    if (_focus.hasFocus) return;
    if (CoilAdaptivePopup.presentationOf(
          context,
          traits: _traits(),
          override: widget.presentation,
        ) ==
        CoilPresentation.popover) {
      _popup.close();
    }
    _showPicked();
  }

  CoilOverlayTraits _traits() => CoilOverlayTraits(
    kind: CoilOverlayKind.combobox,
    itemCount: widget.options.length,
  );

  void _open() {
    if (!_enabled || _popup.isOpen) return;
    unawaited(
      _popup.open().then((_) {
        if (mounted && !_focus.hasFocus) _showPicked();
      }),
    );
  }

  void _onChanged(String text) {
    _query.value = text;
    _open();
    _activateFirst();
  }

  void _activateFirst() {
    final matches = _matches(_query.value);
    if (_query.value.trim().isEmpty) {
      _active.clear();
    } else {
      _active.first(
        count: matches.length,
        isEnabled: (i) => matches[i].enabled,
      );
    }
  }

  void _move(int step) {
    if (!_popup.isOpen) {
      _open();
      return;
    }
    final matches = _matches(_query.value);
    _active.move(
      step,
      count: matches.length,
      isEnabled: (i) => matches[i].enabled,
    );
  }

  void _pickActive() {
    final i = _active.index;
    final matches = _matches(_query.value);
    if (!_popup.isOpen || i == null || i >= matches.length) return;
    _pick(matches[i].value);
    _popup.close();
  }

  void _pick(T value) {
    widget.onChanged?.call(value);
    _active.clear();
    // The owner may not rebuild with the new value until later.
    final label = _labelOf(value);
    _text.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
    _query.value = '';
  }

  void _escape() {
    if (_popup.isOpen) {
      _popup.close();
    } else {
      _showPicked();
    }
  }

  CoilSelectStyle _style(BuildContext context, CoilMetrics metrics) =>
      CoilSelectStyle.fallback(
        CoilTheme.of(context),
        metrics,
      ).merge(CoilTheme.styleOf<CoilSelectStyle>(context)).merge(widget.style);

  Map<ShortcutActivator, Intent> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.arrowDown): VoidCallbackIntent(
      () => _move(1),
    ),
    const SingleActivator(LogicalKeyboardKey.arrowUp): VoidCallbackIntent(
      () => _move(-1),
    ),
    const SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
        VoidCallbackIntent(_pickActive),
    const SingleActivator(
      LogicalKeyboardKey.numpadEnter,
      includeRepeats: false,
    ): VoidCallbackIntent(
      _pickActive,
    ),
    const SingleActivator(LogicalKeyboardKey.escape): VoidCallbackIntent(
      _escape,
    ),
  };

  /// The page's field, or with [inSheet] the sheet's search field, which
  /// starts empty and only filters.
  Widget _field({required bool inSheet, FocusNode? focusNode}) => CoilInput(
    controller: inSheet ? null : _text,
    focusNode: focusNode,
    autofocus: inSheet,
    enabled: _enabled,
    placeholder: Text(widget.placeholder),
    size: widget.size,
    motion: widget.motion,
    autocorrect: false,
    textInputAction: TextInputAction.search,
    onChanged: _onChanged,
    onSubmitted: (_) => _pickActive(),
    shortcuts: _shortcuts,
    trailing: inSheet ? null : const CoilDrawnGlyph(CoilGlyph.chevronDown),
  );

  Widget _list(BuildContext context, CoilPopupHandle popup) {
    final sheet = popup.presentation == CoilPresentation.sheet;
    final theme = CoilTheme.of(context);
    final metrics = sheet
        ? theme.metrics.resolve(CoilTier.touch, CoilSize.regular)
        : CoilTheme.metricsOf(context);
    final style = _style(context, metrics);
    return ValueListenableBuilder(
      valueListenable: _query,
      builder: (context, query, _) {
        final matches = _matches(query);
        if (matches.isEmpty) {
          return Semantics(
            liveRegion: true,
            child: Padding(
              padding: EdgeInsets.all(
                metrics.popupInset + metrics.itemPaddingX,
              ),
              child: Text(
                widget.emptyLabel,
                textAlign: TextAlign.center,
                style: theme.typography.style(
                  metrics.body,
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          );
        }
        return CoilOptionList<T>(
          options: matches,
          picked: {?widget.value},
          activeItem: _active,
          metrics: metrics,
          style: style,
          selectedFill: !sheet,
          fullEmphasis: sheet,
          onPick: (value) {
            _pick(value);
            popup.close(CoilPopupCloseReason.selected);
          },
          onDismiss: popup.close,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheet =
        CoilAdaptivePopup.presentationOf(
          context,
          traits: _traits(),
          override: widget.presentation,
        ) ==
        CoilPresentation.sheet;
    final metrics = CoilTheme.metricsOf(context);
    return CoilAdaptivePopup(
      controller: _popup,
      traits: _traits,
      presentation: widget.presentation,
      takeFocus: false,
      motion: widget.motion,
      maxHeight: metrics.tier == CoilTier.pointer ? 300 : double.infinity,
      content: (context, popup) => popup.presentation == CoilPresentation.sheet
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _field(inSheet: true),
                ),
                Flexible(child: _list(context, popup)),
              ],
            )
          : _list(context, popup),
      popover: (context, content) {
        final metrics = CoilTheme.metricsOf(context);
        final style = _style(context, metrics);
        return CoilPopoverSurface(
          color: style.surface,
          radius: style.radius! + metrics.popupInset,
          child: content,
        );
      },
      sheet: (context, content) =>
          CoilSheetPanel(title: widget.sheetTitle, child: content),
      // On a phone the page's field only opens the sheet.
      // One tree for both, so the field keeps its state when the window
      // crosses the phone width.
      child: Semantics(
        button: sheet,
        child: CoilInteractionDetector(
          states: _states,
          enabled: _enabled && sheet,
          onTap: sheet ? _open : null,
          child: IgnorePointer(
            ignoring: sheet,
            child: _field(inSheet: false, focusNode: _focus),
          ),
        ),
      ),
    );
  }
}
