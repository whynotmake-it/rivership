import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/input.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/select/option_list.dart';
import 'package:coil/src/components/select/picked_label.dart';
import 'package:coil/src/components/select/select_style.dart';
import 'package:coil/src/components/select/select_trigger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A text field that filters a list of [options] as the user types, to
/// pick one.
///
/// Typing opens the list and narrows it to options whose
/// [CoilOption.searchText] contains the text;
/// the first match is active. The arrows move through the matches and
/// Enter picks one, while focus stays in the field. An Enter that only
/// commits an IME composition picks nothing. Escape closes the list, and
/// leaving the field puts the picked option's search text back. Give every
/// option a [CoilOption.searchText]: the field and the filter need it.
///
/// On a phone the field opens a sheet with its own field and the list, so
/// the keyboard doesn't cover the matches. [presentation] pins one.
class CoilCombobox<T> extends StatelessWidget {
  /// Creates a combobox.
  const CoilCombobox({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
    this.placeholder = const Text('Search…'),
    this.empty = const Text('No results'),
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

  /// Shown, muted, in the empty field. Usually a [Text].
  final Widget placeholder;

  /// Shown in the list when nothing matches. Usually a [Text].
  final Widget empty;

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

  /// Overrides for the list's look.
  final CoilSelectStyle? style;

  /// Opens and closes the list from code.
  final CoilPopupController? controller;

  @override
  Widget build(BuildContext context) => _ComboboxCore<T>(
    options: options,
    picked: {?value},
    multiple: false,
    onChanged: switch (onChanged) {
      final onChanged? => (picked) => onChanged(picked.first),
      null => null,
    },
    removeLabel: '',
    placeholder: placeholder,
    empty: empty,
    sheetTitle: sheetTitle,
    presentation: presentation,
    size: size,
    focusNode: focusNode,
    motion: motion,
    style: style,
    controller: controller,
  );
}

/// A combobox that picks any number of [options]: rows toggle and the list
/// stays open, and the picks show as chips under the field. Backspace in
/// the empty field removes the last chip.
///
/// On a phone it always opens a sheet. Otherwise like [CoilCombobox].
class CoilMultiCombobox<T> extends StatelessWidget {
  /// Creates a multi-select combobox.
  const CoilMultiCombobox({
    required this.options,
    required this.values,
    required this.onChanged,
    super.key,
    this.placeholder = const Text('Search…'),
    this.empty = const Text('No results'),
    this.removeLabel = 'Remove',
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

  /// The picked values.
  final Set<T> values;

  /// Called with the new picks. Null disables the combobox.
  final ValueChanged<Set<T>>? onChanged;

  /// Shown, muted, in the empty field. Usually a [Text].
  final Widget placeholder;

  /// Shown in the list when nothing matches. Usually a [Text].
  final Widget empty;

  /// A chip's remove button label for screen readers, before its label.
  final String removeLabel;

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

  /// Overrides for the list's look.
  final CoilSelectStyle? style;

  /// Opens and closes the list from code.
  final CoilPopupController? controller;

  @override
  Widget build(BuildContext context) => _ComboboxCore<T>(
    options: options,
    picked: values,
    multiple: true,
    onChanged: onChanged,
    removeLabel: removeLabel,
    placeholder: placeholder,
    empty: empty,
    sheetTitle: sheetTitle,
    presentation: presentation,
    size: size,
    focusNode: focusNode,
    motion: motion,
    style: style,
    controller: controller,
  );
}

class _ComboboxCore<T> extends StatefulWidget {
  const _ComboboxCore({
    required this.options,
    required this.picked,
    required this.multiple,
    required this.onChanged,
    required this.removeLabel,
    this.placeholder = const Text('Search…'),
    this.empty = const Text('No results'),
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

  /// The picked values.
  final Set<T> picked;

  /// Whether options toggle and the list stays open.
  final bool multiple;

  /// Called with the new picks. Null disables the combobox.
  final ValueChanged<Set<T>>? onChanged;

  /// A chip's remove button label.
  final String removeLabel;

  /// Shown, muted, in the empty field. Usually a [Text].
  final Widget placeholder;

  /// Shown in the list when nothing matches. Usually a [Text].
  final Widget empty;

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
  State<_ComboboxCore<T>> createState() => _ComboboxCoreState<T>();
}

class _ComboboxCoreState<T> extends State<_ComboboxCore<T>> {
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
    _syncText();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_ComboboxCore<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    // Only the page's own field follows here: the list's listenables, which
    // a sheet route also listens to, change in event handlers only.
    if (!setEquals(oldWidget.picked, widget.picked)) _syncText();
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
      if (option.value == value) return option.searchText ?? '';
    }
    return '';
  }

  List<CoilOption<T>> _matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return [
      for (final option in widget.options)
        if (option.searchText?.toLowerCase().contains(q) ?? false) option,
    ];
  }

  /// Puts the picked option's label in the page's field.
  void _syncText() {
    final label = widget.multiple ? '' : _labelOf(widget.picked.firstOrNull);
    _text.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
  }

  /// Shows the picked label again and stops filtering. From event handlers
  /// only.
  void _showPicked() {
    _syncText();
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
    multiSelect: widget.multiple,
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
    if (!widget.multiple) _popup.close();
  }

  void _pick(T value) {
    if (widget.multiple) {
      final picked = {...widget.picked};
      if (!picked.remove(value)) picked.add(value);
      widget.onChanged?.call(picked);
      // The typed text found it; the next search starts over.
      _text.clear();
      _query.value = '';
      return;
    }
    widget.onChanged?.call({value});
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
    if (widget.multiple)
      const SingleActivator(LogicalKeyboardKey.backspace):
          const _RemoveLastIntent(),
  };

  /// The page's field, or with [inSheet] the sheet's search field, which
  /// starts empty and only filters.
  Widget _field({required bool inSheet, FocusNode? focusNode}) => CoilInput(
    controller: inSheet ? null : _text,
    focusNode: focusNode,
    autofocus: inSheet,
    enabled: _enabled,
    placeholder: widget.placeholder,
    size: widget.size,
    motion: widget.motion,
    autocorrect: false,
    textInputAction: TextInputAction.search,
    onChanged: _onChanged,
    onSubmitted: (_) => _pickActive(),
    shortcuts: _shortcuts,
    trailing: inSheet ? null : const CoilDrawnGlyph(CoilGlyph.chevronDown),
  );

  /// The page's field; with [_ComboboxCore.multiple], the picks as chips
  /// under it, and Backspace in the empty field removes the last.
  Widget _pageField() {
    final field = _field(inSheet: false, focusNode: _focus);
    if (!widget.multiple) return field;
    final picked = [
      for (final option in widget.options)
        if (widget.picked.contains(option.value)) option,
    ];
    void remove(T value) =>
        widget.onChanged?.call({...widget.picked}..remove(value));
    return Actions(
      actions: {
        _RemoveLastIntent: _RemoveLastAction(
          enabled: () => _enabled && _text.text.isEmpty && picked.isNotEmpty,
          onInvoke: () => remove(picked.last.value),
        ),
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CoilTheme.metricsOf(context).gap,
        children: [
          field,
          if (picked.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in picked)
                  _Chip(
                    label: option.label,
                    removeLabel:
                        '${widget.removeLabel} '
                        '${option.semanticLabel ?? option.searchText ?? ''}',
                    onRemove: _enabled ? () => remove(option.value) : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

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
              child: DefaultTextStyle(
                textAlign: TextAlign.center,
                style: theme.typography.style(
                  metrics.body,
                  color: theme.colors.mutedForeground,
                ),
                child: widget.empty,
              ),
            ),
          );
        }
        return CoilOptionList<T>(
          options: matches,
          picked: widget.picked,
          multiple: widget.multiple,
          activeItem: _active,
          metrics: metrics,
          style: style,
          selectedFill: !sheet,
          fullEmphasis: sheet,
          onPick: (value) {
            _pick(value);
            if (!widget.multiple) popup.close(CoilPopupCloseReason.selected);
          },
          onDismiss: popup.close,
        );
      },
    );
  }

  /// The phone's trigger: a select-style button that opens the sheet.
  Widget _trigger(CoilMetrics metrics) {
    final style = _style(context, metrics);
    final picked = [
      for (final option in widget.options)
        if (widget.picked.contains(option.value)) option,
    ];
    final value = pickedSemanticValue(picked);
    return ListenableBuilder(
      listenable: _popup,
      builder: (context, _) => Semantics(
        button: true,
        enabled: _enabled,
        expanded: _popup.isOpen,
        value: value,
        child: CoilInteraction(
          onPressed: _enabled ? _open : null,
          focusNode: _focus,
          statesController: _states,
          excludeFromSemantics: true,
          builder: (context, states, _) => CoilSelectTrigger(
            metrics: metrics,
            style: style,
            states: {...states, if (_popup.isOpen) WidgetState.selected},
            label: ExcludeSemantics(
              excluding: value != null,
              child: pickedLabel(
                picked,
                multiple: widget.multiple,
                placeholder: widget.placeholder,
                placeholderColor: style.placeholder!,
              ),
            ),
          ),
        ),
      ),
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
      // On a phone the field would hide under the keyboard with the list:
      // the page shows a trigger, and the sheet holds the field.
      child: sheet ? _trigger(metrics) : _pageField(),
    );
  }
}

class _RemoveLastIntent extends Intent {
  const _RemoveLastIntent();
}

/// Removes the last pick. Disabled while the field has text, so Backspace
/// then edits it.
class _RemoveLastAction extends Action<_RemoveLastIntent> {
  _RemoveLastAction({required this.enabled, required this.onInvoke});

  final bool Function() enabled;
  final VoidCallback onInvoke;

  @override
  bool isEnabled(_RemoveLastIntent intent) => enabled();

  @override
  void invoke(_RemoveLastIntent intent) => onInvoke();
}

/// A pick of a multi-select combobox, with a button that removes it.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.removeLabel,
    required this.onRemove,
  });

  final Widget label;

  /// The remove button's name for screen readers.
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final onRemove = this.onRemove;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.muted,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(
            theme.shape.radii(metrics.tier).item,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            DefaultTextStyle(
              style: theme.typography.style(
                metrics.caption,
                color: colors.foreground,
              ),
              child: label,
            ),
            Semantics(
              button: true,
              label: removeLabel,
              excludeSemantics: true,
              onTap: onRemove,
              child: CoilInteraction(
                onPressed: onRemove,
                excludeFromSemantics: true,
                minHitTarget: metrics.tier == CoilTier.touch ? 44 : 0,
                builder: (context, states, _) => SizedBox.square(
                  dimension: 20,
                  child: IconTheme(
                    data: IconThemeData(
                      size: 12,
                      color: states.contains(WidgetState.hovered)
                          ? colors.foreground
                          : colors.mutedForeground,
                    ),
                    child: const CoilDrawnGlyph(CoilGlyph.cross),
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
