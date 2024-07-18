import 'dart:ui';

import 'package:material_color_utilities/material_color_utilities.dart';

/// Tools for working with colors in HCT space.
extension HctTools on Color {
  /// Linearly interpolates between two colors in HCT space.
  ///
  /// HCT interpolation is useful for finding a color between two colors that
  /// are not in the same hue, but share an equally spaced chroma and tone.
  ///
  /// The t parameter is the amount to interpolate between the two values where
  /// 0.0 is the first color and 1.0 is the second color.
  static Color? lerpBlend(Color? a, Color? b, double t) {
    if (a == null) {
      if (b == null) {
        return null;
      }
      return b.withOpacity(1.0 - t);
    }
    if (b == null) {
      return a.withOpacity(t);
    }

    final aHct = a.toHct();
    final bHct = b.toHct();

    final result = Hct.from(
      lerpDouble(aHct.hue, bHct.hue, t)!,
      lerpDouble(aHct.chroma, bHct.chroma, t)!,
      lerpDouble(aHct.tone, bHct.tone, t)!,
    );

    return Color(result.toInt()).withOpacity(
      lerpDouble(a.opacity, b.opacity, t)!,
    );
  }

  /// Shifts the hue of this color towards [other] in a way that is still
  /// recognizable but matches the original color more closely.
  ///
  /// Keeps [opacity] the same.
  Color harmonizeWith(Color other) {
    return Color(Blend.harmonize(value, other.value)).withOpacity(opacity);
  }

  /// Converts this color to its HCT representation.
  Hct toHct() => Hct.fromInt(value);
}
