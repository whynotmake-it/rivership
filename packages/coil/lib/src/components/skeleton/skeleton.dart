import 'package:coil/foundation.dart';
import 'package:coil/src/components/skeleton/skeleton_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilSkeleton].
final class CoilSkeletonTrack<T extends Object> extends Track<T> {
  CoilSkeletonTrack._(super.converter, {super.initial, super.debugLabel});

  /// The fade-in after the grace period (default motion: `fade`).
  static final appear = CoilSkeletonTrack<double>._(
    .single,
    initial: 0,
    debugLabel: 'CoilSkeleton.appear',
  );

  /// One leg of the pulse, 1 → 0.5 → 1 (default: a 1 s ease; loops).
  static final pulse = CoilSkeletonTrack<double>._(
    .single,
    initial: 1,
    debugLabel: 'CoilSkeleton.pulse',
  );
}

/// A loading placeholder block.
///
/// It waits [grace] (160 ms), so content that arrives at once never flashes
/// a placeholder, fades in on `fade`, then pulses its opacity 1 → 0.5 → 1
/// every 2 s. Reduced motion keeps the grace and the fade and drops the
/// pulse. Skeletons are excluded from semantics: wrap the loading region in
/// [CoilSkeletonRegion].
///
/// Match the final layout's line count and widths, and don't shimmer.
class CoilSkeleton extends StatelessWidget {
  /// A block of [width] × [height] (either may be null to fill the space
  /// the parent gives).
  const CoilSkeleton({
    super.key,
    this.width,
    this.height,
    this.size,
    this.motion,
    this.motions,
    this.style,
  }) : text = false,
       widthFactor = null;

  /// A line of text: [widthFactor] of the available width, 0.6 of a body
  /// line box high, with full-pill corners.
  const CoilSkeleton.text({
    super.key,
    this.width,
    this.widthFactor,
    this.size,
    this.motion,
    this.motions,
    this.style,
  }) : text = true,
       height = null;

  /// The block's width.
  final double? width;

  /// The block's height.
  final double? height;

  /// Whether this is a text line.
  final bool text;

  /// The fraction of the available width a text line takes.
  final double? widthFactor;

  /// Pins the size step the text line is sized for.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Overrides single tracks' motions.
  final Map<CoilSkeletonTrack<Object>, Motion>? motions;

  /// Overrides for this skeleton's look.
  final CoilSkeletonStyle? style;

  /// How long a skeleton waits before it appears.
  static const grace = Duration(milliseconds: 160);

  static const _pulseCurve = CurvedMotion(
    Duration(seconds: 1),
    Cubic(0.4, 0, 0.6, 1),
  );

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final look = CoilSkeletonStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilSkeletonStyle>(context)).merge(style);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final appearMotion = CoilTheme.trackMotionOf(
      context,
      CoilSkeletonTrack.appear,
      instance: motions,
      token: tokens.fade,
      spatial: false,
    );
    final pulseMotion = CoilTheme.trackMotionOf(
      context,
      CoilSkeletonTrack.pulse,
      instance: motions,
      token: _pulseCurve,
      spatial: false,
    );
    final pulsing = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    final blockHeight = text
        ? MediaQuery.textScalerOf(context).scale(sizes.body.lineHeight) *
              look.textHeightFactor!
        : height;
    final radius = text ? (blockHeight! / 2) : look.radius!;

    Widget block = DecoratedBox(
      decoration: ShapeDecoration(
        color: look.fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: SizedBox(width: text ? null : width, height: blockHeight),
    );
    if (text) {
      block = FractionallySizedBox(
        widthFactor: widthFactor ?? 1,
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(width: width, child: block),
      );
    }

    return ExcludeSemantics(
      child: TrackBuilder(
        animations: [
          CoilSkeletonTrack.appear([
            .to(1, motion: appearMotion),
          ], delay: grace),
        ],
        builder: (context, value, _) => Opacity(
          opacity: value(CoilSkeletonTrack.appear).clamp(0, 1),
          child: pulsing
              ? TrackBuilder(
                  loop: LoopMode.loop,
                  animations: [
                    CoilSkeletonTrack.pulse([
                      .to(0.5, motion: pulseMotion),
                      .to(1, motion: pulseMotion),
                    ], from: 1),
                  ],
                  builder: (context, value, child) => Opacity(
                    opacity: value(CoilSkeletonTrack.pulse).clamp(0, 1),
                    child: child,
                  ),
                  child: block,
                )
              : block,
        ),
      ),
    );
  }
}

/// A column of text-line skeletons with the varied widths of real text:
/// each line takes between 55 % and 82 % of the width, and the last line is
/// the shortest.
class CoilSkeletonText extends StatelessWidget {
  /// Creates [lines] text lines.
  const CoilSkeletonText({
    super.key,
    this.lines = 3,
    this.size,
    this.motion,
    this.style,
  }) : assert(lines > 0, 'A skeleton has at least one line');

  /// The number of lines.
  final int lines;

  /// Pins the size step the lines are sized for.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Overrides for the lines' look.
  final CoilSkeletonStyle? style;

  static const _factors = [0.82, 0.7, 0.76, 0.64];

  @override
  Widget build(BuildContext context) {
    final sizes = CoilTheme.metricsOf(context, size: size);
    return Column(
      spacing: sizes.body.lineHeight * 0.4,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++)
          CoilSkeleton.text(
            widthFactor: i == lines - 1 && lines > 1
                ? 0.55
                : _factors[i % _factors.length],
            size: size,
            motion: motion,
            style: style,
          ),
      ],
    );
  }
}

/// Marks the region that is loading: announced once as "Loading" to
/// assistive technology, while the skeletons inside stay out of the
/// semantics tree.
class CoilSkeletonRegion extends StatelessWidget {
  /// Creates a loading region.
  const CoilSkeletonRegion({
    required this.child,
    super.key,
    this.label = 'Loading',
  });

  /// The announced label.
  final String label;

  /// The skeletons.
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    liveRegion: true,
    child: child,
  );
}
