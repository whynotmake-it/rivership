// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/src/clamped_animation.dart';
import 'package:stupid_simple_sheet/src/cupertino_sheet_copy.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Simular to [CupertinoSheetRoute] but with the drag gesture improvements from
/// this package.
class StupidSimpleCupertinoSheetRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T>, StupidSimpleSheetController<T> {
  /// Creates a sheet route for displaying modal content.
  ///
  /// The [motion] and [child] arguments must not be null.
  StupidSimpleCupertinoSheetRoute({
    required this.child,
    super.settings,
    this.motion = const CupertinoMotion.smooth(
      duration: Duration(milliseconds: 350),
      snapToEnd: true,
    ),
    this.clearBarrierImmediately = true,
    this.backgroundColor = CupertinoColors.systemBackground,
    this.callNavigatorUserGestureMethods = false,
    this.snappingConfig = SheetSnappingConfig.full,
    this.draggable = true,
    this.originateAboveBottomViewInset = false,
    this.topRadius = const Radius.circular(12),
  });

  @override
  double get overshootResistance => 5000;

  @override
  final Motion motion;

  @override
  final bool clearBarrierImmediately;

  /// The background color of the sheet.
  ///
  /// Will default [CupertinoColors.secondarySystemBackground] if not provided.
  final Color backgroundColor;

  /// The widget to display in the sheet.
  final Widget child;

  /// The border radius of the sheet's top corners when it first appears.
  ///
  /// Defaults to `Radius.circular(12.0)`. The radius when another
  /// sheet is pushed on top\ will be this value divided by 1.5 (8 by default).
  final Radius topRadius;

  @override
  Color? get barrierColor => CupertinoColors.transparent;

  @override
  bool get barrierDismissible => switch (navigator) {
        NavigatorState(:final context) =>
          effectiveSnappingConfig.resolveWith(context).hasInbetweenSnaps,
        _ => false,
      };

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  final bool callNavigatorUserGestureMethods;

  @override
  final SheetSnappingConfig snappingConfig;

  @override
  final bool draggable;

  @override
  final bool originateAboveBottomViewInset;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, canSnapshot, child) {
        final resolvedConfig = effectiveSnappingConfig.resolveWith(context);
        return CopiedCupertinoSheetTransitions.secondarySlideDownTransition(
          context,
          animation: animation.clamped,
          secondaryAnimation: secondaryAnimation.clamped,
          slideBackRange: resolvedConfig.topTwoPoints,
          opacityRange: resolvedConfig.bottomTwoPoints,
          borderRadius: topRadius,
          child: child,
        );
      };

  @override
  Widget buildContent(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: child,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final resolvedConfig = effectiveSnappingConfig.resolveWith(context);
    return CupertinoUserInterfaceLevel(
      data: CupertinoUserInterfaceLevelData.elevated,
      child: CopiedCupertinoSheetTransitions.fullTransition(
        context,
        animation: controller!.view,
        secondaryAnimation: secondaryAnimation,
        slideBackRange: resolvedConfig.topTwoPoints,
        opacityRange: resolvedConfig.bottomTwoPoints,
        backgroundColor: backgroundColor,
        borderRadius: topRadius,
        child: child,
      ),
    );
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    return nextRoute is StupidSimpleCupertinoSheetRoute ||
        super.canTransitionTo(nextRoute);
  }

  @override
  @mustCallSuper
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);

    // This is a hack for forcing the internal secondary transition instead
    if (nextRoute is StupidSimpleCupertinoSheetRoute) {
      // ignore: invalid_use_of_visible_for_testing_member
      receivedTransition = null;
    }
  }

  @override
  @mustCallSuper
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);

    // This is a hack for forcing the internal secondary transition instead
    if (nextRoute is StupidSimpleCupertinoSheetRoute) {
      // ignore: invalid_use_of_visible_for_testing_member
      receivedTransition = null;
    }
  }
}
