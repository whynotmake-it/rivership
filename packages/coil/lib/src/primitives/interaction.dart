import 'dart:async';

import 'package:coil/src/foundation/input_modality.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Writes a control's interaction states into [states], by coil's rules.
///
/// * [WidgetState.hovered]: only from pointers that can hover (mouse,
///   trackpad, hovering pen). A touch never hovers, so nothing stays lit
///   where a finger lifted.
/// * [WidgetState.pressed]: while a pointer is down on [child]. It clears on
///   release, on cancel, and when the touch turns into a scroll. A quick tap
///   still shows it for `CoilMotion.minPressDuration`.
/// * [WidgetState.focused]: when [focusNode] has focus and the last input
///   was the keyboard. Taps and clicks never show it.
/// * [WidgetState.disabled]: when not [enabled].
///
/// Use it for a control that owns its own focus or gestures (a text field,
/// a list row); otherwise use [CoilInteraction].
class CoilInteractionDetector extends StatefulWidget {
  /// Creates an interaction detector.
  const CoilInteractionDetector({
    required this.states,
    required this.child,
    super.key,
    this.enabled = true,
    this.focusNode,
    this.onTap,
    this.trackPress = true,
    this.cursor = MouseCursor.defer,
    this.excludeFromSemantics = false,
  });

  /// The states to write.
  final WidgetStatesController states;

  /// The interactive area.
  final Widget child;

  /// Whether the control is enabled. Disabled controls neither hover nor
  /// press.
  final bool enabled;

  /// The node whose focus drives [WidgetState.focused], if any.
  final FocusNode? focusNode;

  /// Called on a completed tap.
  final VoidCallback? onTap;

  /// Whether to recognize taps and report [WidgetState.pressed]. Off for
  /// controls that handle their own gestures (a text field).
  final bool trackPress;

  /// The mouse cursor over [child].
  final MouseCursor cursor;

  /// Whether to leave the tap action out of semantics.
  final bool excludeFromSemantics;

  @override
  State<CoilInteractionDetector> createState() =>
      _CoilInteractionDetectorState();
}

class _CoilInteractionDetectorState extends State<CoilInteractionDetector> {
  final _modality = CoilInputModality.instance;
  final _pressWatch = Stopwatch();
  Timer? _pressRelease;

  @override
  void initState() {
    super.initState();
    _modality.addListener(_syncFocus);
    widget.focusNode?.addListener(_syncFocus);
    _syncDisabled();
  }

  @override
  void didUpdateWidget(CoilInteractionDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_syncFocus);
      widget.focusNode?.addListener(_syncFocus);
      _syncFocus();
    }
    _syncDisabled();
  }

  @override
  void dispose() {
    _pressRelease?.cancel();
    _modality.removeListener(_syncFocus);
    widget.focusNode?.removeListener(_syncFocus);
    super.dispose();
  }

  void _syncDisabled() {
    widget.states.update(WidgetState.disabled, !widget.enabled);
    if (!widget.enabled) {
      widget.states
        ..update(WidgetState.pressed, false)
        ..update(WidgetState.hovered, false);
    }
  }

  void _syncFocus() {
    final node = widget.focusNode;
    if (node == null) return;
    widget.states.update(
      WidgetState.focused,
      node.hasFocus && _modality.value == CoilModality.keyboard,
    );
  }

  void _setHovered(PointerEvent event, bool value) {
    if (value && (!widget.enabled || !CoilInputModality.canHover(event.kind))) {
      return;
    }
    widget.states.update(WidgetState.hovered, value);
  }

  void _setPressed(bool value, {bool completed = false}) {
    _pressRelease?.cancel();
    if (value) {
      if (!widget.enabled) return;
      _pressWatch
        ..reset()
        ..start();
      widget.states.update(WidgetState.pressed, true);
      return;
    }
    // A tap that lifts before the press could be seen still shows it for
    // the theme's minimum, as iOS cells do.
    final minimum = CoilTheme.motionOf(context).minPressDuration;
    final remaining = minimum - _pressWatch.elapsed;
    // A cancel (the touch became a scroll, or left) clears at once.
    if (!completed || remaining <= Duration.zero || !widget.enabled) {
      widget.states.update(WidgetState.pressed, false);
      return;
    }
    _pressRelease = Timer(remaining, () {
      if (mounted) widget.states.update(WidgetState.pressed, false);
    });
  }

  @override
  Widget build(BuildContext context) {
    var child = widget.child;
    if (widget.trackPress) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: widget.excludeFromSemantics,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false, completed: true),
        onTapCancel: () => _setPressed(false),
        onTap: widget.enabled ? widget.onTap : null,
        child: child,
      );
    }
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (event) => _setHovered(event, true),
      onHover: (event) => _setHovered(event, true),
      onExit: (event) => _setHovered(event, false),
      child: child,
    );
  }
}

/// A pressable control: focus, keyboard activation and interaction states
/// for [builder].
///
/// States follow [CoilInteractionDetector]'s rules; it is disabled when
/// [onPressed] is null. Enter, Numpad Enter and Space activate it. Pressing
/// doesn't take focus (as on macOS and iOS); Tab does.
///
/// Pass a [statesController] to observe the states.
class CoilInteraction extends StatefulWidget {
  /// Creates a pressable.
  const CoilInteraction({
    required this.onPressed,
    required this.builder,
    super.key,
    this.child,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.mouseCursor,
    this.minHitTarget = 0,
    this.onFocusChange,
    this.excludeFromSemantics = false,
  });

  /// Called when the control is activated. Null disables it.
  final VoidCallback? onPressed;

  /// Builds the visual from the current states.
  final ValueWidgetBuilder<Set<WidgetState>> builder;

  /// A child passed through to [builder].
  final Widget? child;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// Whether to request focus when first built.
  final bool autofocus;

  /// Observes, and can force, the interaction states.
  final WidgetStatesController? statesController;

  /// The cursor over the control. Defaults to a click cursor when enabled.
  final MouseCursor? mouseCursor;

  /// The smallest square the hit area may be. The visual is centered in it.
  /// See [CoilMetrics.minHitTarget].
  final double minHitTarget;

  /// Called when the control gains or loses focus (by any means).
  final ValueChanged<bool>? onFocusChange;

  /// Whether to leave the tap action out of the semantics tree (when the
  /// caller provides its own).
  final bool excludeFromSemantics;

  /// Whether the control is enabled.
  bool get enabled => onPressed != null;

  /// Enter, Numpad Enter and Space.
  static const activationShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  @override
  State<CoilInteraction> createState() => _CoilInteractionState();
}

class _CoilInteractionState extends State<CoilInteraction> {
  WidgetStatesController? _ownStates;
  FocusNode? _ownFocusNode;

  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'CoilInteraction'));

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) => widget.onPressed?.call(),
    ),
  };

  @override
  void didUpdateWidget(CoilInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      _ownStates?.dispose();
      _ownStates = null;
    }
  }

  @override
  void dispose() {
    _ownStates?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget visual = ListenableBuilder(
      listenable: _states,
      builder: (context, child) =>
          widget.builder(context, _states.value, child),
      child: widget.child,
    );
    if (widget.minHitTarget > 0) {
      visual = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minHitTarget,
          minHeight: widget.minHitTarget,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: visual),
      );
    }
    return FocusableActionDetector(
      enabled: widget.enabled,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      shortcuts: CoilInteraction.activationShortcuts,
      actions: _actions,
      onFocusChange: widget.onFocusChange,
      child: CoilInteractionDetector(
        states: _states,
        enabled: widget.enabled,
        focusNode: _focusNode,
        onTap: widget.onPressed,
        cursor:
            widget.mouseCursor ??
            (widget.enabled ? SystemMouseCursors.click : MouseCursor.defer),
        excludeFromSemantics: widget.excludeFromSemantics,
        child: visual,
      ),
    );
  }
}
