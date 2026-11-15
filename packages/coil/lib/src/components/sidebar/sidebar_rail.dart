import 'package:coil/foundation.dart';
import 'package:coil/kbd.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/sidebar/sidebar_scope.dart';
import 'package:coil/src/components/sidebar/sidebar_style.dart';
import 'package:coil/src/components/sidebar/sidebar_text.dart';
import 'package:coil/tooltip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The grab strip on an open sidebar's inner edge, for pointers.
///
/// Dragging it resizes the sidebar between the scaffold's `minWidth` and
/// `maxWidth`, following the pointer. Dragging 56 past the minimum folds
/// the sidebar away, and pulling back before release opens it again.
/// Clicking it folds the sidebar. Hovering brightens the edge and shows a
/// tooltip beside the strip that follows the pointer: [resizeHint] and
/// [collapseHint] with the toggle key.
///
/// It isn't a tab stop: the keyboard toggles with the scaffold's shortcuts.
/// Screen readers get increase and decrease actions that resize in steps
/// of 16, and a tap that folds. A touch tier shows no rail.
class CoilSidebarRail extends StatefulWidget {
  /// Creates a rail.
  const CoilSidebarRail({
    super.key,
    this.semanticLabel = 'Resize or collapse sidebar',
    this.resizeHint,
    this.collapseHint,
  });

  /// The rail's name for screen readers.
  final String semanticLabel;

  /// The tooltip's first line. Null is "**Drag** to resize".
  final Widget? resizeHint;

  /// The tooltip's second line, before the key. Null is "**Click** to
  /// collapse".
  final Widget? collapseHint;

  /// How far past the minimum a drag folds the sidebar.
  static const collapseSlop = 56.0;

  @override
  State<CoilSidebarRail> createState() => _CoilSidebarRailState();
}

class _CoilSidebarRailState extends State<CoilSidebarRail> {
  final _states = WidgetStatesController();
  double? _startWidth;
  double _dragged = 0;
  bool _folded = false;

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  void _onDragStart(CoilSidebarScopeData scope) {
    _startWidth = scope.controller.width;
    _dragged = 0;
    _folded = false;
    _states.update(WidgetState.dragged, true);
    scope.setResizing(true);
  }

  void _onDragUpdate(CoilSidebarScopeData scope, double dx) {
    final start = _startWidth;
    if (start == null) return;
    _dragged += scope.physicalLeft ? dx : -dx;
    final raw = start + _dragged;
    final controller = scope.controller;
    if (raw < scope.minWidth - CoilSidebarRail.collapseSlop) {
      if (!_folded) {
        _folded = true;
        controller
          ..width = scope.minWidth
          ..open = false;
      }
      return;
    }
    if (_folded) {
      _folded = false;
      controller.open = true;
    }
    controller.width = raw.clamp(scope.minWidth, scope.maxWidth);
  }

  void _onDragEnd(CoilSidebarScopeData scope) {
    _startWidth = null;
    _states.update(WidgetState.dragged, false);
    scope.setResizing(false);
  }

  void _resizeBy(CoilSidebarScopeData scope, double delta) {
    final controller = scope.controller;
    controller.width = (controller.width + delta).clamp(
      scope.minWidth,
      scope.maxWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = CoilSidebarScope.maybeOf(context);
    if (scope == null ||
        scope.drawer ||
        CoilTheme.tierOf(context) == CoilTier.touch) {
      return const SizedBox.shrink();
    }
    final theme = CoilTheme.of(context);
    final look = CoilSidebarStyle.fallback(
      theme,
      CoilTheme.metricsOf(context),
    ).merge(CoilTheme.styleOf<CoilSidebarStyle>(context));
    final motion = CoilTheme.motionOf(context);
    Widget hint(String verb, String rest) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: verb,
            style: TextStyle(fontVariations: CoilWeight.semibold.variations),
          ),
          TextSpan(text: rest),
        ],
      ),
    );
    final rail = Semantics(
      label: widget.semanticLabel,
      onTap: scope.toggle,
      onIncrease: () => _resizeBy(scope, 16),
      onDecrease: () => _resizeBy(scope, -16),
      child: CoilInteractionDetector(
        states: _states,
        onTap: scope.toggle,
        excludeFromSemantics: true,
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: (_) => _onDragStart(scope),
          onHorizontalDragUpdate: (details) =>
              _onDragUpdate(scope, details.primaryDelta ?? 0),
          onHorizontalDragEnd: (_) => _onDragEnd(scope),
          onHorizontalDragCancel: () => _onDragEnd(scope),
          child: ValueListenableBuilder(
            valueListenable: _states,
            builder: (context, states, _) {
              final lit =
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.dragged);
              return SingleMotionBuilder(
                value: lit ? 1 : 0,
                motion: lit ? motion.fade : motion.fadeExit,
                builder: (context, opacity, _) => Align(
                  alignment: scope.physicalLeft
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: SizedBox(
                    width: 1,
                    height: double.infinity,
                    child: ColoredBox(
                      color: look.railColor!.withValues(
                        alpha: look.railColor!.a * opacity.clamp(0, 1),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    // As FF: two lines beside the strip, the key after the second, and the
    // bubble following the pointer along the strip. A press hides it, so it
    // stays away while dragging.
    final resize = widget.resizeHint ?? hint('Drag', ' to resize');
    final collapse = widget.collapseHint ?? hint('Click', ' to collapse');
    return CoilTooltip(
      semanticLabel: [
        coilSidebarPlainText(resize),
        coilSidebarPlainText(collapse),
      ].nonNulls.join(', '),
      side: scope.side == CoilSidebarSide.start
          ? CoilTooltipSide.end
          : CoilTooltipSide.start,
      follow: CoilTooltipFollow.pointer,
      message: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          resize,
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              collapse,
              CoilKbd(
                scope.shortcutLabel,
                style: const CoilKbdStyle(size: 16),
              ),
            ],
          ),
        ],
      ),
      child: rail,
    );
  }
}
