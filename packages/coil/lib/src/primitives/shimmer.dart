/// @docImport 'package:coil/thinking.dart';
library;

import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Sweeps a highlight across [child] while [active]: the look of work in
/// progress, such as a running step's title in [CoilThinkingSteps] or a
/// chat's "Thinking…" line.
///
/// The child is painted in its own colors with a band of [highlight]
/// (the theme's foreground by default) passing over it every [period]. It
/// suits text and glyphs; on a filled shape the band covers the fill.
///
/// Under reduced motion, or when not [active], the child shows as it is, so
/// the words must say the status on their own ("Searching…", not a bare
/// "Search").
class CoilShimmer extends StatefulWidget {
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
  State<CoilShimmer> createState() => _CoilShimmerState();
}

class _CoilShimmerState extends State<CoilShimmer>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(vsync: this, duration: widget.period);

  bool get _running =>
      widget.active && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    _sweep.duration = widget.period;
    if (_running && !_sweep.isAnimating) {
      unawaited(_sweep.repeat());
    } else if (!_running && _sweep.isAnimating) {
      _sweep.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CoilShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_running) return widget.child;
    final light = widget.highlight ?? CoilTheme.of(context).colors.foreground;
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, child) => ShaderMask(
        // Keeps the child's own colors and lays the band over them.
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          // The band travels from past the end to before the start, so each
          // pass starts and ends on the plain child. Its width follows the
          // child within limits, so short and long labels read alike.
          final band = bounds.width.clamp(48.0, 200.0);
          final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
          final t = rtl ? _sweep.value : 1 - _sweep.value;
          final x = bounds.left + (bounds.width + band) * t - band;
          return LinearGradient(
            colors: [
              light.withValues(alpha: 0),
              light,
              light.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(x, bounds.top, band, bounds.height));
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Builds [builder] with a value that swings 0 → 1 → 0 every two
/// [halfPeriod]s, eased, while [active]: a breathing glyph, such as a running
/// step's dot in [CoilThinkingSteps].
///
/// Inactive, or under reduced motion, the value rests at 1 and nothing ticks.
class CoilPulse extends StatefulWidget {
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

  /// How long one swing, 0 → 1 or back, takes.
  final Duration halfPeriod;

  @override
  State<CoilPulse> createState() => _CoilPulseState();
}

class _CoilPulseState extends State<CoilPulse>
    with SingleTickerProviderStateMixin {
  late final _swing = AnimationController(
    vsync: this,
    duration: widget.halfPeriod,
    value: 1,
  );

  bool get _running =>
      widget.active && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    _swing.duration = widget.halfPeriod;
    if (_running && !_swing.isAnimating) {
      unawaited(_swing.repeat(reverse: true));
    } else if (!_running && _swing.isAnimating) {
      _swing
        ..stop()
        ..value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CoilPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _swing,
    builder: (context, _) => widget.builder(
      context,
      _running ? Curves.easeInOut.transform(_swing.value) : 1,
    ),
  );
}
