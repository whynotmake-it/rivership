import 'package:meta/meta.dart';
import 'package:motor/src/motion.dart';

/// A motion as an `Equatable` prop.
///
/// `Equatable` also compares the runtime types of props, but motions of
/// different classes are equal when they move the same. This compares with
/// the motion's own `==` instead.
@internal
@immutable
final class MotionProp {
  /// Wraps [motion].
  const MotionProp(this.motion);

  /// The wrapped motion.
  final MotionBase motion;

  /// Wraps each of [motions], or returns null without any.
  static List<MotionProp>? all(List<MotionBase>? motions) => motions == null
      ? null
      : [for (final motion in motions) MotionProp(motion)];

  @override
  bool operator ==(Object other) =>
      other is MotionProp && motion == other.motion;

  @override
  int get hashCode => motion.hashCode;
}
