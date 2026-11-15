import 'package:coil/foundation.dart';
import 'package:coil/src/components/carousel_dots/carousel_dots.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilCarouselDots]. Use them as keys of
/// [CoilCarouselDots.motions] or [CoilThemeData.trackMotions].
final class CoilCarouselDotsTrack<T extends Object> extends Track<T> {
  CoilCarouselDotsTrack._(super.converter, {required String super.debugLabel});

  /// The width of the current dot's pill. Default motion: `standard`.
  static final pill = CoilCarouselDotsTrack<double>._(
    .single,
    debugLabel: 'CoilCarouselDots.pill',
  );

  /// The hover highlight gliding between dots. Default motion: `quick`.
  static final highlight = CoilCarouselDotsTrack<Rect>._(
    .rect,
    debugLabel: 'CoilCarouselDots.highlight',
  );
}
