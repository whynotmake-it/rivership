import 'package:motor_widgets/src/drag/motion_draggable.dart';

/// The point of a [MotionDraggable]'s drag that a drop zone or an edge
/// scroll reacts to.
enum MotionDragProbe {
  /// The pointer: the finger on a touch screen.
  pointer,

  /// The center of the feedback as it is painted: where the card is, also
  /// when it was grabbed near an edge.
  feedbackCenter,
}
