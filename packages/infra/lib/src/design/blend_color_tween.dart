import 'package:flutter/widgets.dart';
import 'package:infra/src/extensions/hct_tools.dart';

class BlendColorTween extends ColorTween {
  BlendColorTween({
    required Color begin,
    required Color end,
  }) : super(begin: begin, end: end);

  @override
  Color lerp(double t) {
    return HctTools.lerpBlend(begin, end, t)!;
  }
}
