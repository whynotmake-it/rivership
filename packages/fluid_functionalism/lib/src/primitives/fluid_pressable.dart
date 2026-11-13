import 'package:fluid_functionalism/src/foundation/fluid_sizes.dart'
    show FluidSizes;
import 'package:fluid_functionalism/src/primitives/fluid_interaction.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The interaction core of every pressable Fluid control.
///
/// States come from [FluidInteractionDetector], so the rules are the same
/// everywhere and survive ejecting a component:
///
/// * [WidgetState.hovered]: a mouse, trackpad or hovering pen is over the
///   control. Never a touch, so nothing stays lit after a tap.
/// * [WidgetState.pressed]: a pointer is down on the control. Clears on
///   release, cancel, or when the touch becomes a scroll.
/// * [WidgetState.focused]: focused **and** the last input was the keyboard
///   (`:focus-visible`). Taps and clicks never show a focus ring.
/// * [WidgetState.disabled]: [onPressed] is null.
///
/// Enter, Numpad Enter and Space activate it. Pressing does not take focus
/// (as on macOS and iOS); Tab does.
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
  WidgetStatesController? _ownStates;
  FocusNode? _ownFocusNode;

  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'FluidPressable'));

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) => widget.onPressed?.call(),
    ),
  };

  @override
  void didUpdateWidget(FluidPressable oldWidget) {
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
      shortcuts: FluidPressable.activationShortcuts,
      actions: _actions,
      onFocusChange: widget.onFocusChange,
      child: FluidInteractionDetector(
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
