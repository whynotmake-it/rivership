import 'package:fluid_functionalism/fluid_functionalism.dart' show FluidSizes;
import 'package:fluid_functionalism/src/foundation/fluid_sizes.dart'
    show FluidSizes;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The interaction core of every pressable Fluid control.
///
/// Tracks [WidgetState]s the way the web's CSS pseudo-classes do:
///
/// * [WidgetState.hovered]: a mouse is over the control (`:hover`).
/// * [WidgetState.focused]: the control has focus **and** focus should be
///   visible, i.e. it was reached with the keyboard (`:focus-visible`).
///   Pointer focus never sets it. This follows
///   [FocusManager.highlightMode] through [FocusableActionDetector].
/// * [WidgetState.pressed]: a pointer is down on the control (`:active`).
/// * [WidgetState.disabled]: [onPressed] is null.
///
/// Enter, Numpad Enter and Space activate it.
///
/// Pass a [statesController] to observe the states or to force some (golden
/// tests and docs force hovered/pressed/focused this way). The control
/// still updates the controller from real input.
class FluidPressable extends StatefulWidget {
  /// Creates a pressable.
  const FluidPressable({
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
  /// See [FluidSizes.minHitTarget].
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
  State<FluidPressable> createState() => _FluidPressableState();
}

class _FluidPressableState extends State<FluidPressable> {
  WidgetStatesController? _internalController;

  WidgetStatesController get _states =>
      widget.statesController ??
      (_internalController ??= WidgetStatesController());

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) => _activate(),
    ),
  };

  @override
  void initState() {
    super.initState();
    _states.update(WidgetState.disabled, !widget.enabled);
  }

  @override
  void didUpdateWidget(FluidPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      _internalController?.dispose();
      _internalController = null;
    }
    _states.update(WidgetState.disabled, !widget.enabled);
    if (!widget.enabled) _states.update(WidgetState.pressed, false);
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  void _activate() => widget.onPressed?.call();

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    _states.update(WidgetState.pressed, value);
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
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      shortcuts: FluidPressable.activationShortcuts,
      actions: _actions,
      mouseCursor:
          widget.mouseCursor ??
          (widget.enabled ? SystemMouseCursors.click : MouseCursor.defer),
      onShowFocusHighlight: (value) =>
          _states.update(WidgetState.focused, value),
      onFocusChange: widget.onFocusChange,
      // Hover is pointer state, not focus state: tracked with a plain
      // MouseRegion so it works whatever the focus highlight mode is
      // (FocusableActionDetector hides hover in touch highlight mode).
      child: MouseRegion(
        onEnter: (_) {
          if (widget.enabled) _states.update(WidgetState.hovered, true);
        },
        onExit: (_) => _states.update(WidgetState.hovered, false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: widget.excludeFromSemantics,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.enabled ? _activate : null,
          child: visual,
        ),
      ),
    );
  }
}
