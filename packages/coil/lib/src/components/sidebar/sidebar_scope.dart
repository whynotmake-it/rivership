import 'package:coil/src/components/sidebar/sidebar_controller.dart';
import 'package:flutter/widgets.dart';

/// Which edge of the scaffold the sidebar sits on, following the text
/// direction.
enum CoilSidebarSide {
  /// The leading edge: left in a left-to-right layout.
  start,

  /// The trailing edge: right in a left-to-right layout.
  end,
}

/// How the sidebar sits beside the page.
enum CoilSidebarVariant {
  /// A flush column on the page, with a hairline at its inner edge.
  sidebar,

  /// A raised card, inset from the scaffold's edges.
  floating,

  /// Flush rows on the page, while the page itself becomes a raised card.
  inset,
}

/// How the sidebar folds away.
enum CoilSidebarCollapsible {
  /// It slides off the edge, giving the page its width back. The rail, the
  /// toggle shortcut, peeking and the phone drawer all work.
  offcanvas,

  /// It always shows, as a static column: no rail, no shortcut and no
  /// drawer. For a sidebar inside a dialog.
  none,
}

/// What the collapsed edge does.
enum CoilSidebarPeek {
  /// Nothing; only the trigger and the shortcut bring the sidebar back.
  none,

  /// Resting a mouse on the edge, or on the collapsed trigger, floats the
  /// sidebar out over the page for as long as the pointer stays on it.
  hover,

  /// Pressing the edge floats the sidebar out until Escape or a press
  /// elsewhere.
  click,
}

/// What the scaffold shares with the parts inside it.
@immutable
class CoilSidebarScopeData {
  /// Creates scope data.
  const CoilSidebarScopeData({
    required this.controller,
    required this.side,
    required this.physicalLeft,
    required this.drawer,
    required this.peeking,
    required this.peekMode,
    required this.shortcutLabel,
    required this.toggle,
    required this.closeDrawer,
    required this.armPeek,
    required this.disarmPeek,
    required this.setResizing,
    required this.minWidth,
    required this.maxWidth,
  });

  /// The sidebar's state.
  final CoilSidebarController controller;

  /// The edge the sidebar sits on.
  final CoilSidebarSide side;

  /// Whether that edge is the physical left.
  final bool physicalLeft;

  /// Whether this content is the phone drawer.
  final bool drawer;

  /// Whether the collapsed sidebar is floating out as a peek.
  final bool peeking;

  /// What the collapsed edge does, or [CoilSidebarPeek.none] while the
  /// sidebar is open or a drawer.
  final CoilSidebarPeek peekMode;

  /// The key the trigger's tooltip names.
  final String shortcutLabel;

  /// Opens or closes the sidebar (or the drawer).
  final VoidCallback toggle;

  /// Closes the drawer, when this content is one.
  final VoidCallback closeDrawer;

  /// Starts the peek's hover intent.
  final VoidCallback armPeek;

  /// Cancels a pending peek, or lets a hover peek go.
  final VoidCallback disarmPeek;

  /// Tells the scaffold a rail drag started (true) or ended (false), so
  /// the width tracks the pointer instead of springing.
  final ValueChanged<bool> setResizing;

  /// The narrowest the rail resizes to.
  final double minWidth;

  /// The widest the rail resizes to.
  final double maxWidth;

  @override
  bool operator ==(Object other) =>
      other is CoilSidebarScopeData &&
      other.controller == controller &&
      other.side == side &&
      other.physicalLeft == physicalLeft &&
      other.drawer == drawer &&
      other.peeking == peeking &&
      other.peekMode == peekMode &&
      other.shortcutLabel == shortcutLabel &&
      other.minWidth == minWidth &&
      other.maxWidth == maxWidth;

  @override
  int get hashCode => Object.hash(
    controller,
    side,
    physicalLeft,
    drawer,
    peeking,
    peekMode,
    shortcutLabel,
    minWidth,
    maxWidth,
  );
}

/// Shares [CoilSidebarScopeData] with the sidebar's parts.
class CoilSidebarScope extends InheritedWidget {
  /// Creates a scope.
  const CoilSidebarScope({required this.data, required super.child, super.key});

  /// The shared data.
  final CoilSidebarScopeData data;

  /// The nearest scope's data, if any.
  static CoilSidebarScopeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoilSidebarScope>()?.data;

  @override
  bool updateShouldNotify(CoilSidebarScope oldWidget) => oldWidget.data != data;
}
