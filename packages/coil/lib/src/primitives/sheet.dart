import 'dart:math' as math;

import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/foundation/typography.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// coil's sheet: a `stupid_simple_sheet` route (drag to dismiss, scroll
/// handoff, Motor-driven) with coil's chrome.
///
/// [motion] is the theme's `gentle` spring. `stupid_simple_sheet` uses one
/// motion for both directions and keeps the drag's fling velocity when it
/// dismisses, so the exit uses [motion] too. A separate exit spring needs an
/// `exitMotion` hook upstream (see the coil README, "Known gaps").
class CoilSheetRoute<T> extends StupidSimpleSheetRoute<T> {
  /// Creates a sheet route showing [child] (usually a [CoilSheetPanel]).
  CoilSheetRoute({
    required Widget child,
    required super.motion,
    required Color barrierColor,
    CapturedThemes? capturedThemes,
    super.barrierLabel,
    super.barrierDismissible,
    super.settings,
  }) : super(
         child: capturedThemes?.wrap(child) ?? child,
         barrierColor: barrierColor,
       );
}

/// The floating panel a [CoilSheetRoute] shows: inset from the screen edges
/// and the home indicator, on a raised surface, with a grabber, an optional
/// [title], then [child].
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

  /// The scrim behind sheets at [context]: black at 40% in both modes (a
  /// light scrim over a dark UI would read as a flash, not a dimming).
  static Color barrierColorOf(BuildContext context) =>
      CoilTheme.of(context).brightness == Brightness.dark
      ? const Color(0x80000000)
      : const Color(0x66000000);

  /// The heading's type step: one step above touch body (16/22), the size
  /// of an iOS headline, at semibold.
  static const titleStep = CoilTypeStep(17, 22);

  /// The widest a sheet gets; wider windows center it.
  static const maxWidth = 560.0;

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
    final metrics = theme.metrics.resolve(CoilTier.touch, CoilSize.regular);
    final media = MediaQuery.of(context);
    const margin = 8.0;
    // The container radius: concentric with the rows, which sit
    // popupInset in.
    final radius = BorderRadius.circular(
      theme.shape.radii(CoilTier.touch).container,
    );
    // Title text starts where row text starts.
    final textInset = metrics.popupInset + metrics.itemPaddingX;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        margin + media.padding.left,
        media.padding.top + 48,
        margin + media.padding.right,
        math.max(margin, media.padding.bottom),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: CoilSheetPanel.maxWidth,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.surface(3),
              shadows: colors.shadow(3),
              shape: RoundedSuperellipseBorder(borderRadius: radius),
            ),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: colors.insetRing(3),
                ),
              ),
              child: ClipRSuperellipse(
                borderRadius: radius,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 6),
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
                            style: theme.typography.style(
                              CoilSheetPanel.titleStep,
                              weight: .semibold,
                              color: colors.foreground,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            child: title,
                          ),
                        ),
                      ),
                    // The scroll-edge hairline: painted over the top of the
                    // content, so showing it never shifts layout.
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
                                  alpha:
                                      colors.border.a *
                                      hairline.clamp(0.0, 1.0),
                                ),
                              ),
                            ),
                          ),
                          child: child,
                        ),
                        child: NotificationListener<ScrollMetricsNotification>(
                          onNotification: (n) => _onScroll(n.metrics, n.depth),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) =>
                                _onScroll(n.metrics, n.depth),
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
