import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:motor/motor.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';
import 'package:stupid_simple_sheet/src/clamped_animation.dart';
import 'package:stupid_simple_sheet/src/dismissal_mode.dart';
import 'package:stupid_simple_sheet/src/route_snapshot_mode.dart';
import 'package:stupid_simple_sheet/src/sheet_background.dart';
import 'package:stupid_simple_sheet/src/sheet_constants.dart';
import 'package:stupid_simple_sheet/src/sheet_dismissal_transition.dart';
import 'package:stupid_simple_sheet/src/snapping_point.dart';

export 'package:motor/src/motion.dart';
export 'package:scroll_drag_detector/scroll_drag_detector.dart'
    show ScrollDragBehavior;

export 'src/dismissal_mode.dart';
export 'src/route_snapshot_mode.dart';
export 'src/sheet_background.dart';
export 'src/sheet_dismissal_transition.dart';
export 'src/shrink_transition.dart';
export 'src/snapping_point.dart';
export 'src/stupid_simple_cupertino_sheet.dart';
export 'src/stupid_simple_glass_sheet.dart';

part 'src/sheet_navigator.dart';

/// Controls whether scrolling content can hand an active gesture to its sheet.
enum SheetDragHandoff {
  /// The sheet can only take over when the scrollable was already at its top
  /// boundary when the gesture began.
  gestureStart,

  /// The sheet can take over after the same gesture scrolls the content to its
  /// top boundary.
  continuous,
}

/// A modal route that displays a sheet that slides up from the bottom.
///
/// The sheet can be dismissed by dragging down or by tapping the barrier.
/// When sheet content overrides its [ScrollBehavior], wrap the behavior in
/// [ScrollDragBehavior] so scrolling still hands off to the sheet correctly.
/// The animation supports spring physics for natural motion using the
///
///
/// By default, when a modal route is replaced by another, the previous route
/// remains in memory. To free all the resources when this is not necessary, set
/// [maintainState] to false.
///
/// The type `T` specifies the return type of the route which can be supplied as
/// the route is popped from the stack via [Navigator.pop] when an optional
/// `result` can be provided.
///
/// See also:
///
///  * [StupidSimpleSheetTransitionMixin], for a mixin that provides sheet
/// transition
///    behavior for this modal route.
///  * [CupertinoModalPopupRoute], for a similar iOS-style modal popup.
class StupidSimpleSheetRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T>, StupidSimpleSheetController<T> {
  /// Creates a sheet route for displaying modal content.
  ///
  /// The [motion] and [child] arguments must not be null.
  StupidSimpleSheetRoute({
    required this.child,
    super.settings,
    this.motion = const CupertinoMotion.smooth(snapToEnd: true),
    this.barrierColor = const Color.fromRGBO(0, 0, 0, 0.2),
    this.barrierDismissible = true,
    this.barrierLabel,
    this.clearBarrierImmediately = true,
    this.dragHandoff = SheetDragHandoff.gestureStart,
    this.callNavigatorUserGestureMethods = false,
    this.snappingConfig = SheetSnappingConfig.full,
    this.draggable = true,
    this.originateAboveBottomViewInset = false,
    this.dismissalMode = DismissalMode.slide,
    this.backgroundSnapshotMode = RouteSnapshotMode.never,
    this.mergeable = true,
  });

  @override
  final Motion motion;

  /// The widget to display in the sheet.
  final Widget child;

  /// {@macro mergeable}
  ///
  /// Defaults to true.
  @override
  final bool mergeable;

  @override
  final Color? barrierColor;

  @override
  final bool barrierDismissible;

  @override
  final String? barrierLabel;

  @override
  final bool clearBarrierImmediately;

  @override
  final SheetDragHandoff dragHandoff;

  @override
  final bool callNavigatorUserGestureMethods;

  /// The base snapping configuration for the sheet.
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

  @override
  Widget buildContent(BuildContext context) {
    return child;
  }
}

class _RelativeGestureDetector extends StatefulWidget {
  const _RelativeGestureDetector({
    required this.dragFromTrailingEdge,
    required this.dragHandoff,
    required this.onRelativeDragStart,
    required this.onRelativeDragUpdate,
    required this.onRelativeDragEnd,
    required this.dismissalMode,
    required this.child,
  });

  final bool dragFromTrailingEdge;
  final SheetDragHandoff dragHandoff;
  final VoidCallback onRelativeDragStart;
  // ignore: avoid_positional_boolean_parameters
  final void Function(double delta, double referenceHeight, bool wouldScroll)
      onRelativeDragUpdate;
  // ignore: avoid_positional_boolean_parameters
  final void Function(double velocity, double referenceHeight, bool wouldScroll)
      onRelativeDragEnd;
  final DismissalMode dismissalMode;

  final Widget child;

  @override
  State<_RelativeGestureDetector> createState() =>
      _RelativeGestureDetectorState();
}

class _RelativeGestureDetectorState extends State<_RelativeGestureDetector> {
  double? _referenceHeight;

  @override
  Widget build(BuildContext context) {
    return ScrollDragDetector(
      up: widget.dragFromTrailingEdge
          ? ScrollDragMode.dragFirst
          : ScrollDragMode.none,
      down: switch (widget.dragHandoff) {
        SheetDragHandoff.gestureStart => ScrollDragMode.boundaryStart,
        SheetDragHandoff.continuous => ScrollDragMode.scrollFirst,
      },
      left: ScrollDragMode.none,
      right: ScrollDragMode.none,
      onVerticalDragStart: (details, _) {
        _referenceHeight = SheetDismissalTransition.referenceHeightOf(
          context,
          widget.dismissalMode,
        );
        widget.onRelativeDragStart();
      },
      onVerticalDragEnd: (details, willScroll) {
        if (_referenceHeight case final height?) {
          widget.onRelativeDragEnd(
            details.velocity.pixelsPerSecond.dy / height,
            height,
            willScroll,
          );
        }
        if (!willScroll) {
          _referenceHeight = null;
        }
      },
      onVerticalDragUpdate: (details, wouldScroll) {
        if (_referenceHeight case final height?) {
          widget.onRelativeDragUpdate(
            details.primaryDelta! / height,
            height,
            wouldScroll,
          );
        }
      },
      child: widget.child,
    );
  }
}

/// A mixin that provides sheet transition behavior for a [PopupRoute].
///
/// This mixin handles the slide-up animation, drag gesture detection,
/// and dismissal logic for sheet-style popups.
///
/// The sheet slides in from the bottom and can be dismissed by dragging down
/// or by tapping the barrier. The animation supports spring physics for
/// natural motion.
///
/// See also:
///
///  * [StupidSimpleSheetRoute], which is a [PopupRoute] that leverages this
/// mixin.
mixin StupidSimpleSheetTransitionMixin<T> on PopupRoute<T> {
  /// Builds the primary contents of the sheet.
  @protected
  Widget buildContent(BuildContext context);

  /// The motion configuration for the sheet animation.
  Motion get motion;

  /// How much resistance the sheet should give when the user tries to drag
  /// it past it's fully opened state.
  double get overshootResistance => 100;

  /// {@template clearBarrierImmediately}
  /// Whether this route should clear the modal barrier immediately when
  /// dismissed.
  ///
  /// This can make your app feel more responsive by letting the user interact
  /// with the underlying content, while this sheet is still animating out.
  ///
  /// Defaults to true.
  /// {@endtemplate}
  bool get clearBarrierImmediately => true;

  /// Controls whether scrolling content can hand an active gesture to this
  /// sheet.
  ///
  /// Defaults to [SheetDragHandoff.gestureStart], matching iOS sheet behavior.
  SheetDragHandoff get dragHandoff => SheetDragHandoff.gestureStart;

  /// Whether the sheet can be dragged.
  ///
  /// When false, the sheet cannot be moved by dragging and applies
  /// resistance in both directions, similar to the resistance applied when
  /// dragging past 1.0.
  ///
  /// Defaults to true.
  bool get draggable => true;

  /// Whether the navigator's user gesture methods should be called when
  /// dragging starts and ends.
  ///
  /// Defaults to false.
  bool get callNavigatorUserGestureMethods => false;

  /// Whether the sheet's origin should be moved up by the bottom view inset of
  /// the current [MediaQuery].
  ///
  /// If this is true, and the keyboard is opened, the sheet will originate from
  /// above the keyboard.
  bool get originateAboveBottomViewInset => false;

  /// The mode used to animate the sheet's dismissal.
  ///
  /// [DismissalMode.slide] translates the sheet downward (the default).
  /// [DismissalMode.shrink] shrinks the sheet vertically, clipping overflow
  /// once the child's minimum intrinsic height is reached.
  ///
  /// Defaults to [DismissalMode.slide].
  DismissalMode get dismissalMode => DismissalMode.slide;

  /// Controls when the route behind this sheet is rasterized to a GPU texture.
  ///
  /// When enabled, the previous route's widget tree is replaced with a frozen
  /// image during the configured phases, eliminating rebuild/paint costs.
  ///
  /// Defaults to [RouteSnapshotMode.never].
  ///
  /// To use this, subclasses must also provide a [delegatedTransition] that
  /// wraps the previous route's child in a [SnapshotWidget] using
  /// [backgroundSnapshotController]. See [StupidSimpleSheetRoute] for an
  /// example.
  RouteSnapshotMode get backgroundSnapshotMode => RouteSnapshotMode.never;

  /// {@template mergeable}
  /// Whether this sheet can merge into a sheet it is pushed from, if that
  /// sheet's content is wrapped in a [SheetNavigator].
  ///
  /// If false, this sheet always stacks on top as a separate sheet.
  ///
  /// For more fine-grained control, override [canMergeInto].
  /// {@endtemplate}
  ///
  /// Defaults to false for custom routes. The routes that ship with this
  /// package default to true.
  bool get mergeable => false;

  /// Decides whether this sheet merges into [host] when it is pushed from
  /// within a [SheetNavigator] of [host].
  ///
  /// Defaults to [mergeable].
  ///
  /// Custom routes that return true here must call [buildMergedTransitions]
  /// from their [buildTransitions] if [isMerged] is true, instead of building
  /// their own chrome.
  bool canMergeInto(StupidSimpleSheetTransitionMixin<dynamic> host) =>
      mergeable;

  /// Whether this sheet was merged into another sheet.
  ///
  /// See [SheetNavigator].
  bool get isMerged => _mergeHost != null;

  /// The sheet this sheet was merged into, if any.
  ///
  /// See [SheetNavigator].
  StupidSimpleSheetTransitionMixin<dynamic>? get mergeHost => _mergeHost;

  StupidSimpleSheetTransitionMixin<dynamic>? _mergeHost;

  /// The [SheetNavigator] inside this sheet, if any.
  _SheetNavigatorHostState? _sheetNavigator;

  /// Builds the transition of content inside a [SheetNavigator].
  ///
  /// The [animation] describes how far the content has transitioned in, and
  /// the [secondaryAnimation] how far it has been covered by a merged sheet
  /// above it. The sheet itself resizes along with these animations.
  ///
  /// This is used for merged sheets, as well as for the host's own content,
  /// which is built by the host's implementation.
  ///
  /// By default, the content fades through: outgoing content fades out during
  /// the first part of the transition, and incoming content fades in during
  /// the second part.
  Widget buildMergedTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: ReverseAnimation(
        secondaryAnimation.clamped.remapped(end: 0.6),
      ),
      child: FadeTransition(
        opacity: animation.clamped.remapped(start: 0.4),
        child: child,
      ),
    );
  }

  /// The [SnapshotController] that toggles snapshotting of the background
  /// route.
  ///
  /// Subclasses should pass this to a [SnapshotWidget] wrapping the previous
  /// route's child inside their [delegatedTransition].
  @protected
  SnapshotController get backgroundSnapshotController =>
      _backgroundSnapshotController;

  late final SnapshotController _backgroundSnapshotController =
      SnapshotController();

  /// The [SnapshotController] from the sheet route stacked on top of this one.
  ///
  /// Set automatically when another [StupidSimpleSheetTransitionMixin] route
  /// pushes on top. Used by [maybeSnapshotChild] to wrap this route's content.
  SnapshotController? _coveredBySnapshotController;

  bool _isUserDragging = false;

  @override
  bool get allowSnapshotting =>
      backgroundSnapshotMode != RouteSnapshotMode.never;

  SheetSnappingConfig? _snappingConfigOverride;

  /// The base snapping configuration for the sheet, as provided by the
  /// implementing class.
  ///
  /// This is used as the fallback when no override is set via
  /// [StupidSimpleSheetController.overrideSnappingConfig].
  ///
  /// Defaults to only containing a relative point at 1.0 (fully open).
  ///
  /// A fully closed point of 0.0 is always added implicitly.
  @protected
  SheetSnappingConfig get snappingConfig;

  /// The currently active snapping configuration for the sheet.
  ///
  /// This will return the override if one has been set via
  /// [StupidSimpleSheetController.overrideSnappingConfig], otherwise it returns
  /// [snappingConfig].
  SheetSnappingConfig get effectiveSnappingConfig =>
      _snappingConfigOverride ?? snappingConfig;

  double? _dragEndVelocity;

  double? _animationTargetValue;

  /// Where the sheet should stick if [draggable] is false, or when
  /// overshooting.
  double? _stickingPoint;

  /// Updates [_backgroundSnapshotController] based on the current
  /// [backgroundSnapshotMode], animation state, and drag state.
  void _updateSnapshotState() {
    final mode = backgroundSnapshotMode;

    if (mode == RouteSnapshotMode.never) {
      _backgroundSnapshotController.allowSnapshotting = false;
      return;
    }
    if (mode == RouteSnapshotMode.always) {
      _backgroundSnapshotController.allowSnapshotting = true;
      return;
    }

    final isAnimating = controller?.isAnimating ?? false;
    final value = controller?.value ?? 0.0;
    final isVisible = value > sheetPositionTolerance;
    final isSettled = !isAnimating && !_isUserDragging && isVisible;
    final maxExtent = effectiveSnappingConfig.maxExtent;
    final isFullyOpen = (value - maxExtent).abs() < sheetPositionTolerance;

    final isTargetingMax = _animationTargetValue != null &&
        (_animationTargetValue! - maxExtent).abs() < sheetPositionTolerance;

    final isMovingForward = isTargetingMax &&
        ((controller?.status.isAnimating ?? false) ||
            (_animationTargetValue! > value));

    _backgroundSnapshotController.allowSnapshotting = switch (mode) {
      RouteSnapshotMode.animating => isAnimating || _isUserDragging,
      RouteSnapshotMode.settled => isSettled,
      RouteSnapshotMode.openAndForward => (isSettled && isFullyOpen) ||
          (isAnimating && isMovingForward && !_isUserDragging),
      _ => false, // never/always handled above
    };
  }

  @override
  Duration get transitionDuration => switch (motion) {
        CurvedMotion(:final duration) => duration,
        CupertinoMotion(:final duration) => duration,
        _ => const Duration(milliseconds: 500),
      };

  @override
  Animation<double>? get animation => super.animation?.clamped;

  @override
  Animation<double>? get secondaryAnimation =>
      super.secondaryAnimation?.clamped;

  @override
  bool get opaque => isMerged || super.opaque;

  @override
  void install() {
    super.install();
    _mergeHost?._sheetNavigator?._controller.register(this, controller!);
  }

  @override
  Simulation? createSimulation({required bool forward}) {
    if (isMerged) {
      // Merged sheets only transition their content, so they always go all
      // the way in or out.
      return motion.createSimulation(
        start: controller?.value ?? 0,
        end: forward ? 1 : 0,
      );
    }

    final v = _dragEndVelocity;
    _dragEndVelocity = null;

    // Get the appropriate end value
    double endValue;
    if (forward) {
      // Opening: use initial snap point or default
      endValue = effectiveSnappingConfig.initialSnap;
    } else {
      // Closing
      endValue = 0.0;
    }
    _animationTargetValue = endValue;
    _stickingPoint = endValue;
    _updateSnapshotState();
    return motion.createSimulation(
      end: endValue,
      start: animation?.value ?? 0,
      velocity: -(v ?? 0),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    if (isMerged) {
      // The host takes care of gestures, we only need to be measured.
      return _SheetPageBoundary(route: this, child: buildContent(context));
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => MediaQuery.removeViewInsets(
        context: context,
        removeBottom: originateAboveBottomViewInset,
        // ^ The sheet is already moved up by the bottom view inset, so we make
        // sure the content inside the sheet doesn't add extra padding
        child: _RelativeGestureDetector(
          dismissalMode: dismissalMode,
          dragHandoff: dragHandoff,
          dragFromTrailingEdge: (_animationTargetValue ?? animation.value) <
              effectiveSnappingConfig.maxExtent,
          onRelativeDragStart: () => _handleDragStart(context),
          onRelativeDragUpdate: (relativeDelta, referenceHeight, wouldScroll) =>
              _handleDragUpdate(
            context,
            relativeDelta,
            referenceHeight,
            wouldScroll,
          ),
          onRelativeDragEnd: (relativeVelocity, referenceHeight, willScroll) =>
              _handleDragEnd(
            context,
            relativeVelocity,
            referenceHeight,
            willScroll,
          ),
          child: child!,
        ),
      ),
      child: buildContent(context),
    );
  }

  @override
  AnimationController createAnimationController() {
    assert(
      !debugTransitionCompleted(),
      'Cannot reuse a $runtimeType after disposing it.',
    );
    final duration = transitionDuration;
    final reverseDuration = reverseTransitionDuration;
    final animationController = AnimationController.unbounded(
      duration: duration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
      vsync: navigator!,
    )..addStatusListener((_) => _updateSnapshotState());
    return animationController;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (isMerged) {
      return buildMergedTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: SheetDismissalTransition(
            animation: controller!,
            dismissalMode: dismissalMode,
            child: child,
          ),
        ),
        if (originateAboveBottomViewInset)
          SizedBox(
            height: MediaQuery.viewInsetsOf(context).bottom,
          ),
      ],
    );
  }

  final _poppedNotifier = ValueNotifier(false);

  @override
  Widget buildModalBarrier() {
    if (isMerged) {
      // The host's barrier is already in place. This one only keeps the
      // content below from being interacted with while transitioning.
      return const ModalBarrier(dismissible: false);
    }
    return ValueListenableBuilder(
      valueListenable: _poppedNotifier,
      builder: (context, value, child) {
        return IgnorePointer(
          ignoring: value && clearBarrierImmediately,
          child: _buildBarrier(),
        );
      },
    );
  }

  /// Same as [ModalRoute.buildModalBarrier], but with nested navigation,
  /// tapping it dismisses the whole sheet instead of only popping the topmost
  /// merged sheet.
  Widget _buildBarrier() {
    final color = barrierColor;
    if (color != null && color.a != 0 && !offstage) {
      return AnimatedModalBarrier(
        color: animation!.drive(
          ColorTween(
            begin: color.withValues(alpha: 0),
            end: color,
          ).chain(CurveTween(curve: barrierCurve)),
        ),
        dismissible: barrierDismissible,
        semanticsLabel: barrierLabel,
        barrierSemanticsDismissible: semanticsDismissible,
        onDismiss: _handleBarrierDismiss,
      );
    }
    return ModalBarrier(
      dismissible: barrierDismissible,
      semanticsLabel: barrierLabel,
      barrierSemanticsDismissible: semanticsDismissible,
      onDismiss: _handleBarrierDismiss,
    );
  }

  void _handleBarrierDismiss() {
    if (_sheetNavigator == null) {
      // What ModalBarrier does by default.
      navigator?.maybePop().ignore();
    } else {
      _dismissSheet();
    }
  }

  /// Dismisses this sheet, including all merged sheets, unless something
  /// blocks it.
  void _dismissSheet() {
    switch (_dismissDisposition) {
      case RoutePopDisposition.pop:
        navigator?.pop();
      case RoutePopDisposition.doNotPop:
        _notifyDismissBlocked();
      case RoutePopDisposition.bubble:
        break;
    }
  }

  /// Whether the sheet as a whole can be dismissed by the user, e.g. by
  /// dragging it closed.
  ///
  /// Unlike [popDisposition], this ignores merged sheets that could be popped
  /// first, but respects any [PopScope] inside of them.
  RoutePopDisposition get _dismissDisposition {
    for (final route in _sheetNavigator?._routes ?? <ModalRoute<dynamic>>[]) {
      if (route.popDisposition == RoutePopDisposition.doNotPop) {
        return RoutePopDisposition.doNotPop;
      }
    }
    return super.popDisposition;
  }

  /// Notifies whoever blocked a dismissal of this sheet, like
  /// [NavigatorState.maybePop] would.
  void _notifyDismissBlocked() {
    final sheetNavigator = _sheetNavigator;
    if (sheetNavigator == null) {
      navigator?.maybePop().ignore();
      return;
    }
    for (final route in sheetNavigator._routes.toList().reversed) {
      if (route.popDisposition == RoutePopDisposition.doNotPop) {
        route.onPopInvokedWithResult(false, null);
        return;
      }
    }
    super.onPopInvokedWithResult(false, null);
  }

  @override
  RoutePopDisposition get popDisposition {
    final sheetNavigator = _sheetNavigator;
    if (sheetNavigator != null) {
      // Let the nested navigator handle back navigation first.
      if (sheetNavigator._canPopNested) return RoutePopDisposition.doNotPop;
      if (sheetNavigator._rootRoute.popDisposition ==
          RoutePopDisposition.doNotPop) {
        return RoutePopDisposition.doNotPop;
      }
    }
    return super.popDisposition;
  }

  @override
  void onPopInvokedWithResult(bool didPop, T? result) {
    final sheetNavigator = _sheetNavigator;
    if (sheetNavigator != null) {
      if (!didPop && sheetNavigator._canPopNested) {
        sheetNavigator._navigator?.maybePop().ignore();
        return;
      }
      // Notify PopScopes in this sheet's content, which are registered with
      // the first page of the nested navigator.
      sheetNavigator._rootRoute.onPopInvokedWithResult(didPop, null);
    }
    super.onPopInvokedWithResult(didPop, result);
  }

  @override
  @mustCallSuper
  bool didPop(T? result) {
    _poppedNotifier.value = true;
    _updateSnapshotState();
    return super.didPop(result);
  }

  void _handleDragStart(
    BuildContext context,
  ) {
    _isUserDragging = true;
    _updateSnapshotState();
    if (callNavigatorUserGestureMethods) {
      navigator?.didStartUserGesture();
    }
  }

  void _handleDragUpdate(
    BuildContext context,
    double delta,
    double referenceHeight,
    bool wouldScroll,
  ) {
    if (_poppedNotifier.value) return;
    final currentValue = controller?.value ?? 0;
    var adjustedDelta = delta;

    final maxExtent = effectiveSnappingConfig.maxExtent;

    final minSnap = effectiveSnappingConfig.minExtent;
    final cannotPop = _dismissDisposition != RoutePopDisposition.pop;
    final belowMinAndCannotPop =
        cannotPop && currentValue < minSnap && delta > 0;

    final applyResistance =
        !draggable || currentValue > maxExtent || belowMinAndCannotPop;

    if (wouldScroll && (currentValue - delta) > maxExtent) {
      // If the scrollable would scroll, and the sheet will be dragged past its
      // max, we don't allow that.
      adjustedDelta = currentValue - maxExtent;
    } else if (applyResistance && delta != 0) {
      final stickingPoint = _stickingPoint ?? 1.0;
      // Reduce the delta with diminishing returns (resistance)

      final overshoot = (stickingPoint - currentValue).abs();

      final resistance = 1.0 /
          (1.0 + overshoot * overshootResistance); // Exponential resistance

      adjustedDelta = delta * resistance;
    }

    final newValue = currentValue - adjustedDelta;

    controller?.value = newValue;
    _animationTargetValue = newValue;
  }

  void _handleDragEnd(
    BuildContext context,
    double velocity,
    double referenceHeight,
    bool willScroll,
  ) {
    _isUserDragging = false;
    if (callNavigatorUserGestureMethods) {
      navigator?.didStopUserGesture();
    }

    // If the route has been popped, don't interfere with the closing animation
    if (_poppedNotifier.value) return;

    // The scrollable is taking over this gesture. Keep the sheet where it is
    // until a later drag segment ends without handing control back.
    if (willScroll) {
      _dragEndVelocity = null;
      _updateSnapshotState();
      return;
    }

    final currentValue = controller!.value;
    _dragEndVelocity = velocity;

    final maxExtent = effectiveSnappingConfig.maxExtent;

    final minSnap = effectiveSnappingConfig.minExtent;
    final routePopDisposition = _dismissDisposition;
    final cannotPop = routePopDisposition != RoutePopDisposition.pop;
    final belowMinAndCannotPop = cannotPop && currentValue < minSnap;

    if (draggable && routePopDisposition == RoutePopDisposition.doNotPop) {
      final attemptedTarget = effectiveSnappingConfig.findTargetSnapPoint(
        position: currentValue,
        relativeVelocity: -velocity,
        absoluteVelocity: -velocity * referenceHeight,
      );
      if (attemptedTarget <= sheetPositionTolerance) {
        _notifyDismissBlocked();
      }
    }

    // If dragged past fully open, or below min snap when route can't pop,
    // snap back to the appropriate point
    if (currentValue > maxExtent || !draggable || belowMinAndCannotPop) {
      final stickingPoint = _stickingPoint ?? maxExtent;
      final snapTarget = currentValue > maxExtent ? maxExtent : stickingPoint;
      // Scale the velocity by the same resistance factor that was applied
      // during dragging
      final overshoot = (currentValue - stickingPoint).abs();
      final resistance = 1.0 / (maxExtent + overshoot * overshootResistance);
      final adjustedVelocity = velocity * resistance;

      final backSim = motion.createSimulation(
        start: currentValue,
        end: snapTarget,
        velocity: -adjustedVelocity,
      );
      controller!.animateWith(backSim);
      _dragEndVelocity = null;
    } else {
      // Find the target snap point based on position and velocity
      final targetValue =
          _animationTargetValue = effectiveSnappingConfig.findTargetSnapPoint(
        position: currentValue,
        relativeVelocity: -velocity,
        absoluteVelocity: -velocity * referenceHeight,
        includeClosed: routePopDisposition == RoutePopDisposition.pop,
      );

      _stickingPoint = targetValue;

      // If target is 0 (closed), dismiss the sheet
      if (targetValue <= sheetPositionTolerance) {
        navigator?.pop();
      } else {
        // Animate to the target snap point
        final snapSim = motion.createSimulation(
          start: currentValue,
          end: targetValue,
          velocity: -_dragEndVelocity!,
        );
        controller!.animateWith(snapSim);
        _dragEndVelocity = null;
      }
    }
    _updateSnapshotState();
  }

  /// Wraps [child] in a [SnapshotWidget] if another sheet route with
  /// snapshotting is stacked on top of this one.
  ///
  /// Call this in [buildTransitions] around the content that should be
  /// snapshotted when covered by another sheet. Returns [child] unchanged
  /// when no snapshotting is active.
  @protected
  Widget maybeSnapshotChild(Widget child) {
    final controller = _coveredBySnapshotController;
    if (controller == null) return child;
    return SnapshotWidget(
      controller: controller,
      mode: SnapshotMode.permissive,
      autoresize: true,
      child: child,
    );
  }

  @override
  @mustCallSuper
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    if (nextRoute is StupidSimpleSheetTransitionMixin && nextRoute.isMerged) {
      // Merged sheets only replace our content, they never transition us via
      // delegation or snapshot us.
      // ignore: invalid_use_of_visible_for_testing_member
      receivedTransition = null;
      _coveredBySnapshotController = null;
    } else if (nextRoute is StupidSimpleSheetTransitionMixin) {
      _coveredBySnapshotController = nextRoute._backgroundSnapshotController;
    } else {
      _coveredBySnapshotController = null;
    }
  }

  @override
  @mustCallSuper
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);
    _coveredBySnapshotController = null;
  }

  @override
  @mustCallSuper
  void dispose() {
    _mergeHost?._sheetNavigator?._controller.unregister(this);
    _backgroundSnapshotController.dispose();
    _poppedNotifier.dispose();
    super.dispose();
  }
}

/// A mixin that provides imperative control over a sheet's animation.
///
/// Mix this into your [PopupRoute] that also uses
/// [StupidSimpleSheetTransitionMixin] to allow children of the sheet to
/// imperatively control the sheet's position.
mixin StupidSimpleSheetController<T> on StupidSimpleSheetTransitionMixin<T> {
  /// Retrieves the current [StupidSimpleSheetController] from the given
  /// [BuildContext].
  ///
  /// This will only work if called from a context that is inside the
  /// [StupidSimpleSheetRoute].
  static StupidSimpleSheetController<T>? maybeOf<T>(BuildContext context) {
    final route = switch (ModalRoute.of(context)) {
      // Inside a sheet with nested navigation, the content is hosted by the
      // first page of the nested navigator.
      _SheetNavigatorRootRoute(:final host) => host,
      final route => route,
    };
    if (route case final StupidSimpleSheetController<T> route) {
      return route;
    }

    return null;
  }

  /// Can be used to imperatively animate the sheet to a relative position, but
  /// can't close it.
  ///
  /// The [relativePosition] must be larger than 0.0 (fully closed) and
  /// lower than or equal to 1.0 (fully open).
  ///
  /// If [snap] is true, the sheet will snap to the nearest snapping point
  /// after reaching the target position.
  ///
  /// If you want to close the sheet, use [Navigator.pop] instead.
  ///
  /// If this sheet [isMerged], this controls the sheet it was merged into.
  TickerFuture animateToRelative(double relativePosition, {bool snap = false}) {
    if (_mergeHost case final StupidSimpleSheetController<dynamic> host) {
      return host.animateToRelative(relativePosition, snap: snap);
    }
    assert(
      relativePosition > 0.0 && relativePosition <= 1.0,
      'Relative position must be larger than 0.0 and less than or equal to 1.0',
    );

    assert(
      controller != null,
      'Controller is null. Make sure the route is pushed before calling.',
    );

    // We only animate if this route is still current
    if (!isCurrent) return TickerFuture.complete();

    final double target;

    if (snap) {
      // Find the closest snapping point that isn't 0.0
      final config = effectiveSnappingConfig;

      target = switch (config.findClosestSnapPoint(relativePosition)) {
        0.0 => config.points.first,
        final v => v,
      };
    } else {
      target = relativePosition;
    }

    final simulation = motion.createSimulation(
      start: controller!.value,
      end: target,
      velocity: controller!.velocity,
    );

    _animationTargetValue = target;
    _stickingPoint = target;
    return controller!.animateWith(simulation);
  }

  /// Updates the snapping configuration to an override for the sheet.
  ///
  /// If this sheet [isMerged], this updates the sheet it was merged into.
  ///
  /// Pass `null` to [newConfig] to reset the configuration to the one
  /// originally passed to the route constructor.
  ///
  /// If [animateToComply] is `true`, the sheet will immediately animate to
  /// comply with the new snapping configuration. This will snap the sheet to
  /// the nearest valid snapping point in the new configuration.
  ///
  /// Example:
  /// ```dart
  /// // Update to a new configuration and animate to comply
  /// controller.updateSheetSnappingConfig(
  ///   SheetSnappingConfig([0.3, 0.6, 1.0]),
  ///   animateToComply: true,
  /// );
  ///
  /// // Reset to the original configuration
  /// controller.updateSheetSnappingConfig(null);
  /// ```
  TickerFuture overrideSnappingConfig(
    SheetSnappingConfig? newConfig, {
    bool animateToComply = false,
  }) {
    if (_mergeHost case final StupidSimpleSheetController<dynamic> host) {
      return host.overrideSnappingConfig(
        newConfig,
        animateToComply: animateToComply,
      );
    }
    assert(
      controller != null,
      'Controller is null. Make sure the route is pushed before calling.',
    );

    _snappingConfigOverride = newConfig;

    // Only animate to comply if requested and if this route is still current
    if (animateToComply && isCurrent) {
      final currentPosition = controller!.value;

      // Find the nearest snapping point in the new configuration
      final targetPosition =
          effectiveSnappingConfig.findClosestSnapPoint(currentPosition);

      // If the current position is already at a valid snap point, don't animate
      if ((targetPosition - currentPosition).abs() < sheetPositionTolerance) {
        return TickerFuture.complete();
      }

      final simulation = motion.createSimulation(
        start: currentPosition,
        end: targetPosition,
        velocity: controller!.velocity,
      );

      _animationTargetValue = targetPosition;
      _stickingPoint = targetPosition;

      return controller!.animateWith(simulation);
    }

    return TickerFuture.complete();
  }
}
