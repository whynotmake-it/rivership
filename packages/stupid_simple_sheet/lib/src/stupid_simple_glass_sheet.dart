// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/src/glass_sheet_transitions.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A sheet route styled after the iOS 26 liquid glass aesthetic.
///
/// The first sheet of this kind that is pushed applies [barrierColor] to the
/// route behind it; its translucent material blurs layers beneath the sheet
/// while it is floating below its largest detent when [blurSheetMaterial] is
/// true.
///
/// Any subsequent sheet of this kind does not apply a barrier color,
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
    this.dragHandoff = SheetDragHandoff.gestureStart,
    this.snappingConfig = SheetSnappingConfig.full,
    this.draggable = true,
    this.originateAboveBottomViewInset = false,
    this.dismissalMode = DismissalMode.slide,
    this.backgroundSnapshotMode = RouteSnapshotMode.never,
    this.shape = glassShape,
    this.presentationSizing = PresentationSizing.automatic,
    this.blurSheetMaterial = true,

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

  /// How the sheet is sized on screen.
  ///
  /// Mirrors SwiftUI's `presentationSizing`. Defaults to
  /// [PresentationSizing.automatic], which presents as a centered card on
  /// regular-width displays and as an edge-to-edge bottom sheet on compact
  /// displays. Use [PresentationSizing.page] to always present edge-to-edge.
  final PresentationSizing presentationSizing;

  /// Whether the translucent sheet material blurs the layers beneath it while
  /// the sheet is floating below its largest detent.
  ///
  /// Native iOS keeps the revealed backdrop sharp; this only controls the
  /// material covering the sheet region. Defaults to true.
  final bool blurSheetMaterial;

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
  double presentationExtent(BuildContext context) {
    return presentationSizing.maxPresentationExtent(context);
  }

  @override
  Widget buildModalBarrier() {
    // SwiftUI's sheet material is translucent over the sheet region, but the
    // revealed backdrop itself remains sharp. Keep the barrier to dimming only.
    return super.buildModalBarrier();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Builder(
      builder: (context) => MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: child,
      ),
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
          final nextSheet = _nextSheet;
          final resolvedConfig = resolvedSnappingConfig(context);
          final snappingConfigForTransition = nextSheet == null
              ? resolvedConfig
              : nextSheet.resolvedSnappingConfig(context);
          return Padding(
            padding: EdgeInsets.only(
              bottom: originateAboveBottomViewInset
                  ? MediaQuery.viewInsetsOf(context).bottom
                  : 0,
            ),
            child: GlassSheetTransitions.fullTransition(
              context,
              animation: controller!.view,
              secondaryAnimation: secondaryAnimation,
              slideBackRange: nextSheet == null
                  ? snappingConfigForTransition.topTwoPoints
                  : slideBackRangeFor(context, nextSheet),
              opacityRange: snappingConfigForTransition.bottomTwoPoints,
              backgroundColor: backgroundColor,
              secondSheet: _isSecondGlassSheet,
              materialBlur: blurSheetMaterial,
              dismissalMode: dismissalMode,
              shape: shape,
              presentationSizing: presentationSizing,
              child: maybeSnapshotChild(child),
            ),
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
