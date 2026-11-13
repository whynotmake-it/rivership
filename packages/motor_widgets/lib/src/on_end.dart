import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Turns an `onEnd` callback into a status listener that calls it whenever
/// the motion has settled.
ValueChanged<AnimationStatus>? onEndListener(VoidCallback? onEnd) =>
    onEnd == null
    ? null
    : (AnimationStatus status) {
        if (!status.isAnimating) onEnd();
      };
