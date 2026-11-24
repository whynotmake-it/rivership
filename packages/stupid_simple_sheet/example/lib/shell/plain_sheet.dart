import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A bare [StupidSimpleSheetRoute] with a [SheetBackground] in coil's
/// colors: what `CoilSheetRoute` is built out of, written out.
///
/// The plain route brings the drag, the snapping, the scroll handoff and
/// the keyboard inset, and no look at all; the background gives it the
/// fill and the top corners. Themes are captured from the opener, as
/// coil's own sheet route does, so the content inside keeps the page's
/// theme.
class PlainSheetRoute<T> extends StupidSimpleSheetRoute<T> {
  /// Creates a plain sheet showing [child] on coil's surface.
  PlainSheetRoute({
    required BuildContext context,
    required Widget child,
    super.snappingConfig,
    super.backgroundSnapshotMode,
  }) : super(
         motion: CoilTheme.motionOf(context).gentle,
         barrierColor: CoilTheme.of(context).colors.scrim,
         originateAboveBottomViewInset: true,
         child: _background(context, child),
       );

  static Widget _background(BuildContext context, Widget child) {
    final colors = CoilTheme.of(context).colors;
    final level = math.min(
      CoilSurface.levelOf(context) + CoilSurface.popoverOffset,
      8,
    );
    return InheritedTheme.capture(
      from: context,
      to: Navigator.of(context).context,
    ).wrap(
      // A sheet is a touch surface whatever the tier, like coil's.
      CoilAdaptiveScope(
        tier: CoilTier.touch,
        size: CoilSize.regular,
        child: SheetBackground(
          backgroundColor: colors.surface(level),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(CoilSheetRoute.cornerRadiusOf(context)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
