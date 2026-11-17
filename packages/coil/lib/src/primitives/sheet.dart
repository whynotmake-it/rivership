import 'dart:math' as math;

import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/shape.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/surface.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// coil's sheet: `stupid_simple_sheet`'s glass sheet (drag to dismiss,
/// scroll handoff, a blurred backdrop, stacking) in coil's colors.
///
/// `context` is read once, while the route is created, for:
///
/// - the motion: the theme's `gentle`, both in and out (a drag that
///   dismisses hands its fling velocity to it);
/// - the fill: the surface two levels above the one `context` sits on
///   (`CoilSurface.popoverOffset`), which [child] sits on too;
/// - the top corners: the glass sheet's 36 for the `rounded` and `pill`
///   shapes, scaled down with tighter shapes;
/// - the themes [child] inherits.
///
/// The scrim is the glass sheet's own: the first sheet blurs the page and
/// dims it with black at 15%, in light and dark mode alike.
///
/// A sheet opened from another sheet stacks on it: the one below shrinks
/// back and only the first blurs and dims the page. The sheet rides above
/// the keyboard. Wider than [maxWidth], it centers.
///
/// Put a [CoilSheetPanel] in it for the grabber, an optional title and the
/// safe area.
class CoilSheetRoute<T> extends StupidSimpleGlassSheetRoute<T> {
  /// Creates a sheet route showing [child] (usually a [CoilSheetPanel]).
  ///
  /// With [barrierDismissible] false, tapping the scrim and pressing Esc
  /// don't close it; dragging and back still do unless [child] blocks them
  /// with a `PopScope`.
  CoilSheetRoute({
    required BuildContext context,
    required Widget child,
    this.barrierDismissible = true,
    this.barrierLabel,
    CoilMotion? motion,
    super.settings,
  }) : super(
         motion: CoilTheme.motionOf(context, override: motion).gentle,
         backgroundColor: CoilTheme.of(context).colors.surface(
           CoilSurface.levelOf(context) + CoilSurface.popoverOffset,
         ),
         shape: RoundedSuperellipseBorder(
           borderRadius: BorderRadius.vertical(
             top: Radius.circular(_radiusOf(context)),
           ),
         ),
         originateAboveBottomViewInset: true,
         child:
             InheritedTheme.capture(
               from: context,
               to: Navigator.of(context).context,
             ).wrap(
               CoilSurface.scope(
                 offset: CoilSurface.popoverOffset,
                 child: child,
               ),
             ),
       );

  /// The widest a sheet gets; wider windows center it.
  static const maxWidth = 560.0;

  /// The glass sheet's corner for coil's default shape, scaled with the
  /// theme's touch container radius and capped at the glass sheet's.
  static double _radiusOf(BuildContext context) {
    const glass = 36.0;
    final container = CoilTheme.of(
      context,
    ).shape.radii(CoilTier.touch).container;
    final rounded = CoilShape.rounded.touch.container;
    return math.min(glass, glass * container / rounded);
  }

  @override
  final bool barrierDismissible;

  @override
  final String? barrierLabel;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
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
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: sheet,
        ),
      ),
    );
  }
}

/// The content layout of a [CoilSheetRoute]: a grabber, an optional
/// [title], then [child], clear of the home indicator and side insets.
///
/// A hairline under the header shows only while [child]'s scrollable has
/// content scrolled beneath it (read from its scroll notifications), and
/// fades on the theme's `fade` / `fadeExit`.
class CoilSheetPanel extends StatefulWidget {
  /// Creates a sheet panel.
  const CoilSheetPanel({required this.child, super.key, this.title});

  /// An optional heading.
  final Widget? title;

  /// The contents, usually a list.
  final Widget child;

  /// The scrim behind coil's unblurred modal surfaces at [context]
  /// (centered and drawer dialogs, `CoilDrawer`): black at 20% in light
  /// mode and 30% in dark mode, where black dims less.
  ///
  /// Sheets don't use it: a [CoilSheetRoute] keeps the glass sheet's own
  /// scrim, black at 15% over a blur, and without the blur a dialog needs
  /// a little more to stand off the page.
  static Color barrierColorOf(BuildContext context) =>
      CoilTheme.of(context).brightness == Brightness.dark
      ? const Color.from(alpha: 0.3, red: 0, green: 0, blue: 0)
      : const Color.from(alpha: 0.2, red: 0, green: 0, blue: 0);

  @override
  State<CoilSheetPanel> createState() => _CoilSheetPanelState();
}

class _CoilSheetPanelState extends State<CoilSheetPanel> {
  /// Whether content is scrolled beneath the header.
  bool _scrolledUnder = false;

  bool _onScroll(ScrollMetrics metrics, int depth) {
    // Only the sheet's own list, not scrollables nested inside rows.
    if (depth != 0 || metrics.axis != Axis.vertical) return false;
    final under = metrics.extentBefore > 0;
    if (under != _scrolledUnder) setState(() => _scrolledUnder = under);
    return false;
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
          // The scroll-edge hairline: painted over the top of the content,
          // so showing it never shifts layout.
          Flexible(
            child: SingleMotionBuilder(
              value: _scrolledUnder ? 1 : 0,
              motion: _scrolledUnder
                  ? CoilTheme.motionOf(context).fade
                  : CoilTheme.motionOf(context).fadeExit,
              debugLabel: 'CoilSheetPanel.hairline',
              builder: (context, hairline, child) => DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colors.border.withValues(
                        alpha: colors.border.a * hairline.clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
                child: child,
              ),
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
        ],
      ),
    );
  }
}
