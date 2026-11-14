import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/skeleton/skeleton_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

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

  /// The cross-fade of a [CoilSkeletonSwitcher] between skeleton and
  /// content (default motion: `fade` in, `fadeExit` out). Set it to
  /// `Motion.instant()` to swap without a fade.
  static final swap = CoilSkeletonTrack<double>._(
    .single,
    initial: 1,
    debugLabel: 'CoilSkeleton.swap',
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
/// To switch between skeletons and the loaded content, use
/// [CoilSkeletonSwitcher]: it cross-fades the two, and skeletons that replace
/// content on screen show at once instead of waiting out the grace period.
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
    final takesOver = _SkeletonTakeover.of(context);

    final Widget block;
    if (_text) {
      // One real line box fixes the height, so N lines are as tall as N
      // lines of text at any scale and font.
      block = Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          CoilLineBox(
            style: theme.typography.style(sizes.body),
            child: const SizedBox.shrink(),
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
          // Taking over from content, there is nothing to wait for: waiting
          // would leave the space empty.
          if (takesOver)
            CoilSkeletonTrack.appear([.to(1, motion: appearMotion)], from: 1)
          else
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
    required this.semanticLabel,
    required this.child,
    super.key,
  });

  /// What screen readers announce, for example "Loading" in the app's
  /// language.
  final String semanticLabel;

  /// The skeletons.
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    liveRegion: true,
    child: child,
  );
}

/// Switches between [skeleton] while [loading] and [child] once loaded.
///
/// The two cross-fade in one stack, on the [CoilSkeletonTrack.swap] track
/// (`fade` in, `fadeExit` out), so the space is never empty. Skeletons shown
/// first still wait out [CoilSkeleton.grace]; content that arrives sooner
/// replaces them before they ever show. Skeletons that replace content show
/// at once. Opt out of the fade with `motions: {.swap: const .instant()}`.
///
/// ```dart
/// CoilSkeletonSwitcher(
///   loading: profile == null,
///   skeleton: CoilSkeletonRegion(
///     semanticLabel: 'Loading',
///     child: ProfileSkeleton(),
///   ),
///   child: Profile(profile),
/// )
/// ```
class CoilSkeletonSwitcher extends StatefulWidget {
  /// Creates a skeleton switcher.
  const CoilSkeletonSwitcher({
    required this.loading,
    required this.skeleton,
    required this.child,
    super.key,
    this.motion,
    this.motions,
  });

  /// Whether to show [skeleton] instead of [child].
  final bool loading;

  /// The placeholder: skeletons in a [CoilSkeletonRegion].
  final Widget skeleton;

  /// The loaded content.
  final Widget child;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Overrides single tracks' motions; only [CoilSkeletonTrack.swap] applies
  /// here.
  final Map<CoilSkeletonTrack<Object>, Motion>? motions;

  @override
  State<CoilSkeletonSwitcher> createState() => _CoilSkeletonSwitcherState();
}

class _CoilSkeletonSwitcherState extends State<CoilSkeletonSwitcher> {
  /// Whether content has been on screen, so skeletons now replace it.
  bool _contentShown = false;

  @override
  void initState() {
    super.initState();
    _contentShown = !widget.loading;
  }

  @override
  void didUpdateWidget(CoilSkeletonSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.loading) _contentShown = true;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    Motion swap(Motion token) => CoilTheme.trackMotionOf(
      context,
      CoilSkeletonTrack.swap,
      instance: widget.motions,
      token: token,
      spatial: false,
    );
    return MotionSwitcher(
      motion: swap(tokens.fade),
      exitMotion: swap(tokens.fadeExit),
      debugLabel: 'CoilSkeletonSwitcher',
      // Both share one cell, the newest on top. The leaving one is out of
      // reach and out of the semantics tree.
      layoutBuilder: (current, previous) => Stack(
        children: [
          for (final child in previous)
            IgnorePointer(child: ExcludeSemantics(child: child)),
          ?current,
        ],
      ),
      child: widget.loading
          ? KeyedSubtree(
              key: const ValueKey(true),
              child: _SkeletonTakeover(
                takesOver: _contentShown,
                child: widget.skeleton,
              ),
            )
          : KeyedSubtree(key: const ValueKey(false), child: widget.child),
    );
  }
}

/// Tells the skeletons below whether they replace content on screen.
class _SkeletonTakeover extends InheritedWidget {
  const _SkeletonTakeover({required this.takesOver, required super.child});

  final bool takesOver;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SkeletonTakeover>()
          ?.takesOver ??
      false;

  @override
  bool updateShouldNotify(_SkeletonTakeover oldWidget) =>
      oldWidget.takesOver != takesOver;
}
