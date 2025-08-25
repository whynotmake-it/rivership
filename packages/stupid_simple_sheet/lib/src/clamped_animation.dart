import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

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
