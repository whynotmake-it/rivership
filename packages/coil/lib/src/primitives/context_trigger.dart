import 'dart:async';

import 'package:coil/src/foundation/haptics.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// How a context menu was asked for.
enum CoilContextSource {
  /// A right-click, or a Control-click on macOS.
  pointer,

  /// A long press on a touch screen.
  touch,

  /// Shift+F10 or the Menu key, or a screen reader's long-press action.
  keyboard,
}

/// A request to open a context menu over [CoilContextTrigger]'s child.
@immutable
class CoilContextRequest {
  /// Describes a request.
  const CoilContextRequest({required this.source, this.position});

  /// What asked for it.
  final CoilContextSource source;

  /// Where, in the child's local coordinates. Null for the keyboard: the
  /// menu then opens next to the child.
  final Offset? position;
}

/// Reports the platform's context-menu gestures on [child] to [onRequest]:
///
/// * A right-click, on its release.
/// * A Control-click on macOS, which also keeps the click from reaching
///   [child].
/// * A 500 ms long press on a touch screen, which plays the
///   [CoilHapticEvent.longPress] haptic.
/// * Shift+F10 or the Menu key while focus is inside [child].
/// * A screen reader's long-press action.
///
/// While [lifted], [child] scales up slightly, the way a long-pressed item
/// lifts toward the finger under its menu.
class CoilContextTrigger extends StatelessWidget {
  /// Creates a context trigger.
  const CoilContextTrigger({
    required this.onRequest,
    required this.child,
    super.key,
    this.lifted = false,
  });

  /// Called when a context menu is asked for.
  final ValueChanged<CoilContextRequest> onRequest;

  /// Whether [child] shows lifted.
  final bool lifted;

  /// The content the menu is for.
  final Widget child;

  /// How far a lifted child grows.
  static const liftScale = 1.02;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    void request(CoilContextSource source, [Offset? position]) =>
        onRequest(CoilContextRequest(source: source, position: position));
    void longPress(Offset position) {
      unawaited(CoilHaptics.play(context, CoilHapticEvent.longPress));
      request(.touch, position);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f10, shift: true): () =>
            request(.keyboard),
        const SingleActivator(LogicalKeyboardKey.contextMenu): () =>
            request(.keyboard),
      },
      child: RawGestureDetector(
        semantics: _LongPressSemantics(() => request(.keyboard)),
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(debugOwner: this),
                (recognizer) => recognizer.onSecondaryTapUp = (details) =>
                    request(.pointer, details.localPosition),
              ),
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  debugOwner: this,
                  supportedDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                  },
                ),
                (recognizer) => recognizer.onLongPressStart = (details) =>
                    longPress(details.localPosition),
              ),
          if (defaultTargetPlatform == TargetPlatform.macOS)
            _ControlClickRecognizer:
                GestureRecognizerFactoryWithHandlers<_ControlClickRecognizer>(
                  () => _ControlClickRecognizer(debugOwner: this),
                  (recognizer) => recognizer.onClick = (position) =>
                      request(.pointer, position),
                ),
        },
        child: SingleMotionBuilder(
          value: lifted ? liftScale : 1,
          motion: lifted ? motion.quick : motion.quickExit,
          child: child,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
        ),
      ),
    );
  }
}

/// A Control-click with the primary button. It claims the pointer when it
/// goes down, so the click doesn't also reach the child.
class _ControlClickRecognizer extends OneSequenceGestureRecognizer {
  _ControlClickRecognizer({super.debugOwner});

  ValueChanged<Offset>? onClick;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      event.buttons == kPrimaryMouseButton &&
      event.kind == PointerDeviceKind.mouse &&
      HardwareKeyboard.instance.isControlPressed &&
      super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) {
      onClick?.call(event.localPosition);
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'control click';
}

/// Gives screen readers a long-press action that opens the menu next to the
/// child, instead of the default one, which reports a long press at the
/// child's corner.
class _LongPressSemantics extends SemanticsGestureDelegate {
  const _LongPressSemantics(this.onLongPress);

  final VoidCallback onLongPress;

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) {
    renderObject.onLongPress = onLongPress;
  }
}
