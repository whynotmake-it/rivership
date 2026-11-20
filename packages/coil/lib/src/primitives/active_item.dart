import 'package:coil/src/foundation/input_modality.dart';
import 'package:flutter/foundation.dart';

/// The item of a list that Enter (or the soft keyboard's Search key) acts
/// on: the equivalent of `aria-activedescendant`.
///
/// Separate from focus and hover. Focus can stay in a search field while the
/// arrow keys move the active item; a hovering pointer moves it too; in
/// lists that stay open (search, multi-select), a completed tap moves it.
/// [via] says how it got there, so the list shows a focus ring only for the
/// keyboard. The fluid highlight paints the active item.
class CoilActiveItemController extends ChangeNotifier {
  /// Creates a controller with no active item.
  CoilActiveItemController({this._index, this._via = .pointer});

  /// The active item, or null.
  int? get index => _index;
  int? _index;

  /// How the active item was last set.
  CoilModality get via => _via;
  CoilModality _via;

  /// Whether the active item was reached with the keyboard (show a ring).
  bool get keyboardDriven => _index != null && _via == CoilModality.keyboard;

  /// Makes [index] active, or clears it with null.
  void activate(int? index, {required CoilModality via}) {
    if (index == _index && via == _via) return;
    _index = index;
    _via = via;
    notifyListeners();
  }

  /// Clears the active item.
  void clear() => activate(null, via: _via);

  /// Moves to the next enabled item of [count] in [step] direction (1 or
  /// -1), from the active one or from before the first. Returns the new
  /// index, or null if none moved.
  int? move(
    int step, {
    required int count,
    bool Function(int index)? isEnabled,
    bool wrap = false,
  }) {
    final from = _index ?? (step > 0 ? -1 : count);
    var i = from;
    for (var n = 0; n < count; n++) {
      i += step;
      if (i < 0 || i >= count) {
        if (!wrap) break;
        i = (i + count) % count;
      }
      if (isEnabled?.call(i) ?? true) {
        activate(i, via: CoilModality.keyboard);
        return i;
      }
    }
    // At an end: keep the item, but it was the keyboard that tried.
    if (_index != null) activate(_index, via: CoilModality.keyboard);
    return null;
  }

  /// Moves to the first enabled item of [count].
  int? first({required int count, bool Function(int index)? isEnabled}) {
    _index = null;
    return move(1, count: count, isEnabled: isEnabled);
  }

  /// Moves to the last enabled item of [count].
  int? last({required int count, bool Function(int index)? isEnabled}) {
    _index = null;
    return move(-1, count: count, isEnabled: isEnabled);
  }
}
