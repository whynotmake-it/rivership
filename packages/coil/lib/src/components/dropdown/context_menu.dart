import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/dropdown/dropdown_style.dart';
import 'package:coil/src/components/dropdown/menu_popup.dart';
import 'package:flutter/widgets.dart';

/// A menu of [entries] for [child], opened where the user asks for it: a
/// right-click (Control-click on macOS) opens it at the pointer, a long
/// press on a touch screen at the finger, and Shift+F10 or the Menu key
/// next to [child].
///
/// It is a `CoilDropdown` opened at a point, with the same rows, keys and
/// [CoilDropdownStyle]. A long press lifts [child] with a haptic while the
/// menu is open; on a phone a long menu opens as a sheet instead.
///
/// ```dart
/// CoilContextMenu(
///   entries: [
///     CoilAction(label: const Text('Copy'), onPressed: copy),
///     CoilAction(label: const Text('Paste'), onPressed: paste),
///   ],
///   child: const FileTile(),
/// )
/// ```
class CoilContextMenu extends StatefulWidget {
  /// Creates a context menu for [child].
  const CoilContextMenu({
    required this.entries,
    required this.child,
    super.key,
    this.controller,
    this.presentation,
    this.search,
    this.style,
    this.motion,
  });

  /// The rows, headings and separators.
  final List<CoilMenuEntry> entries;

  /// What the menu is for.
  final Widget child;

  /// Opens and closes the menu from outside; one is created if null.
  final CoilPopupController? controller;

  /// Pins the presentation instead of deciding it when the menu opens.
  final CoilPresentation? presentation;

  /// Shows a field over the rows that filters them by label. On a phone a
  /// menu with search opens as a sheet.
  final CoilMenuSearch? search;

  /// Overrides the theme's dropdown style.
  final CoilDropdownStyle? style;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  State<CoilContextMenu> createState() => _CoilContextMenuState();
}

class _CoilContextMenuState extends State<CoilContextMenu> {
  CoilPopupController? _own;

  /// Whether a long press opened the open menu.
  bool _lifted = false;

  CoilPopupController get _controller =>
      widget.controller ?? (_own ??= CoilPopupController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  Future<void> _open(CoilContextRequest request) async {
    if (_controller.isOpen) return;
    setState(() => _lifted = request.source == CoilContextSource.touch);
    await _controller.open(position: request.position);
    if (mounted) setState(() => _lifted = false);
  }

  @override
  Widget build(BuildContext context) => CoilMenuPopup(
    controller: _controller,
    entries: widget.entries,
    kind: CoilOverlayKind.contextMenu,
    presentation: widget.presentation,
    search: widget.search,
    style: widget.style,
    motion: widget.motion,
    child: CoilContextTrigger(
      onRequest: _open,
      lifted: _lifted,
      child: widget.child,
    ),
  );
}
