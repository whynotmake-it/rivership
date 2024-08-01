import 'package:flutter/services.dart';

/// Extension methods for the [Brightness] enum.
extension BrightnessTools on Brightness {
  /// Returns the inverse of the brightness.
  ///
  /// If the brightness is [Brightness.light], it returns [Brightness.dark].
  /// If the brightness is [Brightness.dark], it returns [Brightness.light].
  Brightness get inverse =>
      this == Brightness.light ? Brightness.dark : Brightness.light;

  /// Returns the [SystemUiOverlayStyle] that matches the brightness.
  ///
  /// If the brightness is [Brightness.light], it returns
  /// [SystemUiOverlayStyle.light].
  /// If the brightness is [Brightness.dark], it returns
  /// [SystemUiOverlayStyle.dark].
  ///
  /// See also:
  /// * [inverseOverlayStyle] for the inverse [SystemUiOverlayStyle].
  SystemUiOverlayStyle get matchingOverlayStyle => this == Brightness.light
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;

  /// Similar to [matchingOverlayStyle] but returns the opposite.
  SystemUiOverlayStyle get inverseOverlayStyle => inverse.matchingOverlayStyle;
}
