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
      return b.withValues(alpha: 1.0 - t);
    }
    if (b == null) {
      return a.withValues(alpha: t);
    }

    final aHct = a.toHct();
    final bHct = b.toHct();

    final result = Hct.from(
      lerpDouble(aHct.hue, bHct.hue, t)!,
      lerpDouble(aHct.chroma, bHct.chroma, t)!,
      lerpDouble(aHct.tone, bHct.tone, t)!,
    );

    return Color(result.toInt()).withValues(alpha: lerpDouble(a.a, b.a, t));
  }

  /// Shifts the hue of this color towards [other] in a way that is still
  /// recognizable but matches the original color more closely.
  ///
  /// Keeps [a] the same.
  Color harmonizeWith(Color other) {
    // ignore: deprecated_member_use
    return Color(Blend.harmonize(value, other.value)).withValues(alpha: a);
  }

  /// Converts this color to its HCT representation.
  // ignore: deprecated_member_use
  Hct toHct() => Hct.fromInt(value);
}

/// Tools for working with HCT colors.
extension HctToolsHct on Hct {
  /// Converts this [Hct] to a [Color].
  Color toColor() => Color(toInt());
}
