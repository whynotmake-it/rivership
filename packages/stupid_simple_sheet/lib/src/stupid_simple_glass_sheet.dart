// ignore_for_file: avoid_positional_boolean_parameters

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/src/glass_sheet_transitions.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A sheet route styled after the iOS 26 liquid glass aesthetic.
///
/// The first sheet of this kind that is pushed will blur the backdrop (if
/// [blurBehindBarrier] is true) and apply [barrierColor] to the route behind.
///
/// Any subsequent sheet of this kind will not apply a barrier color or blur,
/// since the previous sheet will transition using its own internal secondary
/// transition.
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
    this.backgroundSnapshotMode = RouteSnapshotMode.never,
    this.shape = glassShape,
    this.blurBehindBarrier = true,

    /// The color applied to the route behind the first glass sheet.
    ///
    /// This barrier color is only used for the first pushed glass sheet; any
    /// subsequent sheets rely on the previous sheet's internal transition and
    /// do not apply an additional barrier.
    ///
    /// Defaults to black with 15% opacity.
    Color barrierColor =
        const Color.from(alpha: .15, red: 0, green: 0, blue: 0),
  }) : _barrierColor = barrierColor;

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

  /// Whether the first sheet will blur the backdrop when it appears.
  ///
  /// Defaults to true.
  final bool blurBehindBarrier;

  final Color _barrierColor;

  @override
  Color? get barrierColor => _isSecondGlassSheet ? null : _barrierColor;

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
      backgroundSnapshotMode == RouteSnapshotMode.never
          ? null
          : (context, animation, secondaryAnimation, canSnapshot, child) {
              return SnapshotWidget(
                controller: backgroundSnapshotController,
                mode: SnapshotMode.permissive,
                autoresize: true,
                child: child,
              );
            };

  bool _isSecondGlassSheet = false;

  StupidSimpleSheetTransitionMixin<dynamic>? _nextSheet;

  @override
  Widget buildModalBarrier() {
    return Stack(
      children: [
        super.buildModalBarrier(),
        if (blurBehindBarrier && !_isSecondGlassSheet)
          Positioned.fill(
            child: ValueListenableBuilder(
              valueListenable: animation ?? kAlwaysDismissedAnimation,
              builder: (context, value, child) {
                final sigma = value * 10;
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
      ],
    );
  }

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
          final snappingConfigForTransition =
              _nextSheet?.effectiveSnappingConfig ?? effectiveSnappingConfig;
          return GlassSheetTransitions.fullTransition(
            context,
            animation: controller!.view,
            secondaryAnimation: secondaryAnimation,
            slideBackRange: snappingConfigForTransition.topTwoPoints,
            opacityRange: snappingConfigForTransition.bottomTwoPoints,
            backgroundColor: backgroundColor,
            secondSheet: _isSecondGlassSheet,
            shape: shape,
            child: maybeSnapshotChild(child),
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
  void didChangePrevious(Route<dynamic>? previousRoute) {
    _isSecondGlassSheet = previousRoute is StupidSimpleGlassSheetRoute;
    super.didChangePrevious(previousRoute);
  }

  @override
  @mustCallSuper
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);

    if (nextRoute is StupidSimpleSheetTransitionMixin) {
      _nextSheet = nextRoute;
    } else {
      _nextSheet = null;
    }

    if (nextRoute is StupidSimpleGlassSheetRoute) {
      // Force the internal secondary transition instead of the delegated one,
      // so this sheet's own scale-down/slide-up animation plays correctly.
      // ignore: invalid_use_of_visible_for_testing_member
      receivedTransition = null;
    }
  }

  @override
  @mustCallSuper
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);
    if (nextRoute is StupidSimpleGlassSheetRoute) {
      // ignore: invalid_use_of_visible_for_testing_member
      receivedTransition = null;
    }
  }
}
