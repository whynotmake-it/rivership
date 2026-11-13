import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/chat_message/chat_message.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

// TODO(coil-context-menu): replace with CoilContextMenu once it exists.
// This is the smallest menu the long press needs: touch rows in a popover
// or a sheet, picked by CoilAdaptivePopup's phone rule.

/// Opens [actions] as a menu anchored to [child] when [controller] opens.
/// A finger opens it, so the rows are touch rows on every tier.
class ChatMessageMenu extends StatelessWidget {
  /// Creates the menu around [child].
  const ChatMessageMenu({
    required this.controller,
    required this.actions,
    required this.child,
    super.key,
  });

  /// Opens the menu.
  final CoilPopupController controller;

  /// The rows.
  final List<CoilChatMessageAction> actions;

  /// The anchor: the message bubble.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.of(
      context,
    ).metrics.resolve(CoilTier.touch, CoilSize.regular);
    return CoilAdaptivePopup(
      controller: controller,
      traits: () => CoilOverlayTraits(
        kind: CoilOverlayKind.contextMenu,
        itemCount: actions.length,
      ),
      content: (context, popup) => _Menu(
        actions: actions,
        metrics: metrics,
        onPick: (action) {
          popup.close(CoilPopupCloseReason.selected);
          action.onPressed?.call();
        },
        onEscape: () => popup.close(CoilPopupCloseReason.escape),
      ),
      popover: (context, content) =>
          _PopoverSurface(metrics: metrics, child: content),
      sheet: (context, content) => CoilSheetPanel(child: content),
      child: child,
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.actions,
    required this.metrics,
    required this.onPick,
    required this.onEscape,
  });

  final List<CoilChatMessageAction> actions;
  final CoilMetrics metrics;
  final ValueChanged<CoilChatMessageAction> onPick;
  final VoidCallback onEscape;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onEscape},
      child: Focus(
        autofocus: true,
        child: Semantics(
          role: SemanticsRole.menu,
          child: Padding(
            padding: EdgeInsets.all(metrics.popupInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final action in actions)
                  _Row(
                    action: action,
                    metrics: metrics,
                    onPressed: action.onPressed == null
                        ? null
                        : () => onPick(action),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A touch row: icon, label, with the press fill while a pointer is down.
class _Row extends StatelessWidget {
  const _Row({
    required this.action,
    required this.metrics,
    required this.onPressed,
  });

  final CoilChatMessageAction action;
  final CoilMetrics metrics;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final motion = CoilTheme.motionOf(context);
    final radius = BorderRadius.circular(theme.shape.radii(metrics.tier).item);
    return Semantics(
      role: SemanticsRole.menuItem,
      label: action.label,
      child: CoilInteraction(
        onPressed: onPressed,
        builder: (context, states, _) {
          final pressed = states.contains(WidgetState.pressed);
          final lit = pressed || states.contains(WidgetState.hovered);
          final fill = pressed
              ? colors.active
              : lit
              ? colors.hover
              : colors.active.withValues(alpha: 0);
          return Opacity(
            opacity: onPressed == null ? 0.4 : 1,
            child: MotionBuilder<Color>(
              value: fill,
              converter: MotionConverter.colorRgb,
              motion: lit ? motion.fade : motion.fadeExit,
              debugLabel: 'CoilChatMessage.menu.row',
              builder: (context, fill, child) => DecoratedBox(
                decoration: ShapeDecoration(
                  color: fill,
                  shape: RoundedSuperellipseBorder(borderRadius: radius),
                ),
                child: child,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: metrics.controlHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.itemPaddingX,
                    vertical: metrics.controlPaddingY(metrics.body),
                  ),
                  child: IconTheme(
                    data: IconThemeData(
                      size: metrics.iconSize,
                      applyTextScaling: true,
                      color: colors.foreground,
                    ),
                    child: Row(
                      spacing: metrics.gap,
                      children: [
                        action.icon,
                        Expanded(
                          child: ExcludeSemantics(
                            child: Text(
                              action.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.style(
                                metrics.body,
                                color: colors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Surface 3, shadow 3, concentric with the rows.
class _PopoverSurface extends StatelessWidget {
  const _PopoverSurface({required this.metrics, required this.child});

  final CoilMetrics metrics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final radius = BorderRadius.circular(
      theme.shape.radii(metrics.tier).item + metrics.popupInset,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: IntrinsicWidth(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.surface(3),
            shadows: colors.shadow(3),
            shape: RoundedSuperellipseBorder(borderRadius: radius),
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: colors.insetRing(3),
              ),
            ),
            child: ClipRSuperellipse(borderRadius: radius, child: child),
          ),
        ),
      ),
    );
  }
}
