import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// How the user last interacted: with a keyboard or with a pointer.
enum FluidModality {
  /// The last input was a key press.
  keyboard,

  /// The last input was a pointer going down (mouse, touch, stylus).
  pointer,
}

/// Tracks the last input modality app-wide, to decide when focus should be
/// visible.
///
/// This is what browsers do for `:focus-visible`, minus their quirks: focus
/// is visible only while the last input was a key press. A tap or a click
/// anywhere hides the ring; the next key press brings it back if something
/// is focused. Unlike [FocusManager.highlightMode], a mouse click counts as
/// pointer input here, so clicking a control never shows its ring.
class FluidInputModality extends ValueNotifier<FluidModality> {
  FluidInputModality._() : super(FluidModality.pointer) {
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  static FluidInputModality? _instance;

  /// The app-wide tracker, created on first use.
  // A lazily created singleton, not a factory.
  // ignore: prefer_constructors_over_static_methods
  static FluidInputModality get instance =>
      _instance ??= FluidInputModality._();

  /// Whether a pointer of [kind] can hover, i.e. can produce a hover state
  /// without touching the screen: mice, trackpads and hovering styluses.
  ///
  /// Touch never hovers. A pen only reports enter/hover events while it
  /// actually hovers above the screen, so those are real hovers.
  static bool canHover(PointerDeviceKind kind) => switch (kind) {
    PointerDeviceKind.mouse ||
    PointerDeviceKind.trackpad ||
    PointerDeviceKind.stylus ||
    PointerDeviceKind.invertedStylus => true,
    PointerDeviceKind.touch || PointerDeviceKind.unknown => false,
  };

  bool _onKey(KeyEvent event) {
    // Modifier presses alone (e.g. Cmd while clicking) are not keyboard
    // navigation.
    if (event is KeyDownEvent && !_isModifier(event.logicalKey)) {
      value = FluidModality.keyboard;
    }
    return false;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) value = FluidModality.pointer;
  }

  static final _modifiers = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.fn,
  };

  static bool _isModifier(LogicalKeyboardKey key) => _modifiers.contains(key);

  /// Drops the app-wide tracker so the next [instance] registers fresh
  /// handlers. Test bindings reset keyboard handlers between tests; call
  /// this in `setUp`.
  @visibleForTesting
  static void debugReset() {
    final old = _instance;
    if (old == null) return;
    HardwareKeyboard.instance.removeHandler(old._onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(old._onPointer);
    _instance = null;
  }
}

/// The one place Fluid controls derive their interaction states from.
///
/// Writes into [states]:
///
/// * [WidgetState.hovered] only from pointers that can hover
///   ([FluidInputModality.canHover]). A touch never hovers, so nothing stays
///   lit where a finger lifted.
/// * [WidgetState.pressed] while a pointer (any kind) is down on [child],
///   via a tap recognizer: it clears on release, on cancel, and when the
///   touch turns into a scroll or drag.
/// * [WidgetState.focused] when [focusNode] has focus **and** the last input
///   was the keyboard (`:focus-visible`). Taps and clicks never show it.
/// * [WidgetState.disabled] when not [enabled].
///
/// Components only read [states]; ejected copies inherit the rules.
class FluidInteractionDetector extends StatefulWidget {
  /// Creates an interaction detector.
  const FluidInteractionDetector({
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
  State<FluidInteractionDetector> createState() =>
      _FluidInteractionDetectorState();
}

class _FluidInteractionDetectorState extends State<FluidInteractionDetector> {
  final _modality = FluidInputModality.instance;

  @override
  void initState() {
    super.initState();
    _modality.addListener(_syncFocus);
    widget.focusNode?.addListener(_syncFocus);
    _syncDisabled();
  }

  @override
  void didUpdateWidget(FluidInteractionDetector oldWidget) {
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
      node.hasFocus && _modality.value == FluidModality.keyboard,
    );
  }

  void _setHovered(PointerEvent event, bool value) {
    if (value &&
        (!widget.enabled || !FluidInputModality.canHover(event.kind))) {
      return;
    }
    widget.states.update(WidgetState.hovered, value);
  }

  void _setPressed(bool value) {
    if (value && !widget.enabled) return;
    widget.states.update(WidgetState.pressed, value);
  }

  @override
  Widget build(BuildContext context) {
    var child = widget.child;
    if (widget.trackPress) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: widget.excludeFromSemantics,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
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
