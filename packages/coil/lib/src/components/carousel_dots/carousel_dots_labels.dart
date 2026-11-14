import 'package:flutter/foundation.dart';

/// Formats a slide position for screen readers, from the slide's 1-based
/// [number] and the [count] of slides.
typedef CoilSlidePositionFormatter = String Function(int number, int count);

/// The words `CoilCarouselDots` speaks to screen readers. Pass translations
/// for other locales.
@immutable
class CoilCarouselDotsLabels {
  /// Creates the labels.
  const CoilCarouselDotsLabels({
    this.slidesLabel = 'Slides',
    this.positionLabel = _englishPosition,
  });

  static String _englishPosition(int number, int count) =>
      'Slide $number of $count';

  /// The control's name, announced before the position.
  final String slidesLabel;

  /// The current position, such as "Slide 2 of 5", and the positions one
  /// step either side.
  final CoilSlidePositionFormatter positionLabel;

  @override
  bool operator ==(Object other) =>
      other is CoilCarouselDotsLabels &&
      other.slidesLabel == slidesLabel &&
      other.positionLabel == positionLabel;

  @override
  int get hashCode => Object.hash(slidesLabel, positionLabel);
}
