import 'package:flutter/animation.dart';
import 'package:meta/meta.dart';

@internal
class ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  ClampedAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);
}

@internal
extension ClampedAnimationX on Animation<double> {
  Animation<double> get clamped => ClampedAnimation(this);
}

@internal
class RemappedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  RemappedAnimation(
    this.parent, {
    this.start = 0.0,
    this.end = 1.0,
  });

  @override
  final Animation<double> parent;

  final double start;

  final double end;

  @override
  double get value => Interval(start, end).transform(parent.value);
}

@internal
extension RemappedAnimationX on Animation<double> {
  Animation<double> remapped({
    double start = 0.0,
    double end = 1.0,
  }) =>
      RemappedAnimation(this, start: start, end: end);
}
