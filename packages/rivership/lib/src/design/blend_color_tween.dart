import 'package:flutter/widgets.dart' show Color, ColorTween;
import 'package:material_color_utilities/hct/hct.dart' show Hct;
import 'package:rivership/src/extensions/hct_tools.dart';

/// A [ColorTween] that blends in [Hct] colorspace.
class BlendColorTween extends ColorTween {
  /// Creates a [BlendColorTween].
  BlendColorTween({
    required Color begin,
    required Color end,
  }) : super(begin: begin, end: end);

  @override
  Color lerp(double t) {
    return HctTools.lerpBlend(begin, end, t)!;
  }
}
