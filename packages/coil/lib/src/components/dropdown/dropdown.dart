import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/dropdown/dropdown_style.dart';
import 'package:coil/src/components/dropdown/menu_popup.dart';
import 'package:flutter/widgets.dart';

/// Builds a dropdown's trigger. Call `controller.open()` to show the menu.
typedef CoilDropdownTriggerBuilder =
    Widget Function(BuildContext context, CoilPopupController controller);

/// An action menu: [entries] in a popover next to the trigger, or in a
/// sheet on a phone when the menu is long.
///
/// Rows are [CoilAction]s, grouped with [CoilMenuLabel]s and
/// [CoilMenuSeparator]s. A hovering pointer lights rows with a gliding
/// highlight; arrows, Home, End and typing move between rows; Enter or
/// Space picks; Escape and Tab close. Picking an action closes the menu and
/// runs it; a checkable row shows its mark first.
///
/// On a phone, a short menu stays anchored with touch-sized rows and a long
/// one opens as a sheet (see [CoilAdaptivePopup.presentationOf]).
/// [presentation] pins one.
///
/// ```dart
/// CoilDropdown(
///   entries: [
///     CoilAction(label: const Text('Rename'), onPressed: rename),
///     const CoilMenuSeparator(),
///     CoilAction(
///       label: const Text('Delete'),
///       tone: CoilActionTone.destructive,
///       onPressed: delete,
///     ),
///   ],
///   builder: (context, menu) => CoilButton(
///     onPressed: menu.open,
///     child: const Text('Actions'),
///   ),
/// )
/// ```
class CoilDropdown extends StatefulWidget {
  /// Creates a dropdown.
  const CoilDropdown({
    required this.entries,
    required this.builder,
    super.key,
    this.controller,
    this.presentation,
    this.search,
    this.style,
    this.motion,
  });

  /// The rows, headings and separators.
  final List<CoilMenuEntry> entries;

  /// Builds the trigger.
  final CoilDropdownTriggerBuilder builder;

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
  State<CoilDropdown> createState() => _CoilDropdownState();
}

class _CoilDropdownState extends State<CoilDropdown> {
  CoilPopupController? _own;

  CoilPopupController get _controller =>
      widget.controller ?? (_own ??= CoilPopupController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoilMenuPopup(
    controller: _controller,
    entries: widget.entries,
    kind: CoilOverlayKind.actionMenu,
    presentation: widget.presentation,
    search: widget.search,
    style: widget.style,
    motion: widget.motion,
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Semantics(
        expanded: _controller.isOpen,
        child: widget.builder(context, _controller),
      ),
    ),
  );
}
