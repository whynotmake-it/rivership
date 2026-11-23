import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Drags something you can pick up: a card, a square, a dial's needle.
///
/// A plain pan needs twice the slop of a horizontal or vertical drag, so
/// inside a scrolling page the scroll (and any other drag around it) wins
/// before the pan does, and the thing can't be moved at all on a touch
/// screen. This pan claims the pointer as soon as it moves, so a drag that
/// starts on [child] always moves it. Start a scroll beside it instead.
class GrabDetector extends StatelessWidget {
  const GrabDetector({
    required this.child,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onCancel,
    super.key,
  });

  final GestureDragStartCallback? onStart;
  final GestureDragUpdateCallback? onUpdate;
  final GestureDragEndCallback? onEnd;
  final GestureDragCancelCallback? onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.opaque,
    gestures: {
      _GrabRecognizer: GestureRecognizerFactoryWithHandlers<_GrabRecognizer>(
        () => _GrabRecognizer(debugOwner: this),
        (recognizer) => recognizer
          ..dragStartBehavior = DragStartBehavior.down
          ..onStart = onStart
          ..onUpdate = onUpdate
          ..onEnd = onEnd
          ..onCancel = onCancel,
      ),
    },
    child: child,
  );
}

/// A pan that wins the arena on the first move.
class _GrabRecognizer extends PanGestureRecognizer {
  _GrabRecognizer({super.debugOwner});

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) => true;
}
