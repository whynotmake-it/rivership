import 'package:flutter/foundation.dart';

/// The state of a `CoilSidebarScaffold`'s sidebar: whether it is open and
/// how wide it is.
///
/// Pass one to the scaffold to drive the sidebar from outside, or to keep
/// its state between launches: listen to it, save [open] and [width], and
/// create the next controller with the saved values. coil stores nothing
/// itself. The scaffold creates its own when you pass none.
///
/// [open] is the sidebar beside the page. A phone's drawer and a peek are
/// transient and never change it.
class CoilSidebarController extends ChangeNotifier {
  /// Creates a controller, open and 256 wide unless told otherwise.
  CoilSidebarController({this._open = true, this._width = 256});

  bool _open;
  double _width;
  VoidCallback? _toggle;

  /// Whether the sidebar shows beside the page.
  bool get open => _open;
  set open(bool value) {
    if (value == _open) return;
    _open = value;
    notifyListeners();
  }

  /// The sidebar's width beside the page. Dragging its rail changes it.
  double get width => _width;
  set width(double value) {
    if (value == _width) return;
    _width = value;
    notifyListeners();
  }

  /// Opens or closes the sidebar. Where the scaffold shows it as a drawer,
  /// this opens the drawer instead, and [open] stays as it is.
  void toggle() => _toggle != null ? _toggle!() : open = !open;
}

/// Lets a scaffold decide what [CoilSidebarController.toggle] does, or
/// stop deciding with null. `sidebar.dart` hides it: only the scaffold
/// calls it.
void attachSidebarScaffold(
  CoilSidebarController controller,
  VoidCallback? toggle,
) => controller._toggle = toggle;
