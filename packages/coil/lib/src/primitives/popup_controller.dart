import 'dart:async';

import 'package:coil/src/foundation/adaptive.dart';
import 'package:flutter/foundation.dart';

/// Why a popup closed. A [CoilPopupController.open] future resolves with
/// one of these, exactly once.
enum CoilPopupCloseReason {
  /// A pick closed it (a single-choice list, a menu action).
  selected,

  /// Something else dismissed it: a drag down on a sheet, the system back
  /// gesture, Tab out of the list.
  dismissed,

  /// The Escape key.
  escape,

  /// A tap outside it, recognized on tap-up.
  outsideTap,

  /// [CoilPopupController.close] or the owner closing it in code.
  programmatic,
}

/// Opens and closes a popup (a select's list, later a menu or combobox)
/// from code, shaped like Flutter's `MenuController`.
///
/// Hand it to a component's `controller:`. [open] returns a future that
/// resolves once, when the popup closes, with the [CoilPopupCloseReason];
/// while the popup is open, [open] returns that same future. [isOpen] is
/// listenable, so UI can follow it.
class CoilPopupController extends ChangeNotifier {
  _CoilPopupHost? _host;
  Future<CoilPopupCloseReason>? _closed;

  /// Whether the popup is open. It turns false as soon as the popup starts
  /// to close, before its exit animation ends.
  bool get isOpen => _closed != null;

  /// Opens the popup, or returns the pending future if it is open. The
  /// future resolves once, when it closes.
  Future<CoilPopupCloseReason> open() {
    if (_closed case final closed?) return closed;
    final host = _host;
    assert(host != null, 'CoilPopupController is not attached to a popup');
    final opened = host?.open();
    // The host reports the popup's own future through didOpen; hand out that
    // one, so every open() call while it shows gets the same future.
    return _closed ?? opened ?? Future.value(CoilPopupCloseReason.programmatic);
  }

  /// Closes the popup with [CoilPopupCloseReason.programmatic]. Does
  /// nothing when it is closed.
  void close() {
    if (isOpen) _host?.close(CoilPopupCloseReason.programmatic);
  }

  /// Connects the popup. `CoilAdaptivePopup` calls this; apps don't.
  void attach({
    required Future<CoilPopupCloseReason> Function() open,
    required void Function(CoilPopupCloseReason reason) close,
  }) {
    _host = _CoilPopupHost(open, close);
  }

  /// Disconnects the popup. A popup that goes away while open still
  /// resolves its future, but the controller forgets it without notifying.
  void detach() {
    _host = null;
    _closed = null;
  }

  /// Reports that the popup opened; [closed] resolves when it closes.
  /// `CoilAdaptivePopup` calls this; apps don't.
  void didOpen(Future<CoilPopupCloseReason> closed) {
    _closed = closed;
    notifyListeners();
    unawaited(
      closed.whenComplete(() {
        if (_closed != closed) return;
        _closed = null;
        notifyListeners();
      }),
    );
  }
}

class _CoilPopupHost {
  _CoilPopupHost(this.open, this.close);

  final Future<CoilPopupCloseReason> Function() open;
  final void Function(CoilPopupCloseReason reason) close;
}

/// One open popup, as `CoilAdaptivePopup` hands it to its content: close it
/// with a reason, or wait for it to close.
abstract interface class CoilPopupHandle {
  /// How it opened: anchored or in a sheet.
  CoilPresentation get presentation;

  /// Resolves once, when the popup closes.
  Future<CoilPopupCloseReason> get closed;

  /// Closes the popup with [reason]. Only the first close counts.
  void close(CoilPopupCloseReason reason);
}
