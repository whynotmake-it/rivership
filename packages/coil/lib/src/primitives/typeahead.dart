import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Type-to-jump for lists and menus.
///
/// Printable keys typed within [timeout] of each other build one query,
/// matched case-insensitively against the start of each enabled label. A
/// query of one repeated letter ("sss") cycles through the items starting
/// with that letter. Space is part of a query once one has started ("New
/// York"); otherwise it is left to the item (to activate it).
///
/// Only hardware key events are read: text typed through an IME goes to a
/// text field, never here.
class CoilTypeahead extends StatefulWidget {
  /// Creates a typeahead.
  const CoilTypeahead({
    required this.labels,
    required this.current,
    required this.onMatch,
    required this.child,
    super.key,
    this.isEnabled,
    this.timeout = const Duration(seconds: 1),
  });

  /// The text of each item, in order.
  final List<String> labels;

  /// The item the search starts after (the active item), or null.
  final int? current;

  /// Whether the item at an index can be matched. Null: all can.
  final bool Function(int index)? isEnabled;

  /// Called with the index of the matched item.
  final ValueChanged<int> onMatch;

  /// How long a pause ends the query.
  final Duration timeout;

  /// The list, which (or a descendant of which) holds focus.
  final Widget child;

  @override
  State<CoilTypeahead> createState() => _CoilTypeaheadState();
}

class _CoilTypeaheadState extends State<CoilTypeahead> {
  String _query = '';
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (character == null || character.isEmpty) return KeyEventResult.ignored;
    final code = character.codeUnitAt(0);
    if (code < 0x20 || code == 0x7F) return KeyEventResult.ignored;
    if (character.trim().isEmpty && _query.isEmpty) {
      return KeyEventResult.ignored;
    }
    _type(character);
    return KeyEventResult.handled;
  }

  void _type(String character) {
    _reset?.cancel();
    _reset = Timer(widget.timeout, () => _query = '');
    _query += character.toLowerCase();
    final repeated = _query.split('').every((c) => c == _query[0]);
    final query = repeated ? _query[0] : _query;
    final count = widget.labels.length;
    if (count == 0) return;
    final start = widget.current ?? -1;
    // A fresh multi-letter query may still match the current item.
    final offset = repeated ? 1 : 0;
    for (var n = 0; n < count; n++) {
      final i = (start + offset + n + count) % count;
      if (!(widget.isEnabled?.call(i) ?? true)) continue;
      if (widget.labels[i].toLowerCase().startsWith(query)) {
        widget.onMatch(i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onKeyEvent: _onKey,
    child: widget.child,
  );
}
