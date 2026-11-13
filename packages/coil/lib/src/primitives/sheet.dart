import 'dart:math' as math;

import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/widgets.dart';
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
    super.barrierLabel = 'Dismiss',
    super.settings,
  }) : super(
         child: capturedThemes?.wrap(child) ?? child,
         barrierColor: barrierColor,
       );
}

/// The floating panel a [CoilSheetRoute] shows: inset from the screen edges
/// and the home indicator, on a raised surface, with a grabber, an optional
/// [title], then [child].
class CoilSheetPanel extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final media = MediaQuery.of(context);
    const margin = 8.0;
    final radius = BorderRadius.circular(
      theme.shape.container + metrics.popupInset,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        margin + media.padding.left,
        media.padding.top + 48,
        margin + media.padding.right,
        math.max(margin, media.padding.bottom),
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
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
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
                if (title case final title?)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      metrics.popupInset + metrics.itemPaddingX,
                      4,
                      metrics.popupInset + metrics.itemPaddingX,
                      4,
                    ),
                    child: Semantics(
                      header: true,
                      child: DefaultTextStyle(
                        style: theme.typography.style(
                          metrics.caption,
                          weight: .semibold,
                          color: colors.mutedForeground,
                        ),
                        child: title,
                      ),
                    ),
                  ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
