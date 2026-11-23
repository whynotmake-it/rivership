import 'dart:ui';

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

/// The colors the demos draw with, read from the coil theme so they follow
/// light and dark, high contrast and any brand an app gives coil.
///
/// coil spends color only on meaning, and so do the demos: the thing in
/// motion is [text] on a neutral stage, and [accent] (coil's brand) marks
/// the one thing a demo wants you to watch, such as a spring's trace.
@immutable
class Palette {
  const Palette._({
    required this.canvas,
    required this.surface,
    required this.inset,
    required this.control,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
  });

  /// The palette for [colors].
  factory Palette.from(CoilColors colors) => Palette._(
    canvas: colors.background,
    surface: colors.surface(4),
    inset: colors.surface(3),
    control: colors.muted,
    border: colors.border,
    borderStrong: colors.foreground.withValues(alpha: 0.2),
    text: colors.foreground,
    textSecondary: colors.mutedForeground,
    textTertiary: colors.mutedForeground.withValues(alpha: 0.7),
    accent: colors.brand,
    onAccent: const Color(0xFFFFFFFF),
    accentSoft: colors.brand.withValues(alpha: 0.16),
  );

  /// The page behind the stages.
  final Color canvas;

  /// Things placed on a stage: cards, panels, a phone's screen.
  final Color surface;

  /// The stage a demo plays on.
  final Color inset;

  /// Resting fill of neutral shapes, such as an empty track.
  final Color control;

  /// Hairlines.
  final Color border;

  /// Hairlines that need to stand out from [border].
  final Color borderStrong;

  /// Text, and the thing in motion.
  final Color text;

  /// Secondary text.
  final Color textSecondary;

  /// Labels and axes that sit back.
  final Color textTertiary;

  /// coil's brand color: the one thing a demo wants you to watch.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// A quiet tint of [accent].
  final Color accentSoft;

  /// The palette at [context].
  static Palette of(BuildContext context) =>
      Palette.from(CoilTheme.of(context).colors);
}

/// A strong ease-out, for things that enter or respond.
const easeOut = Cubic(.23, 1, .32, 1);

/// JetBrains Mono, for code, numbers on a live readout and timeline lanes.
TextStyle mono(
  double size, {
  double weight = 440,
  double spacing = 0,
  double? height,
  Color? color,
}) => TextStyle(
  fontFamily: 'JetBrains Mono',
  fontSize: size,
  fontWeight: FontWeight(weight.round()),
  fontVariations: [FontVariation.weight(weight)],
  letterSpacing: spacing,
  height: height,
  color: color,
);

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
        tileMode: .decal,
      ),
      child: child,
    );
  }
}

/// Fades [child] in and moves it by [offset] as [progress] goes from 0 to 1.
/// A light [blur] blends the in-between frames of a crossfade.
class Reveal extends StatelessWidget {
  const Reveal({
    required this.progress,
    required this.child,
    this.offset = const Offset(0, 6),
    this.blur = 2,
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
        offset: offset * hidden,
        child: Blur(sigma: Offset(hidden, hidden) * blur, child: child),
      ),
    );
  }
}

/// Motion blur for something moving at [velocity] pixels per second.
Offset motionBlur(Offset velocity) => Offset(
  (velocity.dx.abs() * .002).clamp(0, 4),
  (velocity.dy.abs() * .002).clamp(0, 4),
);
