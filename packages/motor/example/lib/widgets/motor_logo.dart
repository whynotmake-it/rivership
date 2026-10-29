import 'package:example_design/example_design.dart' show LogoGlyph;
import 'package:flutter/cupertino.dart';
import 'package:motor_example/widgets/style.dart';

/// The motor logo: the ball and motion arc of the rivership package logos, in
/// the accent color. [size] is its height.
class MotorLogo extends StatelessWidget {
  const MotorLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) =>
      LogoGlyph(color: Palette.of(context).accent, size: size);
}
