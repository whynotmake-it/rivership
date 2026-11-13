import 'package:coil/foundation.dart';
import 'package:coil/src/components/skeleton/skeleton_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilSkeleton].
final class CoilSkeletonTrack<T extends Object> extends Track<T> {
  CoilSkeletonTrack._(
    super.converter, {
    required String super.debugLabel,
    super.initial,
  });

  /// The fade-in after the grace period (default motion: `fade`).
  static final appear = CoilSkeletonTrack<double>._(
    .single,
    initial: 0,
    debugLabel: 'CoilSkeleton.appear',
  );

  /// The opacity pulse. Each leg runs on this motion; the default takes 1 s.
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
  }) : _text = false,
       widthFactor = null;

  /// A line of text: one body line box tall with a pill bar inside it, which
  /// takes [widthFactor] of the width the parent gives (give it a tight
  /// width, as a stretched column does).
  const CoilSkeleton.text({
    super.key,
    this.widthFactor,
    this.size,
    this.motion,
    this.motions,
    this.style,
  }) : _text = true,
       width = null,
       height = null;

  /// The block's width.
  final double? width;

  /// The block's height.
  final double? height;

  final bool _text;

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

  /// A radius larger than any bar, which clamps to a full pill.
  static const _fullRadius = 1000.0;

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

    final Widget block;
    if (_text) {
      // One real line box fixes the height, so N lines are as tall as N
      // lines of text at any scale and font. The bar sits inside it.
      block = Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          Opacity(
            opacity: 0,
            child: Text(
              ' ',
              maxLines: 1,
              style: theme.typography.style(sizes.body),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              widthFactor: widthFactor ?? 1,
              heightFactor: look.textHeightFactor,
              alignment: AlignmentDirectional.centerStart,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: look.fill,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(_fullRadius),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      block = DecoratedBox(
        decoration: ShapeDecoration(
          color: look.fill,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(look.radius!),
          ),
        ),
        child: SizedBox(width: width, height: height),
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
/// the shortest. [lines] skeletons are as tall as [lines] lines of text.
class CoilSkeletonText extends StatelessWidget {
  /// Creates [lines] text lines.
  const CoilSkeletonText({
    super.key,
    this.lines = 3,
    this.size,
    this.motion,
    this.motions,
    this.style,
  }) : assert(lines > 0, 'A skeleton has at least one line');

  /// The number of lines.
  final int lines;

  /// Pins the size step the lines are sized for.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Overrides single tracks' motions.
  final Map<CoilSkeletonTrack<Object>, Motion>? motions;

  /// Overrides for the lines' look.
  final CoilSkeletonStyle? style;

  static const _factors = [0.82, 0.7, 0.76, 0.64];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < lines; i++)
        CoilSkeleton.text(
          widthFactor: i == lines - 1 && lines > 1
              ? 0.55
              : _factors[i % _factors.length],
          size: size,
          motion: motion,
          motions: motions,
          style: style,
        ),
    ],
  );
}

/// Marks the region that is loading: announced once as "Loading" to
/// assistive technology, while the skeletons inside stay out of the
/// semantics tree.
class CoilSkeletonRegion extends StatelessWidget {
  /// Creates a loading region.
  const CoilSkeletonRegion({
    required this.label,
    required this.child,
    super.key,
  });

  /// The announced label, for example "Loading" in the app's language.
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
