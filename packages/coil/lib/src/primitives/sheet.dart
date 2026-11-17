import 'dart:math' as math;

import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/shape.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/surface.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// coil's sheet: a `stupid_simple_sheet` route (drag to dismiss, scroll
/// handoff, keyboard insets) with coil's own surface, corner and scrim.
///
/// `context` is read once, while the route is created, for:
///
/// - the motion: the theme's `gentle`, both in and out (a drag that
///   dismisses hands its fling velocity to it);
/// - the surface: two levels above the one `context` sits on
///   (`CoilSurface.popoverOffset`), its fill, shadow and dark-mode edge;
///   [child] sits on it too, clipped to its corners;
/// - the top corners: a superellipse of the glass sheet's
///   [glassRadius] (36) for the `rounded` and `pill` shapes, scaled down
///   with tighter shapes;
/// - the scrim: the theme's `CoilColors.scrim`, with no blur;
/// - the themes [child] inherits.
///
/// The sheet hugs its content: short content makes a short sheet on the
/// bottom edge, and a scroll view grows it up to the top cap (the top
/// safe area or 5 % of the window's height, whichever is larger). It
/// rides above the keyboard. Wider than [maxWidth], it centers.
///
/// A sheet opened from another sheet slides over it with its own scrim.
///
/// Put a [CoilSheetPanel] in it for the grabber, an optional title, a
/// pinned footer and the safe area.
class CoilSheetRoute<T> extends StupidSimpleSheetRoute<T> {
  /// Creates a sheet route showing [child] (usually a [CoilSheetPanel]).
  ///
  /// With [barrierDismissible] false, tapping the scrim and pressing Esc
  /// don't close it; dragging and back still do unless [child] blocks them
  /// with a `PopScope`.
  CoilSheetRoute({
    required BuildContext context,
    required Widget child,
    super.barrierDismissible,
    super.barrierLabel,
    CoilMotion? motion,
    super.settings,
  }) : backgroundColor = CoilTheme.of(context).colors.surface(
         math.min(CoilSurface.levelOf(context) + CoilSurface.popoverOffset, 8),
       ),
       shape = _shapeOf(context),
       super(
         motion: CoilTheme.motionOf(context, override: motion).gentle,
         barrierColor: CoilTheme.of(context).colors.scrim,
         originateAboveBottomViewInset: true,
         child:
             InheritedTheme.capture(
               from: context,
               to: Navigator.of(context).context,
             ).wrap(
               _SheetSurface(shape: _shapeOf(context), child: child),
             ),
       );

  /// The widest a sheet gets; wider windows center it.
  static const maxWidth = 560.0;

  /// The top corner radius of `stupid_simple_sheet`'s glass sheet
  /// (`StupidSimpleGlassSheetRoute.glassShape`), which coil's sheet uses
  /// for its default shape.
  static final double glassRadius = StupidSimpleGlassSheetRoute
      .glassShape
      .borderRadius
      .resolve(TextDirection.ltr)
      .topLeft
      .x;

  /// The least space above the sheet, as a fraction of the window's
  /// height, when the top safe area is smaller.
  static const topGapFraction = 0.05;

  /// The sheet's fill: the surface two levels above the opener.
  final Color backgroundColor;

  /// The sheet's outline: a superellipse with rounded top corners.
  final RoundedSuperellipseBorder shape;

  /// [glassRadius] for coil's default shape, scaled with the theme's touch
  /// container radius and capped at [glassRadius].
  static RoundedSuperellipseBorder _shapeOf(BuildContext context) {
    final container = CoilTheme.of(
      context,
    ).shape.radii(CoilTier.touch).container;
    final rounded = CoilShape.rounded.touch.container;
    final radius = math.min(glassRadius, glassRadius * container / rounded);
    return RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The sheet slides on the route's controller and stands on the
    // keyboard.
    final sheet = super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
    final media = MediaQuery.of(context);
    final gutter = math.max(0, (media.size.width - maxWidth) / 2);
    // Centered, the sheet clears side insets (a landscape notch) that
    // don't reach it. It rides on the keyboard, which covers the home
    // indicator, as platforms report it.
    EdgeInsets clear(EdgeInsets padding, {double below = 0}) =>
        padding.copyWith(
          left: math.max(0, padding.left - gutter),
          right: math.max(0, padding.right - gutter),
          bottom: math.max(0, padding.bottom - below),
        );
    return MediaQuery(
      data: media.copyWith(
        padding: clear(media.padding, below: media.viewInsets.bottom),
        viewPadding: clear(media.viewPadding),
      ),
      // The top cap; it also takes the top inset off the content's
      // padding.
      child: SafeArea(
        left: false,
        right: false,
        bottom: false,
        minimum: EdgeInsets.only(top: media.size.height * topGapFraction),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: sheet,
          ),
        ),
      ),
    );
  }
}

/// The sheet's surface: coil's fill, shadow and edge at the popover level,
/// in [shape], clipping [child] to it.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.shape, required this.child});

  final RoundedSuperellipseBorder shape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = shape.borderRadius;
    return CoilSurface(
      offset: CoilSurface.popoverOffset,
      borderRadius: radius,
      child: ClipRSuperellipse(borderRadius: radius, child: child),
    );
  }
}

/// The content layout of a [CoilSheetRoute]: a grabber, an optional
/// [title], then [child], then an optional pinned [footer], clear of the
/// home indicator and side insets.
///
/// A hairline under the header shows only while [child]'s scrollable has
/// content scrolled beneath it (read from its scroll notifications), and
/// one over the [footer] only while content continues below it; both fade
/// on the theme's `fade` / `fadeExit`.
class CoilSheetPanel extends StatefulWidget {
  /// Creates a sheet panel.
  const CoilSheetPanel({
    required this.child,
    super.key,
    this.title,
    this.footer,
  });

  /// An optional heading.
  final Widget? title;

  /// The contents, usually a list.
  final Widget child;

  /// Pinned under [child]: the sheet's buttons, usually a `CoilActionBar`
  /// with horizontal padding. It stays put while [child] scrolls and rides
  /// on the keyboard with the sheet. The panel keeps it above the home
  /// indicator, with [footerBottomGap] below it at least (the safe area
  /// counts toward it, and 8 always separates the two).
  final Widget? footer;

  /// The least space under a [footer], safe area included.
  static const footerBottomGap = 16.0;

  /// The most of the window's height a [footer] takes; past it (huge text
  /// in a short window), the footer scrolls.
  static const footerMaxHeightFraction = 0.4;

  @override
  State<CoilSheetPanel> createState() => _CoilSheetPanelState();
}

class _CoilSheetPanelState extends State<CoilSheetPanel> {
  /// Whether content is scrolled beneath the header.
  bool _scrolledUnder = false;

  /// Whether content continues below, beneath the footer.
  bool _continuesBelow = false;

  bool _onScroll(ScrollMetrics metrics, int depth) {
    // Only the sheet's own list, not scrollables nested inside rows.
    if (depth != 0 || metrics.axis != Axis.vertical) return false;
    final under = metrics.extentBefore > 0;
    final below = metrics.extentAfter > 0;
    if (under != _scrolledUnder || below != _continuesBelow) {
      setState(() {
        _scrolledUnder = under;
        _continuesBelow = below;
      });
    }
    return false;
  }

  /// A hairline over the top or bottom edge of [child] that fades in while
  /// [visible].
  Widget _hairline({
    required bool visible,
    required bool top,
    required String debugLabel,
    required Widget child,
  }) {
    final colors = CoilTheme.of(context).colors;
    final motion = CoilTheme.motionOf(context);
    return SingleMotionBuilder(
      value: visible ? 1 : 0,
      motion: visible ? motion.fade : motion.fadeExit,
      debugLabel: debugLabel,
      builder: (context, hairline, child) {
        final side = BorderSide(
          color: colors.border.withValues(
            alpha: colors.border.a * hairline.clamp(0.0, 1.0),
          ),
        );
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: top ? Border(top: side) : Border(bottom: side),
          ),
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    // A sheet is a touch surface whatever the tier, like its rows.
    final metrics = CoilTheme.metricsOf(
      context,
      tier: CoilTier.touch,
      size: CoilSize.regular,
    );
    // Title text starts where row text starts.
    final textInset = metrics.popupInset + metrics.itemPaddingX;
    final footer = widget.footer;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 36,
                height: 5,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.foreground.withValues(alpha: 0.16),
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (title != null)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                textInset,
                4,
                textInset,
                6,
              ),
              child: Semantics(
                header: true,
                child: DefaultTextStyle(
                  // The touch title, the size of an iOS headline.
                  style: theme.typography
                      .resolve(metrics.tier, metrics.size)
                      .title
                      .copyWith(color: colors.foreground),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: title,
                ),
              ),
            ),
          // The scroll-edge hairlines: painted over the edges of the
          // content, so showing them never shifts layout.
          Flexible(
            child: _hairline(
              visible: _scrolledUnder,
              top: true,
              debugLabel: 'CoilSheetPanel.hairline',
              child: _hairline(
                visible: footer != null && _continuesBelow,
                top: false,
                debugLabel: 'CoilSheetPanel.footerHairline',
                // Scroll updates and extent changes; other scroll
                // notifications can come during layout.
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: (n) => _onScroll(n.metrics, n.depth),
                  child: NotificationListener<ScrollUpdateNotification>(
                    onNotification: (n) => _onScroll(n.metrics, n.depth),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: EdgeInsets.only(
                bottom: math.max(
                  8,
                  CoilSheetPanel.footerBottomGap - safeBottom,
                ),
              ),
              // Huge text in a short window: the footer scrolls on its
              // own rather than push the content out of the sheet.
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.sizeOf(context).height *
                      CoilSheetPanel.footerMaxHeightFraction,
                ),
                child: SingleChildScrollView(primary: false, child: footer),
              ),
            ),
        ],
      ),
    );
  }
}
