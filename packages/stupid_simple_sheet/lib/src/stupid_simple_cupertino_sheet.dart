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
      duration: Duration(milliseconds: 400),
      snapToEnd: true,
    ),
    this.clearBarrierImmediately = true,
    this.snappingPoints = const [
      SnappingPoint.relative(1),
    ],
    this.initialSnap,
  }) : super();

  @override
  final Motion motion;

  @override
  final bool clearBarrierImmediately;

  /// The widget to display in the sheet.
  final Widget child;

  @override
  Color? get barrierColor => CupertinoColors.transparent;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  final List<SnappingPoint> snappingPoints;

  @override
  final SnappingPoint? initialSnap;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, canSnapshot, child) =>
          CopiedCupertinoSheetTransitions.secondarySlideDownTransition(
            context,
            animation: animation.clamped,
            secondaryAnimation: secondaryAnimation.clamped,
            slideBackRange: _getTopTwoSnapPoints(context),
            opacityRange: _getOpacityRange(context),
            child: child,
          );

  @override
  Widget buildContent(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: CupertinoUserInterfaceLevel(
        data: CupertinoUserInterfaceLevelData.elevated,
        child: child,
      ),
    );
  }

  (double, double) _getTopTwoSnapPoints(BuildContext context) {
    final lastSnapPoint = snappingPoints.isNotEmpty
        ? snappingPoints.last
        : const SnappingPoint.relative(1);

    final secondLastSnapPoint = snappingPoints.length > 1
        ? snappingPoints[snappingPoints.length - 2]
        : const SnappingPoint.relative(0);

    final height = MediaQuery.sizeOf(context).height;

    return (
      secondLastSnapPoint.toRelative(height),
      lastSnapPoint.toRelative(height),
    );
  }

  (double, double) _getOpacityRange(BuildContext context) {
    final firstSnapPoint = snappingPoints.isNotEmpty
        ? snappingPoints.first
        : const SnappingPoint.relative(0);

    final secondSnapPoint = snappingPoints.length > 1
        ? snappingPoints[1]
        : const SnappingPoint.relative(1);

    final height = MediaQuery.sizeOf(context).height;

    return (
      firstSnapPoint.toRelative(height),
      secondSnapPoint.toRelative(height),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CopiedCupertinoSheetTransitions.fullTransition(
      context,
      animation: animation.clamped,
      secondaryAnimation: secondaryAnimation.clamped,
      slideBackRange: _getTopTwoSnapPoints(context),
      opacityRange: _getOpacityRange(context),
      child: child,
    );
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    return nextRoute is StupidSimpleCupertinoSheetRoute;
  }

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    if (nextRoute is StupidSimpleCupertinoSheetRoute) {
      // ignore: invalid_use_of_visible_for_testing_member
      receivedTransition = null;
    }
  }

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);
    if (nextRoute is StupidSimpleCupertinoSheetRoute) {
      // ignore: invalid_use_of_visible_for_testing_member
      receivedTransition = null;
    }
  }
}
