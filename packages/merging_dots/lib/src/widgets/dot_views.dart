import 'package:flutter/widgets.dart';
import 'package:merging_dots/src/animation/dot_animator.dart';
import 'package:merging_dots/src/animation/dot_sequence.dart';
import 'package:merging_dots/src/animation/dot_stagger.dart';
import 'package:merging_dots/src/model/dot_cloud.dart';
import 'package:merging_dots/src/model/dot_grid.dart';
import 'package:merging_dots/src/model/dot_scene.dart';
import 'package:merging_dots/src/model/dot_state.dart';
import 'package:merging_dots/src/rendering/dot_styles.dart';
import 'package:merging_dots/src/rendering/render_dots.dart';
import 'package:motor/motor.dart';

/// Shows a [DotGrid] of dots that merge into each other.
///
/// Give it a new [grid] and every dot animates to its new size with
/// [motion], swept across the grid by [stagger]:
///
/// ```dart
/// DotGridView(
///   grid: isFavorite ? heart : outline,
///   motion: const Motion.bouncySpring(),
///   stagger: const DotStagger.radial(duration: Duration(milliseconds: 200)),
/// )
/// ```
///
/// Or play a [DotSequence] with [DotGridView.sequence], for example a
/// loading indicator exported from the editor.
///
/// Every dot widget is its own repaint boundary, and animation frames only
/// repaint it: nothing rebuilds or lays out while the dots move. Pixels are
/// shaded only around visible dots, and each pixel looks at its 5x5 nearest
/// cells, so grid size barely changes the cost.
class DotGridView extends StatefulWidget {
  /// Shows [grid], animating to it whenever it changes.
  const DotGridView({
    required DotGrid this.grid,
    super.key,
    this.style = const DotGridStyle(),
    this.motion = const CupertinoMotion.smooth(),
    this.stagger = const DotStagger.none(),
  }) : sequence = null,
       playing = true,
       onFrame = null;

  /// Plays [sequence] while [playing].
  ///
  /// When the sequence changes but keeps its number of frames, playback
  /// continues at the current frame, so frames can be edited live.
  const DotGridView.sequence({
    required DotSequence<DotGrid> this.sequence,
    super.key,
    this.style = const DotGridStyle(),
    this.playing = true,
    this.onFrame,
  }) : grid = null,
       motion = const CupertinoMotion.smooth(),
       stagger = const DotStagger.none();

  /// The grid to show, or null when playing a [sequence].
  final DotGrid? grid;

  /// The sequence to play, or null when showing a [grid].
  final DotSequence<DotGrid>? sequence;

  /// How the dots are drawn.
  final DotGridStyle style;

  /// The motion when [grid] changes.
  final Motion motion;

  /// The stagger when [grid] changes.
  final DotStagger stagger;

  /// Whether [sequence] plays. When false, the dots freeze where they are.
  final bool playing;

  /// Called whenever [sequence] starts moving to a frame.
  final ValueChanged<int>? onFrame;

  @override
  State<DotGridView> createState() => _DotGridViewState();
}

class _DotGridViewState extends _DotsViewState<DotGridView, DotGrid> {
  @override
  DotGrid? stateOf(DotGridView widget) => widget.grid;
  @override
  DotSequence<DotGrid>? sequenceOf(DotGridView widget) => widget.sequence;
  @override
  Motion get motion => widget.motion;
  @override
  DotStagger get stagger => widget.stagger;
  @override
  bool get playing => widget.playing;
  @override
  ValueChanged<int>? get onFrame => widget.onFrame;

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return _DotGridRenderWidget(
      animator: animator,
      color:
          style.color ?? IconTheme.of(context).color ?? const Color(0xFF000000),
      devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      style: style,
    );
  }
}

/// Shows a [DotCloud]: freely placed dots that merge into each other.
///
/// Give it a new [cloud] and every dot moves to its new place and size with
/// [motion]. Dots are matched by index; added dots grow out of nothing and
/// removed ones shrink away. Or play a [DotSequence] with
/// [DotCloudView.sequence], like a spinner.
///
/// The cloud's canvas is scaled to fit and centered. Up to
/// [DotCloud.maxDots] dots are drawn, and each pixel only looks at the dots
/// near it. Dots on a regular lattice are still cheaper as a [DotGridView],
/// which skips sorting them every frame.
class DotCloudView extends StatefulWidget {
  /// Shows [cloud], animating to it whenever it changes.
  const DotCloudView({
    required DotCloud this.cloud,
    super.key,
    this.style = const DotCloudStyle(),
    this.motion = const CupertinoMotion.smooth(),
    this.stagger = const DotStagger.none(),
  }) : sequence = null,
       playing = true,
       onFrame = null;

  /// Plays [sequence] while [playing].
  ///
  /// When the sequence changes but keeps its number of frames, playback
  /// continues at the current frame, so frames can be edited live.
  const DotCloudView.sequence({
    required DotSequence<DotCloud> this.sequence,
    super.key,
    this.style = const DotCloudStyle(),
    this.playing = true,
    this.onFrame,
  }) : cloud = null,
       motion = const CupertinoMotion.smooth(),
       stagger = const DotStagger.none();

  /// The cloud to show, or null when playing a [sequence].
  final DotCloud? cloud;

  /// The sequence to play, or null when showing a [cloud].
  final DotSequence<DotCloud>? sequence;

  /// How the dots are drawn.
  final DotCloudStyle style;

  /// The motion when [cloud] changes.
  final Motion motion;

  /// The stagger when [cloud] changes.
  final DotStagger stagger;

  /// Whether [sequence] plays. When false, the dots freeze where they are.
  final bool playing;

  /// Called whenever [sequence] starts moving to a frame.
  final ValueChanged<int>? onFrame;

  @override
  State<DotCloudView> createState() => _DotCloudViewState();
}

class _DotCloudViewState extends _DotsViewState<DotCloudView, DotCloud> {
  @override
  DotCloud? stateOf(DotCloudView widget) => widget.cloud;
  @override
  DotSequence<DotCloud>? sequenceOf(DotCloudView widget) => widget.sequence;
  @override
  Motion get motion => widget.motion;
  @override
  DotStagger get stagger => widget.stagger;
  @override
  bool get playing => widget.playing;
  @override
  ValueChanged<int>? get onFrame => widget.onFrame;

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return _DotCloudRenderWidget(
      animator: animator,
      color:
          style.color ?? IconTheme.of(context).color ?? const Color(0xFF000000),
      devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      blend: style.blend,
    );
  }
}

/// Shows a [DotScene]: layers of freely placed dots, each merging with its
/// own blend, where upper layers can cut holes into lower ones.
///
/// Give it a new [scene] and dots move, resize and change layers with
/// [motion], while the layers fade, move, squash and change their blend
/// along with them. Or play a [DotSequence] with [DotSceneView.sequence].
///
/// A [modifier] adjusts the layers every frame on top of that, which is
/// how a `DotCharacter` blinks and looks around. To show a character, use
/// `DotCharacterView`.
///
/// A scene draws up to [DotScene.maxDots] dots, and every shaded pixel
/// looks at all of them, so it is meant for small, expressive shapes. Use
/// a `DotCloudView` for many dots.
class DotSceneView extends StatefulWidget {
  /// Shows [scene], animating to it whenever it changes.
  const DotSceneView({
    required DotScene this.scene,
    super.key,
    this.style = const DotSceneStyle(),
    this.motion = const CupertinoMotion.smooth(),
    this.stagger = const DotStagger.none(),
    this.modifier,
  }) : sequence = null,
       playing = true,
       onFrame = null;

  /// Plays [sequence] while [playing].
  const DotSceneView.sequence({
    required DotSequence<DotScene> this.sequence,
    super.key,
    this.style = const DotSceneStyle(),
    this.playing = true,
    this.onFrame,
    this.modifier,
  }) : scene = null,
       motion = const CupertinoMotion.smooth(),
       stagger = const DotStagger.none();

  /// The scene to show, or null when playing a [sequence].
  final DotScene? scene;

  /// The sequence to play, or null when showing a [scene].
  final DotSequence<DotScene>? sequence;

  /// How the layers are drawn.
  final DotSceneStyle style;

  /// The motion when [scene] changes.
  final Motion motion;

  /// The stagger when [scene] changes.
  final DotStagger stagger;

  /// Whether [sequence] plays. When false, the dots freeze where they are.
  final bool playing;

  /// Called whenever [sequence] starts moving to a frame.
  final ValueChanged<int>? onFrame;

  /// Adjusts the layers every frame.
  final DotSceneModifier? modifier;

  @override
  State<DotSceneView> createState() => _DotSceneViewState();
}

class _DotSceneViewState extends _DotsViewState<DotSceneView, DotScene> {
  @override
  DotScene? stateOf(DotSceneView widget) => widget.scene;
  @override
  DotSequence<DotScene>? sequenceOf(DotSceneView widget) => widget.sequence;
  @override
  Motion get motion => widget.motion;
  @override
  DotStagger get stagger => widget.stagger;
  @override
  bool get playing => widget.playing;
  @override
  ValueChanged<int>? get onFrame => widget.onFrame;

  @override
  Widget build(BuildContext context) => DotSceneRenderer(
    animator: animator,
    style: widget.style,
    modifier: widget.modifier,
  );
}

/// Draws the scene of [animator] with [style], adjusted by [modifier].
///
/// [DotSceneView] and `DotCharacterView` build on it. Use it directly to
/// drive a [DotAnimator] yourself.
class DotSceneRenderer extends LeafRenderObjectWidget {
  /// Draws the scene of [animator].
  const DotSceneRenderer({
    required this.animator,
    super.key,
    this.style = const DotSceneStyle(),
    this.modifier,
  });

  /// Where the dots come from.
  final DotAnimator<DotScene> animator;

  /// How the layers are drawn.
  final DotSceneStyle style;

  /// Adjusts the layers every frame.
  final DotSceneModifier? modifier;

  List<Color> _colors(BuildContext context) {
    final fallback = IconTheme.of(context).color ?? const Color(0xFF000000);
    return [
      for (var i = 0; i < DotScene.maxLayers; i++)
        style.layer(i).color ??
            (style.layer(i).mode == DotLayerMode.over
                ? fallback
                : const Color(0x00000000)),
    ];
  }

  @override
  RenderDotScene createRenderObject(BuildContext context) => RenderDotScene(
    animator: animator,
    devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    colors: _colors(context),
    style: style,
    modifier: modifier,
  );

  @override
  void updateRenderObject(BuildContext context, RenderDotScene renderObject) {
    renderObject
      ..animator = animator
      ..devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1
      ..colors = _colors(context)
      ..style = style
      ..modifier = modifier;
  }
}

/// Drives a [DotAnimator] from a dot view's configuration.
abstract class _DotsViewState<W extends StatefulWidget, T extends DotState>
    extends State<W>
    with SingleTickerProviderStateMixin<W> {
  late final DotAnimator<T> animator;

  T? stateOf(W widget);
  DotSequence<T>? sequenceOf(W widget);
  Motion get motion;
  DotStagger get stagger;
  bool get playing;
  ValueChanged<int>? get onFrame;

  @override
  void initState() {
    super.initState();
    final sequence = sequenceOf(widget);
    animator = DotAnimator<T>(
      vsync: this,
      initial: sequence?.frames.first.state ?? stateOf(widget)!,
    )..onFrame = _onFrame;
    if (sequence != null) {
      animator.play(sequence);
      if (!playing) animator.pause();
    }
  }

  void _onFrame(int frame) => onFrame?.call(frame);

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sequence = sequenceOf(widget);
    final previous = sequenceOf(oldWidget);
    if (sequence != null) {
      if (sequence != previous) {
        animator.play(sequence, restart: previous == null);
        if (!playing) animator.pause();
      } else if (playing && animator.isPaused) {
        animator.resume();
      } else if (!playing && !animator.isPaused) {
        animator.pause();
      }
      return;
    }

    final state = stateOf(widget)!;
    if (state != animator.target || previous != null) {
      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduceMotion) {
        animator.jumpTo(state);
      } else {
        animator.animateTo(state, motion: motion, stagger: stagger);
      }
    }
  }

  @override
  void dispose() {
    animator.dispose();
    super.dispose();
  }
}

class _DotGridRenderWidget extends LeafRenderObjectWidget {
  const _DotGridRenderWidget({
    required this.animator,
    required this.color,
    required this.devicePixelRatio,
    required this.style,
  });

  final DotAnimator<DotGrid> animator;
  final Color color;
  final double devicePixelRatio;
  final DotGridStyle style;

  @override
  RenderDotGrid createRenderObject(BuildContext context) => RenderDotGrid(
    animator: animator,
    color: color,
    devicePixelRatio: devicePixelRatio,
    dotSize: style.dotSize,
    blend: style.blend,
    offsetRange: style.offsetRange,
    cellSize: style.cellSize,
    shape: style.shape,
    cornerRadius: style.cornerRadius,
    innerRadius: style.innerRadius,
  );

  @override
  void updateRenderObject(BuildContext context, RenderDotGrid renderObject) {
    renderObject
      ..animator = animator
      ..color = color
      ..devicePixelRatio = devicePixelRatio
      ..dotSize = style.dotSize
      ..blend = style.blend
      ..offsetRange = style.offsetRange
      ..cellSize = style.cellSize
      ..shape = style.shape
      ..cornerRadius = style.cornerRadius
      ..innerRadius = style.innerRadius;
  }
}

class _DotCloudRenderWidget extends LeafRenderObjectWidget {
  const _DotCloudRenderWidget({
    required this.animator,
    required this.color,
    required this.devicePixelRatio,
    required this.blend,
  });

  final DotAnimator<DotCloud> animator;
  final Color color;
  final double devicePixelRatio;
  final double blend;

  @override
  RenderDotCloud createRenderObject(BuildContext context) => RenderDotCloud(
    animator: animator,
    color: color,
    devicePixelRatio: devicePixelRatio,
    blend: blend,
  );

  @override
  void updateRenderObject(BuildContext context, RenderDotCloud renderObject) {
    renderObject
      ..animator = animator
      ..color = color
      ..devicePixelRatio = devicePixelRatio
      ..blend = blend;
  }
}
