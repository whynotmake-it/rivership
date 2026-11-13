import 'package:coil/src/foundation/input_modality.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// How a coil scrollbar looks. Resolved by the owner (e.g. from a
/// `CoilScrollAreaStyle`) and handed to [CoilScrollBehavior].
@immutable
class CoilScrollbarLook {
  /// Creates a scrollbar look.
  const CoilScrollbarLook({
    required this.color,
    required this.hoverColor,
    required this.dragColor,
    this.thickness = 4,
    this.hoverThickness = 6,
    this.crossAxisMargin = 2,
    this.mainAxisMargin = 4,
    this.touchThickness = 3,
  });

  /// The thumb at rest (pointer).
  final Color color;

  /// The thumb while a hovering pointer is over the scrollbar.
  final Color hoverColor;

  /// The thumb while it's dragged.
  final Color dragColor;

  /// The thumb's width at rest (pointer).
  final double thickness;

  /// The thumb's width while hovered or dragged (pointer).
  final double hoverThickness;

  /// The gap between the thumb and the viewport's edge.
  final double crossAxisMargin;

  /// The gap between the thumb and the viewport's ends.
  final double mainAxisMargin;

  /// The overlay bar's width on the touch tier.
  final double touchThickness;

  @override
  bool operator ==(Object other) =>
      other is CoilScrollbarLook &&
      other.color == color &&
      other.hoverColor == hoverColor &&
      other.dragColor == dragColor &&
      other.thickness == thickness &&
      other.hoverThickness == hoverThickness &&
      other.crossAxisMargin == crossAxisMargin &&
      other.mainAxisMargin == mainAxisMargin &&
      other.touchThickness == touchThickness;

  @override
  int get hashCode => Object.hash(
    color,
    hoverColor,
    dragColor,
    thickness,
    hoverThickness,
    crossAxisMargin,
    mainAxisMargin,
    touchThickness,
  );
}

/// coil's scroll behavior, applied locally (never app-wide) by scroll
/// areas, menus, sheets and tables.
///
/// * Physics: the platform's (bouncing on Apple platforms, clamping
///   elsewhere), as the widgets layer's [ScrollBehavior] picks them.
/// * Overscroll: Android stretches (`StretchingOverscrollIndicator`); other
///   platforms bounce or stop. No glow.
/// * Scrollbar: on the pointer [tier], [CoilScrollbar] (thin, widens on
///   hover, hides when idle); on the touch tier a thin overlay bar that
///   shows only while scrolling, like the OS's. Pass `scrollbar: false` to
///   draw none.
/// * Drag devices: touch, stylus and trackpad drag the content; a mouse
///   drags only the scrollbar.
class CoilScrollBehavior extends ScrollBehavior {
  /// Creates the behavior.
  const CoilScrollBehavior({
    required this.tier,
    required this.look,
    this.scrollbar = true,
  });

  /// Which scrollbar to draw.
  final CoilTier tier;

  /// How the scrollbar looks.
  final CoilScrollbarLook look;

  /// Whether to draw a scrollbar at all.
  final bool scrollbar;

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => switch (getPlatform(context)) {
    TargetPlatform.android => StretchingOverscrollIndicator(
      axisDirection: details.direction,
      clipBehavior: details.decorationClipBehavior ?? Clip.hardEdge,
      child: child,
    ),
    _ => child,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (!scrollbar) return child;
    return CoilScrollbar(
      controller: details.controller,
      look: look,
      tier: tier,
      child: child,
    );
  }

  @override
  bool shouldNotify(CoilScrollBehavior oldDelegate) =>
      tier != oldDelegate.tier ||
      look != oldDelegate.look ||
      scrollbar != oldDelegate.scrollbar;
}

/// coil's scrollbar: a [RawScrollbar] whose thumb is a superellipse pill.
///
/// On the pointer tier it's 4 wide and widens to 6 while a hovering pointer
/// is over it or it's dragged, springing on the theme's `quick` token; its
/// color moves on `fade`. It shows while scrolling or hovered and hides
/// 600 ms after. On the touch tier it's a thin overlay bar that only shows
/// while scrolling and can't be grabbed, like the OS's.
///
/// The idle fade itself is [RawScrollbar]'s: a timed fade driven by its own
/// controller, with [RawScrollbar.fadeDuration] taken from the `fade`
/// token's duration.
class CoilScrollbar extends RawScrollbar {
  /// Creates a scrollbar for [child]'s primary scrollable.
  CoilScrollbar({
    required super.child,
    required this.look,
    required this.tier,
    super.controller,
    super.key,
    super.fadeDuration = const Duration(milliseconds: 120),
  }) : super(
         thumbVisibility: false,
         interactive: tier == CoilTier.pointer,
         thickness: tier == CoilTier.pointer
             ? look.thickness
             : look.touchThickness,
         crossAxisMargin: look.crossAxisMargin,
         mainAxisMargin: look.mainAxisMargin,
         shape: const RoundedSuperellipseBorder(
           borderRadius: BorderRadius.all(Radius.circular(999)),
         ),
         thumbColor: look.color,
         timeToFade: const Duration(milliseconds: 600),
         pressDuration: Duration.zero,
       );

  /// How the bar looks.
  final CoilScrollbarLook look;

  /// Pointer (interactive, widens on hover) or touch (overlay only).
  final CoilTier tier;

  @override
  RawScrollbarState<CoilScrollbar> createState() => _CoilScrollbarState();
}

class _CoilScrollbarState extends RawScrollbarState<CoilScrollbar> {
  late final _hover = SingleMotionController(
    motion: const Motion.instant(),
    vsync: this,
    velocityTracking: const VelocityTracking.off(),
    debugLabel: 'CoilScrollbar.hover',
  );
  bool _hovered = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _hover.addListener(updateScrollbarPainter);
  }

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  void _emphasize() {
    final on = _hovered || _dragging;
    final motion = CoilTheme.motionOf(context);
    _hover
      ..motion = on ? motion.quick : motion.quickExit
      ..animateTo(on ? 1 : 0);
    // The drag color changes even when the width is already there.
    updateScrollbarPainter();
  }

  @override
  void updateScrollbarPainter() {
    super.updateScrollbarPainter();
    final look = widget.look;
    if (widget.tier != CoilTier.pointer) return;
    final t = _hover.value.clamp(0.0, 1.0);
    scrollbarPainter
      ..thickness = look.thickness + (look.hoverThickness - look.thickness) * t
      ..color = _dragging
          ? look.dragColor
          : Color.lerp(look.color, look.hoverColor, t)!;
  }

  @override
  void handleHover(PointerHoverEvent event) {
    super.handleHover(event);
    final over =
        CoilInputModality.canHover(event.kind) &&
        isPointerOverScrollbar(event.position, event.kind, forHover: true);
    if (over != _hovered) {
      _hovered = over;
      _emphasize();
    }
  }

  @override
  void handleHoverExit(PointerExitEvent event) {
    super.handleHoverExit(event);
    if (_hovered) {
      _hovered = false;
      _emphasize();
    }
  }

  @override
  void handleThumbPress() {
    super.handleThumbPress();
    _dragging = true;
    _emphasize();
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    super.handleThumbPressEnd(localPosition, velocity);
    _dragging = false;
    _emphasize();
  }
}

/// Fades [child]'s scrolled content out at whichever edges have more
/// content, over [extent] logical pixels.
///
/// The fade at each edge grows with how far there is to scroll in that
/// direction, up to [extent], read from the scroll notifications of
/// [child]'s scrollable along [axis] (nothing is measured). Painted with a
/// [ShaderMask], so it never changes layout.
class CoilEdgeFade extends StatefulWidget {
  /// Creates an edge fade.
  const CoilEdgeFade({
    required this.child,
    super.key,
    this.axis = Axis.vertical,
    this.extent = 32,
    this.enabled = true,
  });

  /// The scrollable.
  final Widget child;

  /// The scroll axis whose edges fade.
  final Axis axis;

  /// How far each fade reaches.
  final double extent;

  /// Whether to fade at all.
  final bool enabled;

  @override
  State<CoilEdgeFade> createState() => _CoilEdgeFadeState();
}

class _CoilEdgeFadeState extends State<CoilEdgeFade> {
  double _before = 0;
  double _after = 0;

  bool _onMetrics(ScrollMetrics metrics, int depth) {
    if (depth != 0 || metrics.axis != widget.axis) return false;
    final before = metrics.extentBefore.clamp(0.0, widget.extent);
    final after = metrics.extentAfter.clamp(0.0, widget.extent);
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics, n.depth),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(n.metrics, n.depth),
        child: widget.child,
      ),
    );
    // Always a ShaderMask, so the tree (and the scroll position) stays the
    // same whether or not an edge is fading.
    final before = widget.enabled ? _before : 0.0;
    final after = widget.enabled ? _after : 0.0;
    final vertical = widget.axis == Axis.vertical;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final length = vertical ? bounds.height : bounds.width;
        if (length <= 0 || (before == 0 && after == 0)) {
          return const LinearGradient(
            colors: [Color(0xFF000000), Color(0xFF000000)],
          ).createShader(bounds);
        }
        final start = (before / length).clamp(0.0, 0.5);
        final end = (after / length).clamp(0.0, 0.5);
        return LinearGradient(
          begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
          end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
          colors: const [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0, start, 1 - end, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

/// Scrolls a [ScrollController] to a target on a Motor spring, for keyboard
/// scrolling (arrows, Page Up/Down, Home/End).
///
/// The position follows the spring with `jumpTo`, so a repeated key adds to
/// where the scroll is headed instead of restarting, and a user drag takes
/// over (call [stop] on a drag start).
class CoilScrollSpring {
  /// Creates a scroll spring ticking on [vsync].
  CoilScrollSpring({required TickerProvider vsync, String? debugLabel})
    : _offset = SingleMotionController(
        motion: const Motion.instant(),
        vsync: vsync,
        debugLabel: debugLabel ?? 'CoilScrollSpring',
      ) {
    _offset.addListener(_follow);
  }

  final SingleMotionController _offset;
  ScrollController? _controller;
  bool _running = false;
  double _target = 0;

  /// Where [controller] is headed: the spring's target while it runs, else
  /// its current offset.
  double targetOf(ScrollController controller) =>
      _running && _controller == controller ? _target : controller.offset;

  /// Springs [controller] to [target] (clamped to its extent) on [motion].
  void scrollTo(ScrollController controller, double target, Motion motion) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final to = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (!_running || _controller != controller) {
      _offset.value = position.pixels;
    }
    _controller = controller;
    _running = true;
    _target = to;
    _offset
      ..motion = motion
      ..animateTo(to).whenComplete(() => _running = false);
  }

  /// Stops following the spring (a user drag took over).
  void stop() {
    if (!_running) return;
    _running = false;
    _offset.stop();
  }

  void _follow() {
    final controller = _controller;
    if (!_running || controller == null || !controller.hasClients) return;
    final position = controller.position;
    position.jumpTo(
      _offset.value.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  /// Releases the spring.
  void dispose() => _offset.dispose();
}
