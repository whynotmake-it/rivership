import 'dart:math' as math;

import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/modal.dart';
import 'package:coil/src/primitives/sheet.dart';
import 'package:coil/src/primitives/surface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Shows [drawer] as a modal panel sliding in from [edge] over [child]
/// while [open] is true.
///
/// Unlike a route, the drawer stays a descendant of this widget: it shows
/// the owner's current state and rebuilds with it, the way Flutter's
/// `Scaffold` keeps its drawer. While open:
///
/// * a scrim covers [child]; pressing it calls [onClose];
/// * Escape, system back and dragging the panel toward [edge] call
///   [onClose] (a fling decides by its direction, a slow release by how far
///   the panel moved);
/// * focus stays inside the panel, and returns to where it was on close;
/// * screen readers only reach the panel, named [label].
///
/// It slides in on [motion] and out on [exitMotion] (the theme's
/// `standard` and `standardExit` by default); a drag follows the finger
/// and its velocity carries into the spring. [width] is the panel's width,
/// 85 % of this widget's width when null, at most 320.
class CoilDrawer extends StatefulWidget {
  /// Creates a drawer host.
  const CoilDrawer({
    required this.open,
    required this.onClose,
    required this.drawer,
    required this.child,
    super.key,
    this.edge = CoilDrawerEdge.start,
    this.width,
    this.label,
    this.motion,
    this.exitMotion,
  });

  /// Whether the drawer shows.
  final bool open;

  /// Called when the user dismisses the drawer. Set [open] to false.
  final VoidCallback onClose;

  /// The panel's content.
  final Widget drawer;

  /// What the drawer covers.
  final Widget child;

  /// The edge the panel slides in from.
  final CoilDrawerEdge edge;

  /// The panel's width.
  final double? width;

  /// The panel's name for screen readers.
  final String? label;

  /// The slide in. The theme's `standard` when null.
  final Motion? motion;

  /// The slide out. The theme's `standardExit` when null.
  final Motion? exitMotion;

  @override
  State<CoilDrawer> createState() => _CoilDrawerState();
}

class _CoilDrawerState extends State<CoilDrawer> {
  // Always showing: closed and settled, the layer is offstage, so the
  // drawer's content keeps its state and nothing is shown during build.
  final _portal = OverlayPortalController(debugLabel: 'CoilDrawer')..show();
  final _scope = FocusScopeNode(debugLabel: 'CoilDrawer');
  LocalHistoryEntry? _entry;
  FocusNode? _focusBefore;

  /// The panel's presence while a finger drags it, or null.
  double? _drag;

  /// Whether the panel is out of sight.
  bool _settledClosed = true;

  @override
  void initState() {
    super.initState();
    if (widget.open) _opened();
  }

  @override
  void didUpdateWidget(CoilDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open == oldWidget.open) return;
    widget.open ? _opened() : _closed();
  }

  @override
  void dispose() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    _scope.dispose();
    super.dispose();
  }

  void _opened() {
    _focusBefore = FocusManager.instance.primaryFocus;
    _drag = null;
    _settledClosed = false;
  }

  void _closed() {
    _drag = null;
    final entry = _entry;
    _entry = null;
    entry?.remove();
    final previous = _focusBefore;
    _focusBefore = null;
    if (previous != null && previous.context != null) previous.requestFocus();
  }

  void _onEntryRemoved() {
    // Removed by back, not by [_closed].
    if (_entry == null) return;
    _entry = null;
    widget.onClose();
  }

  void _onStatus(AnimationStatus status) {
    // Back closes the drawer through the route it sits in, as it does
    // Scaffold's. Like Scaffold's, the entry joins once the drawer moves.
    // The panel takes focus once it can: it is no longer excluded by the
    // time it moves.
    if (widget.open && !_scope.hasFocus) _scope.requestFocus();
    if (widget.open && _entry == null) {
      if (ModalRoute.of(context) case final route?) {
        route.addLocalHistoryEntry(
          _entry = LocalHistoryEntry(onRemove: _onEntryRemoved),
        );
      }
    }
    if (!status.isAnimating && !widget.open && !_settledClosed) {
      setState(() => _settledClosed = true);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tokens = CoilTheme.motionOf(context);
      final panelWidth =
          widget.width ?? math.min(320, constraints.maxWidth * 0.85).toDouble();
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final left = (widget.edge == CoilDrawerEdge.start) != rtl;
      final target = _drag ?? (widget.open ? 1.0 : 0.0);
      final motion = _drag != null
          ? const Motion.instant()
          : widget.open
          ? widget.motion ?? tokens.standard
          : widget.exitMotion ?? tokens.standardExit;
      return OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => SingleMotionBuilder(
          value: target,
          from: 0,
          motion: motion,
          onAnimationStatusChanged: _onStatus,
          builder: (context, presence, child) => _Layer(
            hidden: _settledClosed && !widget.open,
            scope: _scope,
            presence: presence.clamp(0, 1),
            open: widget.open,
            left: left,
            width: panelWidth,
            label: widget.label,
            onClose: widget.onClose,
            onDragUpdate: (delta) => setState(() {
              final towardEdge = left ? -delta : delta;
              _drag = ((_drag ?? 1.0) - towardEdge / panelWidth).clamp(0, 1);
            }),
            onDragEnd: (velocity) {
              final towardEdge = left ? -velocity : velocity;
              final position = _drag ?? 1.0;
              final close =
                  towardEdge > 400 || (towardEdge > -400 && position < 0.5);
              setState(() => _drag = null);
              if (close) widget.onClose();
            },
            child: child!,
          ),
          child: widget.drawer,
        ),
        child: widget.child,
      );
    },
  );
}

/// The scrim and the sliding panel.
class _Layer extends StatelessWidget {
  const _Layer({
    required this.hidden,
    required this.scope,
    required this.presence,
    required this.open,
    required this.left,
    required this.width,
    required this.label,
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.child,
  });

  final bool hidden;
  final FocusScopeNode scope;
  final double presence;
  final bool open;
  final bool left;
  final double width;
  final String? label;
  final VoidCallback onClose;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final barrier = CoilSheetPanel.barrierColorOf(context);
    return Offstage(
      offstage: hidden,
      child: ExcludeFocus(
        excluding: !open,
        child: IgnorePointer(
          ignoring: !open,
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  onDismiss: onClose,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    excludeFromSemantics: true,
                    child: ColoredBox(
                      color: barrier.withValues(alpha: barrier.a * presence),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: left ? 0 : null,
                right: left ? null : 0,
                width: width,
                child: FractionalTranslation(
                  translation: Offset((1 - presence) * (left ? -1 : 1), 0),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) =>
                        onDragUpdate(details.primaryDelta ?? 0),
                    onHorizontalDragEnd: (details) =>
                        onDragEnd(details.primaryVelocity ?? 0),
                    child: BlockSemantics(
                      child: Semantics(
                        scopesRoute: true,
                        namesRoute: true,
                        explicitChildNodes: true,
                        label: label,
                        // Above the scope, so Escape also works while
                        // the scope itself holds focus.
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.escape):
                                onClose,
                          },
                          child: FocusScope(
                            node: scope,
                            child: CoilSurface(
                              offset: 2,
                              shadowLevel: 3,
                              borderRadius: BorderRadius.zero,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
