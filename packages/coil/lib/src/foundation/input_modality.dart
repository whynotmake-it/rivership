import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// How the user last interacted: with a keyboard or with a pointer.
enum CoilModality {
  /// The last input was a key press.
  keyboard,

  /// The last input was a pointer going down (mouse, touch, stylus).
  pointer,
}

/// Tracks the last input modality app-wide, to decide when focus should be
/// visible. The one modality tracker in coil.
///
/// This is what browsers do for `:focus-visible`, minus their quirks: focus
/// is visible only while the last input was a key press. A tap or a click
/// anywhere hides the ring; the next key press brings it back if something
/// is focused. Unlike [FocusManager.highlightMode], a mouse click counts as
/// pointer input here, so clicking a control never shows its ring.
class CoilInputModality extends ValueNotifier<CoilModality> {
  CoilInputModality._() : super(CoilModality.pointer) {
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  static CoilInputModality? _instance;

  /// The app-wide tracker, created on first use.
  // A lazily created singleton, not a factory.
  // ignore: prefer_constructors_over_static_methods
  static CoilInputModality get instance => _instance ??= CoilInputModality._();

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

  /// The kind of the last pointer that went down anywhere in the app, or
  /// null before the first one.
  PointerDeviceKind? get lastPointerKind => _lastPointerKind;
  PointerDeviceKind? _lastPointerKind;

  bool _onKey(KeyEvent event) {
    // Modifier presses alone (e.g. Cmd while clicking) are not keyboard
    // navigation.
    if (event is KeyDownEvent && !_isModifier(event.logicalKey)) {
      value = CoilModality.keyboard;
    }
    return false;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      _lastPointerKind = event.kind;
      value = CoilModality.pointer;
    }
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
