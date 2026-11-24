/// @docImport 'package:motor_widgets/src/drag/motion_drag_to_scroll.dart';
/// @docImport 'package:motor_widgets/src/reorder/motion_reorderable.dart';
library;

/// The point of a drag that a [MotionReorderable] places the drop by, and
/// that a [MotionDragToScroll] scrolls by.
enum MotionDragPoint {
  /// The pointer: the finger on a touch screen.
  pointer,

  /// The center of the feedback as it is painted: where the card is, also
  /// when it was grabbed near an edge.
  feedbackCenter,
}
