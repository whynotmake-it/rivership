import 'package:coil/coil.dart';
import 'package:example_design/example_design.dart' show LogoGlyph;
import 'package:flutter/widgets.dart';

/// The motor logo: the ball and motion arc of the rivership package logos,
/// in coil's brand color. [size] is its height.
class MotorLogo extends StatelessWidget {
  const MotorLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) =>
      LogoGlyph(color: CoilTheme.of(context).colors.brand, size: size);
}
