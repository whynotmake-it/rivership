import 'package:coil/src/foundation/input_modality.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The colors and sizes of a coil scrollbar. The owner resolves it, for
/// example from a `CoilScrollAreaStyle`.
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

/// coil's scroll behavior. Scroll areas apply it locally, never app-wide.
///
/// * Physics: the platform's, as Flutter picks them (bouncing on Apple
///   platforms, clamping elsewhere).
/// * Overscroll: Android stretches. Nothing glows.
/// * Scrollbar: a [CoilScrollbar] for [tier], or none when [scrollbar] is
///   false.
/// * Dragging: touch, stylus and trackpad drag the content. A mouse drags
///   only the scrollbar.
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
      fadeDuration:
          CoilTheme.motionOf(context).fade.duration ??
          const Duration(milliseconds: 120),
      child: child,
    );
  }

  @override
  bool shouldNotify(CoilScrollBehavior oldDelegate) =>
      tier != oldDelegate.tier ||
      look != oldDelegate.look ||
      scrollbar != oldDelegate.scrollbar;
}

/// coil's scrollbar: a [RawScrollbar] with a superellipse pill thumb.
///
/// On the pointer tier the thumb is 4 wide. It springs to 6 while a mouse
/// hovers it or drags it. It shows while scrolling or hovered and hides
/// 600 ms later.
///
/// On the touch tier it's a thin overlay bar that shows only while
/// scrolling and can't be grabbed, like the OS's.
///
/// It fades out over [fadeDuration], the theme's `fade` token when built
/// by [CoilScrollBehavior].
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
         timeToFade: hideDelay,
         pressDuration: Duration.zero,
       );

  /// How long the bar stays after scrolling stops, before it fades.
  static const hideDelay = Duration(milliseconds: 600);

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
