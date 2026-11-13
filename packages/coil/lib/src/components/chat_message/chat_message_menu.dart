import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:flutter/widgets.dart';

// TODO(coil-context-menu): replace with CoilContextMenu once it exists.

/// Opens [actions] as a menu anchored to [child] when [controller] opens:
/// a popover, or a sheet by [CoilAdaptivePopup]'s phone rule. A finger
/// opens it, so the rows are touch rows on every tier.
class ChatMessageMenu extends StatelessWidget {
  /// Creates the menu around [child].
  const ChatMessageMenu({
    required this.controller,
    required this.actions,
    required this.minWidth,
    required this.child,
    super.key,
  });

  /// Opens the menu.
  final CoilPopupController controller;

  /// The rows.
  final List<CoilAction> actions;

  /// The narrowest the popover gets.
  final double minWidth;

  /// The anchor: the message bubble.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = theme.metrics.resolve(CoilTier.touch, CoilSize.regular);
    // TODO(surface-scope): read the popover's surface from the scope.
    final surface = theme.colors.surface(3);
    final scroll = CoilScrollAreaStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilScrollAreaStyle>(context));
    return CoilAdaptivePopup(
      controller: controller,
      traits: () => CoilOverlayTraits(
        kind: CoilOverlayKind.contextMenu,
        itemCount: actions.length,
      ),
      content: (context, popup) => CoilActionList(
        entries: actions,
        onClose: popup.close,
        metrics: metrics,
        surface: surface,
        scrollbar: scroll.scrollbarLook,
        fadeExtent: scroll.fadeExtent!,
      ),
      popover: (context, content) => CoilPopoverSurface(
        color: surface,
        radius: theme.shape.radii(metrics.tier).item + metrics.popupInset,
        minWidth: minWidth,
        child: content,
      ),
      sheet: (context, content) => CoilSheetPanel(child: content),
      child: child,
    );
  }
}
