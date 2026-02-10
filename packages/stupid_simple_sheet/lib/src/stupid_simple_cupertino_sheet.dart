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
    this.backgroundSnapshotMode = RouteSnapshotMode.never,
    this.shape = iOS18Shape,
  });

  /// The default iOS 18 shape for sheet controllers.
  static const iOS18Shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(12),
    ),
  );

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

  /// The shape of the sheet.
  ///
  /// Defaults to [iOS18Shape].
  final ShapeBorder shape;

  @override
  Color? get barrierColor => CupertinoColors.transparent;

  @override
  bool get barrierDismissible => effectiveSnappingConfig.hasInbetweenSnaps;

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
  final RouteSnapshotMode backgroundSnapshotMode;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, canSnapshot, child) {
        return CopiedCupertinoSheetTransitions.secondarySlideDownTransition(
          context,
          animation: animation.clamped,
          secondaryAnimation: secondaryAnimation.clamped,
          slideBackRange: effectiveSnappingConfig.topTwoPoints,
          opacityRange: effectiveSnappingConfig.bottomTwoPoints,
          primaryShape: shape,
          child: SnapshotWidget(
            controller: backgroundSnapshotController,
            mode: SnapshotMode.permissive,
            autoresize: true,
            child: child,
          ),
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
    return CupertinoUserInterfaceLevel(
      data: CupertinoUserInterfaceLevelData.elevated,
      child: Builder(
        builder: (context) {
          return CopiedCupertinoSheetTransitions.fullTransition(
            context,
            animation: controller!.view,
            secondaryAnimation: secondaryAnimation,
            slideBackRange: effectiveSnappingConfig.topTwoPoints,
            opacityRange: effectiveSnappingConfig.bottomTwoPoints,
            backgroundColor: backgroundColor,
            shape: shape,
            child: maybeSnapshotChild(child),
          );
        },
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

    // Force the internal secondary transition instead of the delegated one,
    // so this sheet's own scale-down/slide-up animation plays correctly.
    if (nextRoute is StupidSimpleCupertinoSheetRoute) {
      // ignore: invalid_use_of_visible_for_testing_member
      receivedTransition = null;
    }
  }

  @override
  @mustCallSuper
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);

    if (nextRoute is StupidSimpleCupertinoSheetRoute) {
      // ignore: invalid_use_of_visible_for_testing_member
      receivedTransition = null;
    }
  }
}
