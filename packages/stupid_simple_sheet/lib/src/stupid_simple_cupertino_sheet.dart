// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/src/clamped_animation.dart';
import 'package:stupid_simple_sheet/src/cupertino_sheet_copy.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Simular to [CupertinoSheetRoute] but with the drag gesture improvements from
/// this package.
class StupidSimpleCupertinoSheetRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T> {
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
    this.snappingConfig = const SheetSnappingConfig.relative([1.0]),
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

  @override
  Color? get barrierColor => CupertinoColors.transparent;

  @override
  bool get barrierDismissible => switch (navigator) {
        NavigatorState(:final context) =>
          snappingConfig.resolveWith(context).hasInbetweenSnaps,
        _ => false,
      };

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  final SheetSnappingConfig snappingConfig;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, canSnapshot, child) {
        final height = MediaQuery.sizeOf(context).height;
        return CopiedCupertinoSheetTransitions.secondarySlideDownTransition(
          context,
          animation: animation.clamped,
          secondaryAnimation: secondaryAnimation.clamped,
          slideBackRange: snappingConfig.resolve(height).topTwoPoints,
          opacityRange: snappingConfig.resolve(height).bottomTwoPoints,
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
    final height = MediaQuery.sizeOf(context).height;

    return CupertinoUserInterfaceLevel(
      data: CupertinoUserInterfaceLevelData.elevated,
      child: CopiedCupertinoSheetTransitions.fullTransition(
        context,
        animation: controller!.view,
        secondaryAnimation: secondaryAnimation,
        slideBackRange: snappingConfig.resolve(height).topTwoPoints,
        opacityRange: snappingConfig.resolve(height).bottomTwoPoints,
        backgroundColor: backgroundColor,
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
