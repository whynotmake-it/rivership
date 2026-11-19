import 'dart:math' as math;

import 'package:coil/src/foundation/icons.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/shape.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/foundation/typography.dart';
import 'package:coil/src/primitives/drawn_glyph.dart';
import 'package:coil/src/primitives/focus_ring.dart';
import 'package:coil/src/primitives/interaction.dart';
import 'package:coil/src/primitives/surface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';
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
///   [child] sits on it too, clipped to its corners. The surface runs a
///   window's height past the sheet's bottom edge, so a sheet dragged up
///   past its rest shows its own fill below it, not the page;
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
/// Put a [CoilSheetPanel] in it for an optional title, a pinned footer and
/// the safe area.
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

  /// [context]'s scroll behavior without scrollbars, for a scrollable that
  /// takes its own behavior (a `PageView`, a `ListWheelScrollView`), so
  /// that inside a sheet it still hands drags off to the sheet.
  ///
  /// Those scrollables copy the ambient behavior by default, and while the
  /// sheet holds a drag that behavior is the sheet's own; a copy of the
  /// app's behavior after the drag can't be compared with it. Outside a
  /// sheet this is the plain copy.
  static ScrollBehavior scrollBehaviorOf(BuildContext context) {
    final behavior = ScrollConfiguration.of(
      context,
    ).copyWith(scrollbars: false);
    return behavior is ScrollDragBehavior
        ? behavior
        : ScrollDragBehavior(parent: behavior);
  }

  /// The sheet's fill: the surface two levels above the opener.
  final Color backgroundColor;

  /// The sheet's outline: a superellipse with rounded top corners.
  final RoundedSuperellipseBorder shape;

  /// The sheet's top corner radius at [context]: [glassRadius] for coil's
  /// default shape, scaled with the theme's touch container radius and
  /// capped at [glassRadius].
  static double cornerRadiusOf(BuildContext context) {
    final container = CoilTheme.of(
      context,
    ).shape.radii(CoilTier.touch).container;
    final rounded = CoilShape.rounded.touch.container;
    return math.min(glassRadius, glassRadius * container / rounded);
  }

  static RoundedSuperellipseBorder _shapeOf(BuildContext context) =>
      RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(cornerRadiusOf(context)),
        ),
      );

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
///
/// The surface runs a window's height past the sheet's bottom edge, so a
/// sheet dragged up past its rest still shows its own fill below, not the
/// page. [child] keeps the sheet's size and is laid out as without it.
/// This is how `stupid_simple_sheet`'s `SheetBackground` extends its fill,
/// done on coil's surface.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.shape, required this.child});

  final RoundedSuperellipseBorder shape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = shape.borderRadius;
    final below = MediaQuery.sizeOf(context).height;
    return PaddingExtended(
      padding: EdgeInsets.only(bottom: -below),
      child: CoilSurface(
        offset: CoilSurface.popoverOffset,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.only(bottom: below),
          child: ClipRSuperellipse(borderRadius: radius, child: child),
        ),
      ),
    );
  }
}

/// Where a sheet's header puts its title and close button.
enum CoilSheetHeaderLayout {
  /// The title centered over the sheet and the close button in the leading
  /// corner, as iOS sheets have them (Apple's HIG: Cancel or Close on the
  /// leading edge of the top bar, a round close button in the upper-left
  /// corner). iOS and macOS.
  centered,

  /// The title at the start, aligned with the rows' text, and the close
  /// button in the trailing corner, as Material's sheets put their close
  /// affordance in the header. Android and the other platforms.
  start;

  /// The layout [platform]'s own sheets use.
  static CoilSheetHeaderLayout forPlatform(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => centered,
        _ => start,
      };
}

/// The content layout of a [CoilSheetRoute]: a header with an optional
/// [title] and a [close] button, then [child], then an optional pinned
/// [footer], clear of the home indicator and side insets.
///
/// The header is one line, the touch tier's control height (44) tall,
/// whose middle runs through the center of the sheet's top corner (36 down
/// for the default shape, [headerCenterOf]). The close button sits on that
/// center, so its round shape is concentric with the corner.
/// [headerLayout] picks the sides: on iOS and macOS the title is centered
/// and the close button leads; elsewhere the title starts where the rows'
/// text starts and the close button trails. A title that doesn't fit ends
/// in an ellipsis before the button. With neither a title nor a close
/// button there is no header, and [child] starts [topGap] below the top
/// edge.
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
    this.close = const CoilSheetCloseButton(),
    this.headerLayout,
    this.footer,
  });

  /// An optional heading, on one line.
  final Widget? title;

  /// The close button, in the header's corner: by default a
  /// [CoilSheetCloseButton] that pops the route, so every sheet shows a
  /// way out. Pass one with your own `onPressed` or label, any other
  /// widget, or null for none. The default hides itself where the route
  /// can't be popped (a `PopScope` that blocks it, as a non-dismissible
  /// dialog has).
  final Widget? close;

  /// Where the header puts the title and [close]; null follows the
  /// platform ([CoilSheetHeaderLayout.forPlatform]).
  final CoilSheetHeaderLayout? headerLayout;

  /// The contents, usually a list.
  final Widget child;

  /// Pinned under [child]: the sheet's buttons, usually a `CoilActionBar`
  /// with horizontal padding. It stays put while [child] scrolls and rides
  /// on the keyboard with the sheet. The panel keeps it above the home
  /// indicator, with [footerBottomGap] below it at least (the safe area
  /// counts toward it, and 8 always separates the two).
  final Widget? footer;

  /// The space above [child] when there's no header. A sheet has no
  /// grabber; the drag works anywhere on it.
  static const topGap = 12.0;

  /// The least space between the close button and the sheet's top and
  /// side edges, for shapes whose corner is too tight to center it in.
  static const closeMinInset = 12.0;

  /// The least space under a [footer], safe area included.
  static const footerBottomGap = 16.0;

  /// The most of the window's height a [footer] takes; past it (huge text
  /// in a short window), the footer scrolls.
  static const footerMaxHeightFraction = 0.4;

  /// The distance from the sheet's top edge, and from the close button's
  /// side edge, to the middle of the header line at [context]: the center
  /// of the sheet's top corner ([CoilSheetRoute.cornerRadiusOf]), or
  /// further in where a tight corner would put the close button closer
  /// than [closeMinInset] to the edges.
  static double headerCenterOf(BuildContext context) {
    final radius = CoilSheetCloseButton.sizeOf(context) / 2;
    final inset = math.max(
      CoilShape.nested(CoilSheetRoute.cornerRadiusOf(context), radius),
      closeMinInset,
    );
    return inset + radius;
  }

  /// The space above a line of [lineHeight] that starts a sheet without a
  /// header (a search field with a [CoilSheetCloseSlot] at its end), on
  /// top of [topGap], so the line's middle runs where the header's would.
  static double lineTopOf(BuildContext context, double lineHeight) =>
      math.max(0, headerCenterOf(context) - topGap - lineHeight / 2);

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

  /// [CoilSheetPanel.close], unless it's the default button on a route
  /// that can't be popped.
  Widget? _close() {
    final close = widget.close;
    if (close is CoilSheetCloseButton &&
        close.onPressed == null &&
        ModalRoute.of(context)?.popDisposition ==
            RoutePopDisposition.doNotPop) {
      return null;
    }
    return close;
  }

  /// The title and the close button on one line, centered on the corner's
  /// center.
  Widget _header({
    required Widget? title,
    required Widget? close,
    required CoilMetrics metrics,
  }) {
    final theme = CoilTheme.of(context);
    final layout =
        widget.headerLayout ??
        CoilSheetHeaderLayout.forPlatform(defaultTargetPlatform);
    final slot = CoilSheetCloseSlot.extentOf(context);
    final edge = CoilSheetCloseSlot.edgeOf(context);
    // Title text starts where row text starts.
    final textInset = metrics.popupInset + metrics.itemPaddingX;
    final gap = theme.metrics.resolve(CoilTier.touch, CoilSize.compact).gap;
    final centered = layout == CoilSheetHeaderLayout.centered;

    final titleText = title == null
        ? const SizedBox.shrink()
        : Semantics(
            header: true,
            child: DefaultTextStyle(
              // The touch title, the size of an iOS headline.
              style: theme.typography
                  .resolve(metrics.tier, metrics.size)
                  .title
                  .copyWith(color: theme.colors.foreground),
              textAlign: centered ? TextAlign.center : TextAlign.start,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              child: title,
            ),
          );

    final List<Widget> children;
    if (close == null) {
      children = [
        SizedBox(width: textInset),
        Expanded(child: titleText),
        SizedBox(width: textInset),
      ];
    } else if (centered) {
      // The title centers on the sheet: an empty slot balances the
      // button.
      children = [
        CoilSheetCloseSlot(side: CoilSheetCloseSide.start, child: close),
        SizedBox(width: gap),
        Expanded(child: titleText),
        SizedBox(width: gap + slot + edge),
      ];
    } else {
      children = [
        SizedBox(width: textInset),
        Expanded(child: titleText),
        SizedBox(width: gap),
        CoilSheetCloseSlot(child: close),
      ];
    }
    return Padding(
      padding: EdgeInsets.only(top: edge),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: slot),
        child: Row(children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final close = _close();
    // A sheet is a touch surface whatever the tier, like its rows.
    final metrics = CoilTheme.metricsOf(
      context,
      tier: CoilTier.touch,
      size: CoilSize.regular,
    );
    final footer = widget.footer;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final ringRoom = CoilTheme.of(context).focusRing.extent;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title == null && close == null)
            // Room above the content, so it clears the corners.
            const SizedBox(height: CoilSheetPanel.topGap)
          else
            _header(title: title, close: close, metrics: metrics),
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
                // The scroll view reaches into the gaps above and below by
                // the focus ring's room, so the ring around a button at
                // its edge isn't clipped; the buttons stay where they were.
                child: PaddingExtended(
                  padding: EdgeInsets.symmetric(vertical: -ringRoom),
                  child: SingleChildScrollView(
                    primary: false,
                    padding: EdgeInsets.symmetric(vertical: ringRoom),
                    child: footer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Which side of its line a [CoilSheetCloseSlot] sits on.
enum CoilSheetCloseSide {
  /// The start edge: the header's close button on iOS and macOS.
  start,

  /// The end edge: the header's close button elsewhere, and the close
  /// button at the end of a search line on every platform.
  end,
}

/// A sheet's close button where the header puts it: centered in a square
/// of its hit target, as far from the sheet's [side] edge as the corner's
/// center ([CoilSheetPanel.headerCenterOf]), so its round shape is
/// concentric with the corner.
///
/// [CoilSheetPanel] uses it in its header. Put one at the end of a line
/// that starts a sheet without a header, such as a search field, with
/// [CoilSheetPanel.lineTopOf] above the line.
class CoilSheetCloseSlot extends StatelessWidget {
  /// Places [child] in the close button's slot.
  const CoilSheetCloseSlot({
    super.key,
    this.side = CoilSheetCloseSide.end,
    this.child = const CoilSheetCloseButton(),
  });

  /// The edge it keeps its distance from.
  final CoilSheetCloseSide side;

  /// The button, a [CoilSheetCloseButton] by default.
  final Widget child;

  /// The square the button is centered in: its hit target (44), or the
  /// button where large text makes it bigger.
  static double extentOf(BuildContext context) => math.max(
    CoilTheme.of(
      context,
    ).metrics.resolve(CoilTier.touch, CoilSize.regular).minHitTarget,
    CoilSheetCloseButton.sizeOf(context),
  );

  /// The space between the slot and the sheet's edges: the corner's center
  /// less half the slot (14 for the default shape).
  static double edgeOf(BuildContext context) => math.max(
    0,
    CoilSheetPanel.headerCenterOf(context) - extentOf(context) / 2,
  );

  @override
  Widget build(BuildContext context) {
    final extent = extentOf(context);
    final edge = edgeOf(context);
    return Padding(
      padding: switch (side) {
        CoilSheetCloseSide.start => EdgeInsetsDirectional.only(start: edge),
        CoilSheetCloseSide.end => EdgeInsetsDirectional.only(end: edge),
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: extent, minHeight: extent),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }
}

/// A sheet's close button: a round, quietly filled ✕ that pops the sheet's
/// route, as dragging it away or tapping the scrim would.
///
/// [CoilSheetPanel] shows one in its header by default. It is the touch
/// tier's compact control height (36) across, grows with the text as its
/// glyph does ([sizeOf]), and takes taps on a square of at least the touch
/// hit target (44). The fill is the secondary button's `tint`, `tintHover`
/// while hovered, and pressing collapses it by 1 px, as coil's buttons do.
/// Tab reaches it; Enter and Space press it. It plays no haptic, like
/// coil's other buttons and the platforms' own close buttons.
class CoilSheetCloseButton extends StatelessWidget {
  /// Creates a sheet's close button.
  const CoilSheetCloseButton({
    super.key,
    this.onPressed,
    this.icon,
    this.semanticLabel = 'Close',
    this.focusNode,
  });

  /// Called on a press; null pops the route with `Navigator.maybePop`,
  /// which a `PopScope` can block.
  final VoidCallback? onPressed;

  /// The glyph; the theme's [CoilIcons.close], else a drawn ✕, when null.
  /// Sized and colored by `IconTheme`.
  final Widget? icon;

  /// The button's name for screen readers.
  final String semanticLabel;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// The diameter of the round button at [context]: the touch tier's
  /// compact control height, grown by as much as the text scale grows its
  /// glyph.
  static double sizeOf(BuildContext context) {
    final compact = CoilTheme.of(
      context,
    ).metrics.resolve(CoilTier.touch, CoilSize.compact);
    final glyph = MediaQuery.textScalerOf(context).scale(compact.iconSize);
    return compact.controlHeight - compact.iconSize + glyph;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final motion = CoilTheme.motionOf(context);
    final compact = theme.metrics.resolve(CoilTier.touch, CoilSize.compact);
    final size = sizeOf(context);
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      child: CoilInteraction(
        onPressed: onPressed ?? () => Navigator.maybePop(context),
        focusNode: focusNode,
        minHitTarget: compact.minHitTarget,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          return CoilFocusRing(
            visible: states.contains(WidgetState.focused),
            borderRadius: BorderRadius.circular(size / 2),
            child: SingleMotionBuilder(
              value: hovered ? 1 : 0,
              motion: hovered ? motion.fade : motion.fadeExit,
              debugLabel: 'CoilSheetCloseButton.hover',
              builder: (context, hover, _) => SingleMotionBuilder(
                value: pressed ? 0 : 1,
                motion: pressed ? motion.quick : motion.standard,
                debugLabel: 'CoilSheetCloseButton.collapse',
                builder: (context, spread, _) {
                  final lit = hover.clamp(0.0, 1.0);
                  return CustomPaint(
                    painter: _CloseFillPainter(
                      color: Color.lerp(colors.tint, colors.tintHover, lit)!,
                      spread: spread.clamp(0.0, 1.0),
                    ),
                    child: SizedBox.square(
                      dimension: size,
                      child: Center(
                        child: IconTheme(
                          data: IconThemeData(
                            size: compact.iconSize,
                            applyTextScaling: true,
                            color: colors.foreground,
                            // A 2 stroke: the ✕ is the button's only
                            // content, and reads as a signifier at 16.
                            weight: CoilIconWeight.emphasis,
                          ),
                          child: icon ?? const CoilIcon(CoilIconRole.close),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The close button's round fill, 1 px inside its bounds plus [spread]
/// (1 at rest, 0 pressed).
class _CloseFillPainter extends CustomPainter {
  _CloseFillPainter({required this.color, required this.spread});

  final Color color;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final box = (Offset.zero & size).deflate(1 - spread);
    canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(
        box,
        Radius.circular(box.shortestSide / 2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CloseFillPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spread != spread;
}
