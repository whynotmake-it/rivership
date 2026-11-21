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
    ),
    this.clearBarrierImmediately = true,
    this.backgroundColor = CupertinoColors.systemBackground,
    this.callNavigatorUserGestureMethods = false,
    this.dragHandoff = SheetDragHandoff.gestureStart,
    this.snappingConfig = SheetSnappingConfig.full,
    this.draggable = true,
    this.originateAboveBottomViewInset = false,
    this.dismissalMode = DismissalMode.slide,
    this.backgroundSnapshotMode = RouteSnapshotMode.never,
    this.shape = iOS18Shape,
    this.presentationSizing = PresentationSizing.automatic,
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

  /// How the sheet is sized on screen.
  ///
  /// Mirrors SwiftUI's `presentationSizing`. Defaults to
  /// [PresentationSizing.automatic], which presents as a centered card on
  /// regular-width displays and as an edge-to-edge bottom sheet on compact
  /// displays. Use [PresentationSizing.page] to always present edge-to-edge.
  final PresentationSizing presentationSizing;

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
  final SheetDragHandoff dragHandoff;

  @override
  final SheetSnappingConfig snappingConfig;

  @override
  final bool draggable;

  @override
  final bool originateAboveBottomViewInset;

  @override
  final DismissalMode dismissalMode;

  @override
  final RouteSnapshotMode backgroundSnapshotMode;

  @override
  double presentationExtent(BuildContext context) {
    return presentationSizing.maxPresentationExtent(context);
  }

  bool _isSecondCupertinoSheet = false;

  StupidSimpleSheetTransitionMixin<dynamic>? _nextSheet;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, canSnapshot, child) {
        final nextSheet = _nextSheet;
        final snappingConfigForTransition = nextSheet == null
            ? resolvedSnappingConfig(context)
            : nextSheet.resolvedSnappingConfig(context);

        return CopiedCupertinoSheetTransitions.secondarySlideDownTransition(
          context,
          animation: animation.clamped,
          secondaryAnimation: secondaryAnimation.clamped,
          slideBackRange: nextSheet == null
              ? snappingConfigForTransition.topTwoPoints
              : slideBackRangeFor(context, nextSheet),
          opacityRange: snappingConfigForTransition.bottomTwoPoints,
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
            slideBackRange: _nextSheet == null
                ? resolvedSnappingConfig(context).topTwoPoints
                : slideBackRangeFor(context, _nextSheet!),
            opacityRange: resolvedSnappingConfig(context).bottomTwoPoints,
            backgroundColor: backgroundColor,
            dismissalMode: dismissalMode,
            shape: shape,
            presentationSizing: presentationSizing,
            secondSheet: _isSecondCupertinoSheet,
            child: maybeSnapshotChild(child),
          );
        },
      ),
    );
  }

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    _isSecondCupertinoSheet = previousRoute is StupidSimpleCupertinoSheetRoute;
    super.didChangePrevious(previousRoute);
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

    if (nextRoute is StupidSimpleSheetTransitionMixin) {
      _nextSheet = nextRoute;
    } else {
      _nextSheet = null;
    }

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
