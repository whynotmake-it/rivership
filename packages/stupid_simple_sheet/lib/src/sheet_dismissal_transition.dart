import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/src/dismissal_mode.dart';
import 'package:stupid_simple_sheet/src/shrink_transition.dart';

/// A widget that animates its child based on a [DismissalMode] and an
/// [Animation<double>].
///
/// This is the public building block used by `StupidSimpleSheetTransitionMixin`
/// to drive the sheet's enter/exit transition. It can also be used standalone
/// to build custom sheet-like transitions.
///
/// The [animation] value is expected to go from 0.0 (fully dismissed) to 1.0
/// (fully presented). Values above 1.0 are supported for spring overshoot.
///
/// In [DismissalMode.slide] mode, the child is translated vertically using
/// [FractionalTranslation].
///
/// In [DismissalMode.shrink] mode, the child's visible height is reduced via
/// [ShrinkTransition], clipping at the child's minimum intrinsic height.
class SheetDismissalTransition extends StatelessWidget {
  /// Creates a sheet dismissal transition.
  const SheetDismissalTransition({
    required this.animation,
    required this.dismissalMode,
    required this.child,
    super.key,
  });

  /// Returns the reference height for the given [dismissalMode], which is
  /// used to normalize drag deltas consistently regardless of the actual
  /// child's size.
  static double? referenceHeightOf(
    BuildContext context,
    DismissalMode dismissalMode,
  ) {
    return switch (dismissalMode) {
      DismissalMode.shrink => ShrinkTransition.referenceHeightOf(context),
      DismissalMode.slide =>
        (context.size ?? MediaQuery.sizeOf(context)).height,
    };
  }

  /// The animation driving the transition.
  ///
  /// A value of 0.0 means fully dismissed; 1.0 means fully presented.
  /// Values above 1.0 are supported for spring overshoot.
  final Animation<double> animation;

  /// The mode used to animate the dismissal.
  final DismissalMode dismissalMode;

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = animation.value;
        return switch (dismissalMode) {
          DismissalMode.slide => FractionalTranslation(
              translation: Offset(0, 1 - value),
              child: child,
            ),
          DismissalMode.shrink => ShrinkTransition(
              sizeFactor: math.max(0, value),
              child: child,
            ),
        };
      },
    );
  }
}
