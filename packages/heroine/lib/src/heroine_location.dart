part of 'heroines.dart';

/// Represents the location and rotation of a heroine widget.
class HeroineLocation extends Equatable {
  /// Creates a new [HeroineLocation].
  const HeroineLocation({
    required this.boundingBox,
    this.rotation = 0.0,
  });

  /// Creates a new [HeroineLocation] from velocity components.
  const HeroineLocation.velocity({
    required Offset centerPixelsPerSecond,
    required Size sizePixelsPerSecond,
    required double degPerSecond,
  }) : this(
          boundingBox: centerPixelsPerSecond & sizePixelsPerSecond,
          rotation: degPerSecond,
        );

  /// Provides backward compatibility with [HeroineVelocity].
  HeroineLocation._velocity(Velocity velocity)
      : this(
          boundingBox: Rect.fromLTWH(
            velocity.pixelsPerSecond.dx,
            velocity.pixelsPerSecond.dy,
            0,
            0,
          ),
        );

  /// The rectangle of the widget in global coordinates.
  final Rect boundingBox;

  /// The rotation of the widget in radians.
  final double rotation;

  /// Whether this position is valid.
  bool get isValid =>
      boundingBox.isFinite && !boundingBox.isEmpty && rotation.isFinite;

  @override
  List<Object?> get props => [boundingBox, rotation];
}

class _HeroineLocationConverter extends MotionConverter<HeroineLocation> {
  @override
  List<double> normalize(HeroineLocation value) {
    final rect = const RectMotionConverter().normalize(value.boundingBox);
    return [
      ...rect,
      value.rotation,
    ];
  }

  @override
  HeroineLocation denormalize(List<double> values) {
    final rect = const RectMotionConverter().denormalize(values.sublist(0, 4));
    final rotation = values[4];
    return HeroineLocation(
      boundingBox: rect,
      rotation: rotation,
    );
  }
}
