/// @docImport 'package:coil/thinking.dart';
library;

import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Where the highlight of a [CoilShimmer] is, from 0 (past the end) to 1
/// (before the start).
final _sweep = Track<double>(
  .single,
  initial: 0,
  debugLabel: 'CoilShimmer.sweep',
);

/// The value a [CoilPulse] builds with, from 0 to 1.
final _swing = Track<double>(
  .single,
  initial: 1,
  debugLabel: 'CoilPulse.swing',
);

bool _reducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Sweeps a highlight across [child] while [active]: the look of work in
/// progress, such as a running step's title in [CoilThinkingSteps] or a
/// chat's "Thinking…" line.
///
/// The child is painted in its own colors with a band of [highlight]
/// (the theme's foreground by default) passing over it every [period]. It
/// suits text and glyphs; on a filled shape the band covers the fill.
///
/// It plays on Motor, so a [TickerRateScope] above it sets its frame rate.
/// Under reduced motion, or when not [active], the child shows as it is, so
/// the words must say the status on their own ("Searching…", not a bare
/// "Search").
class CoilShimmer extends StatelessWidget {
  /// Creates a shimmer around [child].
  const CoilShimmer({
    required this.child,
    super.key,
    this.active = true,
    this.highlight,
    this.period = const Duration(milliseconds: 2200),
  });

  /// What the highlight passes over, usually a [Text].
  final Widget child;

  /// Whether the highlight sweeps.
  final bool active;

  /// The highlight's color. Defaults to [CoilColors.foreground].
  final Color? highlight;

  /// How long one pass takes.
  final Duration period;

  @override
  Widget build(BuildContext context) {
    final sweeping = active && !_reducedMotion(context);
    final light = highlight ?? CoilTheme.of(context).colors.foreground;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return TrackBuilder(
      debugLabel: 'CoilShimmer',
      animations: [
        if (sweeping)
          _sweep([
            .loop([
              .to(1, motion: CurvedMotion(period)),
              const .to(0, motion: .instant()),
            ]),
          ], from: 0)
        else
          _sweep(const [.to(0, motion: .instant())]),
      ],
      builder: (context, value, child) {
        if (!sweeping) return child!;
        final t = value(_sweep).clamp(0.0, 1.0);
        return ShaderMask(
          // Keeps the child's own colors and lays the band over them.
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // The band travels from past the end to before the start, so
            // each pass starts and ends on the plain child. Its width
            // follows the child within limits, so short and long labels
            // read alike.
            final band = bounds.width.clamp(48.0, 200.0);
            final along = rtl ? t : 1 - t;
            final x = bounds.left + (bounds.width + band) * along - band;
            return LinearGradient(
              colors: [
                light.withValues(alpha: 0),
                light,
                light.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromLTWH(x, bounds.top, band, bounds.height));
          },
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Builds [builder] with a value that swings 1 → 0 → 1 every two
/// [halfPeriod]s, eased, while [active]: a breathing glyph, such as a
/// running step's dot in [CoilThinkingSteps].
///
/// It plays on Motor, so a [TickerRateScope] above it sets its frame rate.
/// Inactive, or under reduced motion, the value rests at 1 and nothing
/// ticks.
class CoilPulse extends StatelessWidget {
  /// Creates a pulse.
  const CoilPulse({
    required this.builder,
    super.key,
    this.active = true,
    this.halfPeriod = const Duration(milliseconds: 650),
  });

  /// Builds the pulsing content from the current value, 0 to 1.
  final Widget Function(BuildContext context, double value) builder;

  /// Whether it pulses.
  final bool active;

  /// How long one swing, 1 → 0 or back, takes.
  final Duration halfPeriod;

  @override
  Widget build(BuildContext context) {
    final pulsing = active && !_reducedMotion(context);
    final swing = CurvedMotion(halfPeriod, Curves.easeInOut);
    return TrackBuilder(
      debugLabel: 'CoilPulse',
      animations: [
        if (pulsing)
          _swing([
            .loop([.to(0, motion: swing), .to(1, motion: swing)]),
          ], from: 1)
        else
          _swing(const [.to(1, motion: .instant())]),
      ],
      builder: (context, value, _) =>
          builder(context, value(_swing).clamp(0.0, 1.0)),
    );
  }
}
