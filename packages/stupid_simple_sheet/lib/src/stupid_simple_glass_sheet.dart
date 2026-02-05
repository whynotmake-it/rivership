// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/src/glass_sheet_transitions.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A sheet route styled after the iOS 26 liquid glass aesthetic.
///
/// Similar to [StupidSimpleCupertinoSheetRoute] but uses the newer glass-style
/// transitions with a larger default corner radius and no delegated transition
/// to the previous route.
class StupidSimpleGlassSheetRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T>, StupidSimpleSheetController<T> {
  /// Creates a glass-style sheet route for displaying modal content.
  ///
  /// The [child] argument must not be null.
  StupidSimpleGlassSheetRoute({
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
    this.shape = glassShape,
  });

  /// The default glass shape with a 36px superellipse corner radius.
  static const glassShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(36),
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
  /// Defaults to [CupertinoColors.systemBackground].
  final Color backgroundColor;

  /// The widget to display in the sheet.
  final Widget child;

  /// The shape of the sheet.
  ///
  /// Defaults to [glassShape].
  final ShapeBorder shape;

  @override
  Color? get barrierColor =>
      _secondSheet ? null : const Color(0xFF000000).withValues(alpha: .15);

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

  bool _secondSheet = false;

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
          return GlassSheetTransitions.fullTransition(
            context,
            animation: controller!.view,
            secondaryAnimation: secondaryAnimation,
            slideBackRange: effectiveSnappingConfig.topTwoPoints,
            opacityRange: effectiveSnappingConfig.bottomTwoPoints,
            backgroundColor: backgroundColor,
            secondSheet: _secondSheet,
            shape: shape,
            child: child,
          );
        },
      ),
    );
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    return nextRoute is StupidSimpleGlassSheetRoute ||
        super.canTransitionTo(nextRoute);
  }

  @override
  @mustCallSuper
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    if (nextRoute is StupidSimpleGlassSheetRoute) {
      nextRoute._secondSheet = true;
    }
  }

  @override
  @mustCallSuper
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);
  }
}
