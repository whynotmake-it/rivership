import 'dart:ui';

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';

/// Archivo at a given weight and width. Both are variable-font axes, so they
/// are set as variations as well as [FontWeight].
TextStyle archivo(
  double size, {
  double weight = 400,
  double width = 100,
  double? height,
  double spacing = 0,
  Color? color,
}) => TextStyle(
  fontFamily: 'Archivo',
  fontSize: size,
  fontWeight: FontWeight.lerp(
    FontWeight.w100,
    FontWeight.w900,
    ((weight - 100) / 800).clamp(0, 1),
  ),
  fontVariations: [FontVariation.weight(weight), FontVariation.width(width)],
  height: height,
  letterSpacing: spacing,
  color: color,
);

/// The example's type scale, resolved against the current palette.
extension TypeScaleTools on ExampleTheme {
  /// Big, light, slightly expanded headlines.
  TextStyle get display => archivo(
    44,
    weight: 260,
    width: 112,
    height: 1.02,
    spacing: -1.6,
    color: textPrimary,
  );

  /// Card and section titles.
  TextStyle get title => archivo(
    19,
    weight: 480,
    width: 104,
    height: 1.2,
    spacing: -.3,
    color: textPrimary,
  );

  /// Body copy.
  TextStyle get body =>
      archivo(15.5, height: 1.45, spacing: -.1, color: textSecondary);

  /// Small print and labels.
  TextStyle get caption =>
      archivo(12.5, weight: 460, height: 1.3, color: textTertiary);

  /// Tiny uppercase labels.
  TextStyle get eyebrow =>
      archivo(10.5, weight: 640, width: 118, spacing: 1.6, color: textTertiary);

  /// Code and numbers.
  TextStyle get code => TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 12.5,
    height: 1.4,
    fontVariations: const [FontVariation.weight(440)],
    color: textSecondary,
  );
}

/// Accent colors for tracks and lanes, taken from the spectrum.
const trackColors = [
  ExampleTheme.signalBlue,
  ExampleTheme.spectrumRed,
  ExampleTheme.marigold,
  ExampleTheme.roseQuartz,
];

/// Blurs [child] by [sigma] on each axis. Skips the filter when it is too
/// small to see.
class Blur extends StatelessWidget {
  const Blur({required this.sigma, required this.child, super.key});

  /// Horizontal and vertical blur sigma.
  final Offset sigma;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (sigma.dx < .05 && sigma.dy < .05) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: sigma.dx,
        sigmaY: sigma.dy,
        tileMode: TileMode.decal,
      ),
      child: child,
    );
  }
}

/// Fades [child] in, lifts it by [offset] and sharpens it as [progress] goes
/// from 0 to 1.
class Reveal extends StatelessWidget {
  const Reveal({
    required this.progress,
    required this.child,
    this.offset = const Offset(0, 14),
    this.blur = 8,
    super.key,
  });

  final double progress;
  final Offset offset;
  final double blur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hidden = 1 - progress.clamp(0.0, 1.0);
    return Opacity(
      opacity: 1 - hidden,
      child: Transform.translate(
        offset: offset * (1 - progress),
        child: Blur(sigma: Offset(hidden, hidden) * blur, child: child),
      ),
    );
  }
}

/// Motion blur for something moving at [velocity] pixels per second.
Offset motionBlur(Offset velocity, {double strength = .0035, double max = 8}) =>
    Offset(
      (velocity.dx.abs() * strength).clamp(0, max),
      (velocity.dy.abs() * strength).clamp(0, max),
    );
