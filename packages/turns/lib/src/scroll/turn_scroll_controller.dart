import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// What [TurnScrollController.scrollTo] and
/// [TurnScrollController.scrollToBottom] return: a [Future] of whether the
/// scroll arrived cleanly, which completes once the motion has settled, and
/// [ended], which completes as soon as the motion's duration has passed.
///
/// A spring keeps settling for a while after it looks done. Await [ended] to
/// follow up when the scroll *looks* finished (highlight the target, open a
/// keyboard), and the future itself when it must have come to rest.
///
/// ```dart
/// final flight = controller.scrollTo(messageId);
/// if (await flight.ended) highlight(messageId);
/// ```
class TurnScrollFuture implements Future<bool> {
  /// Wraps `settled`, which completes when the flight comes to rest, with the
  /// [ended] future of the same flight.
  TurnScrollFuture(this._settled, {required this.ended});

  /// A flight that is already over, as when nothing could be scrolled.
  TurnScrollFuture.value({required bool arrived})
    : _settled = Future.value(arrived),
      ended = Future.value(arrived);

  final Future<bool> _settled;

  /// Completes with `true` once the motion's perceived duration has passed
  /// (the motor [MotionFuture.ended] of the flight), even while a spring is
  /// still settling, or with `false` if the flight was interrupted or
  /// superseded before then.
  ///
  /// Jumps and instant motions end when they land. A flight that retargets
  /// on the way (offscreen rows measuring in) ends with its last motion.
  final Future<bool> ended;

  @override
  Stream<bool> asStream() => _settled.asStream();

  @override
  Future<bool> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => _settled.catchError(onError, test: test);

  @override
  Future<R> then<R>(
    // Future's own signature.
    // ignore: avoid_positional_boolean_parameters
    FutureOr<R> Function(bool value) onValue, {
    Function? onError,
  }) => _settled.then(onValue, onError: onError);

  @override
  Future<bool> timeout(
    Duration timeLimit, {
    FutureOr<bool> Function()? onTimeout,
  }) => _settled.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<bool> whenComplete(FutureOr<void> Function() action) =>
      _settled.whenComplete(action);
}

/// Delegate connecting [TurnScrollController] to its attached scroll view.
abstract interface class TurnScrollDelegate {
  /// Scrolls to where the bottom was when called.
  ///
  /// When [motion] is non-null, it overrides the scroll view's
  /// `autoScrollMotion` for this flight (while still respecting reduced motion
  /// via `MediaQuery.disableAnimationsOf`).
  ///
  /// Returns `true` if the scroll arrived cleanly at the bottom, or `false` if
  /// interrupted by a user gesture, superseded by another programmatic scroll,
  /// or unable to scroll (e.g. empty list or detached position).
  Future<bool> scrollToBottom({required bool animate, Motion? motion});

  /// Scrolls to the item identified by [itemId].
  ///
  /// When [motion] is non-null, it overrides the scroll view's
  /// `autoScrollMotion` for this flight (while still respecting reduced motion
  /// via `MediaQuery.disableAnimationsOf`).
  ///
  /// Returns `true` if the scroll arrived cleanly on [itemId], or `false` if
  /// interrupted by a user gesture, superseded by another programmatic scroll,
  /// or [itemId] was not found.
  Future<bool> scrollTo(
    Object itemId, {
    required double alignment,
    required bool animate,
    Motion? motion,
  });

  /// Called immediately whenever the user initiates any scroll gesture
  /// (touch drag, mouse wheel, trackpad, scrollbar, or keyboard).
  void onUserScroll();

  /// Called synchronously during [ScrollPosition.applyContentDimensions] so
  /// initial positioning, center shifts, and keyboard-inset anchoring can
  /// adjust pixels without a 1-frame flash.
  double? adjustPixelsOnDimensions({
    required double pixels,
    required double minScrollExtent,
    required double maxScrollExtent,
    required double viewportDimension,
  });

  /// Called whenever scroll metrics or pixels change so `isAwayFromBottom` and
  /// `distanceFromBottom` stay current.
  void onMetricsChanged(double pixels, double maxScrollExtent);
}

/// Controls a `TurnScrollView` or `CustomTurnScrollView`, extending
/// [ScrollController] so the same instance can be passed to scrollbars or
/// scroll-area wrappers.
class TurnScrollController extends ScrollController {
  /// Creates a turn scroll controller.
  TurnScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  final _isAwayFromBottom = ValueNotifier<bool>(false);
  final _distanceFromBottom = ValueNotifier<double>(0);
  final _isPinActive = ValueNotifier<bool>(false);
  final _isAutoScrolling = ValueNotifier<bool>(false);
  TurnScrollDelegate? _delegate;
  var _disposed = false;
  var _notifyScheduled = false;
  double _pendingDistanceBottom = 0;
  double _pendingThreshold = 160;
  bool _pendingPinActive = false;
  bool _pendingAutoScrolling = false;

  /// Whether the viewport is more than `jumpThreshold` above the bottom.
  ///
  /// Always reflects the true distance (`distanceFromBottom > jumpThreshold`),
  /// including during programmatic scroll flights. Compose with
  /// [isAutoScrolling] (`isAwayFromBottom.value && !isAutoScrolling.value`) to
  /// hide scroll-to-bottom controls while an automatic scroll is in flight.
  ValueListenable<bool> get isAwayFromBottom => _isAwayFromBottom;

  /// Distance in logical pixels from the current scroll offset to
  /// `maxScrollExtent`.
  ValueListenable<double> get distanceFromBottom => _distanceFromBottom;

  /// Whether the attached view's `pinnedId` currently owns auto-pinning
  /// (cleared immediately on any user scroll or when `pinnedId` is cleared).
  ValueListenable<bool> get isPinActive => _isPinActive;

  /// Whether the attached view is currently executing a programmatic scroll
  /// flight (`scrollTo`, `scrollToBottom`, active `pinnedId` scroll, or
  /// initial bottom positioning).
  ///
  /// Clears immediately upon arrival or any user scroll gesture.
  ValueListenable<bool> get isAutoScrolling => _isAutoScrolling;

  /// Attaches the owning view's delegate. Internal to turn scroll views.
  void attachDelegate(TurnScrollDelegate delegate) {
    _delegate = delegate;
    for (final position in positions) {
      if (position is TurnScrollPosition) {
        position.delegate = delegate;
      }
    }
  }

  /// Detaches the owning view's delegate. Internal to turn scroll views.
  void detachDelegate(TurnScrollDelegate delegate) {
    if (!identical(_delegate, delegate)) return;
    _delegate = null;
    for (final position in positions) {
      if (position is TurnScrollPosition) {
        position.delegate = null;
      }
    }
  }

  /// Updates the observable bottom-distance notifiers. Internal to turn scroll
  /// views.
  void updateBottomDistance(double distance, {required double threshold}) {
    if (_disposed) return;
    _pendingDistanceBottom = math.max(0, distance);
    _pendingThreshold = threshold;
    _scheduleOrApplyNotifiers();
  }

  /// Updates [isPinActive]. Internal to turn scroll views.
  void updatePinActive({required bool active}) {
    if (_disposed) return;
    _pendingPinActive = active;
    _scheduleOrApplyNotifiers();
  }

  /// Updates [isAutoScrolling]. Internal to turn scroll views.
  void updateAutoScrolling({required bool active}) {
    if (_disposed) return;
    _pendingAutoScrolling = active;
    _scheduleOrApplyNotifiers();
  }

  void _scheduleOrApplyNotifiers() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        if (!_disposed) _applyNotifiers();
      });
      return;
    }
    _applyNotifiers();
  }

  void _applyNotifiers() {
    if ((_distanceFromBottom.value - _pendingDistanceBottom).abs() > 0.5) {
      _distanceFromBottom.value = _pendingDistanceBottom;
    }
    final away = _pendingDistanceBottom > _pendingThreshold;
    // Update isAutoScrolling before isAwayFromBottom when entering an auto
    // scroll, and after isAwayFromBottom when leaving one, so listeners on
    // Listenable.merge([isAwayFromBottom, isAutoScrolling]) never observe a
    // transient (away: true, autoScrolling: false) intermediate state.
    if (_pendingAutoScrolling && !_isAutoScrolling.value) {
      _isAutoScrolling.value = true;
    }
    if (_isAwayFromBottom.value != away) {
      _isAwayFromBottom.value = away;
    }
    if (!_pendingAutoScrolling && _isAutoScrolling.value) {
      _isAutoScrolling.value = false;
    }
    if (_isPinActive.value != _pendingPinActive) {
      _isPinActive.value = _pendingPinActive;
    }
  }

  /// Smoothly scrolls to where the bottom was when called.
  ///
  /// When the last item is virtualized/offscreen, the spring converges across
  /// unmeasured items as they lay out and freezes as soon as the last item
  /// lays out, so newly streaming tokens never cause jittery chasing.
  ///
  /// Pass [motion] to override the scroll view's `autoScrollMotion` for this
  /// flight. Under `MediaQuery.disableAnimationsOf(context)`, the transition
  /// always jumps instantaneously.
  ///
  /// Returns `true` if the scroll arrived cleanly at the bottom, or `false` if
  /// interrupted by a user scroll, superseded by another navigation call, or
  /// the list is empty / unattached.
  ///
  /// The returned [TurnScrollFuture] also has [TurnScrollFuture.ended], which
  /// completes when the motion looks finished rather than when it settles.
  TurnScrollFuture scrollToBottom({bool animate = true, Motion? motion}) =>
      _fly(() => _delegate?.scrollToBottom(animate: animate, motion: motion));

  /// Scrolls to the item identified by [itemId], even if it is currently
  /// offscreen/virtualized.
  ///
  /// [alignment] `0.0` aligns the item's top to the usable top edge (below
  /// `padding.top` + safe area and any pinned/sticky header); `1.0` aligns its
  /// bottom to the usable bottom edge; `0.5` centers it.
  ///
  /// Pass [motion] to override the scroll view's `autoScrollMotion` for this
  /// flight. Under `MediaQuery.disableAnimationsOf(context)`, the transition
  /// always jumps instantaneously.
  ///
  /// Returns `true` if the scroll arrived cleanly on [itemId], or `false` if
  /// interrupted by a user scroll, superseded by another navigation call, or
  /// [itemId] was not found.
  ///
  /// The returned [TurnScrollFuture] also has [TurnScrollFuture.ended], which
  /// completes when the motion looks finished rather than when it settles.
  TurnScrollFuture scrollTo(
    Object itemId, {
    double alignment = 0,
    bool animate = true,
    Motion? motion,
  }) => _fly(
    () => _delegate?.scrollTo(
      itemId,
      alignment: alignment,
      animate: animate,
      motion: motion,
    ),
  );

  /// Runs one navigation and collects the `ended` of whichever motion the
  /// view starts for it (possibly frames later, after a recenter).
  TurnScrollFuture _fly(Future<bool>? Function() start) {
    final ended = Completer<bool>();
    for (final position in positions) {
      if (position is TurnScrollPosition) position.endedSink = ended;
    }
    final settled = start();
    if (settled == null) {
      ended.complete(false);
      return TurnScrollFuture.value(arrived: false);
    }
    final result = settled.then((arrived) {
      // Jumps, instant motions and early exits end when they land.
      if (!ended.isCompleted) ended.complete(arrived);
      for (final position in positions) {
        if (position is TurnScrollPosition &&
            identical(position.endedSink, ended)) {
          position.endedSink = null;
        }
      }
      return arrived;
    });
    return TurnScrollFuture(result, ended: ended.future);
  }

  /// Cancels any active pin or programmatic scroll animation immediately.
  void cancelAutoScroll() {
    _delegate?.onUserScroll();
    for (final pos in positions) {
      if (pos is TurnScrollPosition) {
        pos.cancelTargetTracking();
      }
    }
  }

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    if (position is TurnScrollPosition) {
      position.delegate = _delegate;
    }
  }

  @override
  void detach(ScrollPosition position) {
    if (position is TurnScrollPosition &&
        identical(position.delegate, _delegate)) {
      position.delegate = null;
    }
    super.detach(position);
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => TurnScrollPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
    delegate: _delegate,
  );

  @override
  void dispose() {
    _disposed = true;
    for (final position in positions) {
      if (position is TurnScrollPosition &&
          identical(position.delegate, _delegate)) {
        position.delegate = null;
      }
    }
    _delegate = null;
    _isAwayFromBottom.dispose();
    _distanceFromBottom.dispose();
    _isPinActive.dispose();
    _isAutoScrolling.dispose();
    super.dispose();
  }
}

/// Custom [ScrollPosition] backing [TurnScrollController].
///
/// Intercepts all user-initiated scroll gestures (including desktop/web mouse
/// wheel & trackpad via [pointerScroll]), applies synchronous pixel adjustments
/// during [applyContentDimensions] without 1-frame flashes, and hosts
/// [TargetTrackingScrollActivity] for live-target Motor spring scrolling.
class TurnScrollPosition extends ScrollPositionWithSingleContext {
  /// Creates the scroll position.
  TurnScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
    this.delegate,
  });

  /// Owning view delegate.
  TurnScrollDelegate? delegate;

  /// Receives the `ended` of the next flight this position starts, for the
  /// [TurnScrollFuture] of the navigation that is underway.
  Completer<bool>? endedSink;

  var _applyingDimensions = false;

  /// Runs a live-target Motor spring activity toward [resolveTarget].
  ///
  /// Automatically cancels if the user starts dragging, wheeling, or scrolling.
  /// Returns `true` if the spring settled cleanly on the target, or `false` if
  /// interrupted or unresolvable.
  Future<bool> animateToTarget({
    required double? Function() resolveTarget,
    required Motion motion,
    TickerProvider? vsync,
  }) {
    if (!hasPixels || !hasContentDimensions) return Future.value(false);
    final initialTarget = resolveTarget();
    if (initialTarget == null) return Future.value(false);
    final clamped = initialTarget.clamp(minScrollExtent, maxScrollExtent);
    if ((pixels - clamped).abs() <= 0.5) {
      if (pixels != clamped) jumpTo(clamped);
      return Future.value(true);
    }
    final activity = TargetTrackingScrollActivity(
      this,
      initialPixels: pixels,
      initialTarget: clamped,
      resolveTarget: resolveTarget,
      motion: motion,
      vsync: vsync ?? context.vsync,
    );
    final sink = endedSink;
    if (sink != null) {
      endedSink = null;
      unawaited(
        activity.ended.then((value) {
          if (!sink.isCompleted) sink.complete(value);
        }),
      );
    }
    beginActivity(activity);
    activity.start();
    return activity.done;
  }

  /// Whether a [TargetTrackingScrollActivity] is currently driving this
  /// position.
  bool get isTrackingTarget => activity is TargetTrackingScrollActivity;

  /// Stops an active [TargetTrackingScrollActivity] without moving pixels.
  void cancelTargetTracking() {
    if (isTrackingTarget) {
      goIdle();
    }
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    final wasTracking = isTrackingTarget;
    // Disengage auto-pinning for any external or user-driven activity
    // (keyboard springs, scrollbar drags, fling ballistics, etc.).
    // Ignore activities started internally during applyContentDimensions (such
    // as BouncingScrollPhysics goBallistic while layout is converging).
    if (!_applyingDimensions &&
        newActivity != null &&
        newActivity is! IdleScrollActivity &&
        newActivity is! TargetTrackingScrollActivity) {
      delegate?.onUserScroll();
    }
    super.beginActivity(newActivity);
    if (wasTracking != isTrackingTarget && hasPixels && hasContentDimensions) {
      delegate?.onMetricsChanged(pixels, maxScrollExtent);
    }
  }

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    delegate?.onUserScroll();
    return super.hold(holdCancelCallback);
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    delegate?.onUserScroll();
    return super.drag(details, dragCancelCallback);
  }

  @override
  void pointerScroll(double delta) {
    if (delta != 0) {
      delegate?.onUserScroll();
    }
    super.pointerScroll(delta);
    if (hasPixels && hasContentDimensions) {
      delegate?.onMetricsChanged(pixels, maxScrollExtent);
    }
  }

  @override
  Future<void> moveTo(
    double to, {
    Duration? duration,
    Curve? curve,
    bool? clamp = true,
  }) {
    // External calls (Scrollable.ensureVisible, keyboard shortcuts, scrollbar
    // track taps) always disengage auto-pinning cleanly.
    delegate?.onUserScroll();
    return super.moveTo(to, duration: duration, curve: curve, clamp: clamp);
  }

  @override
  void correctBy(double correction) {
    super.correctBy(correction);
    if (activity case final TargetTrackingScrollActivity tracking) {
      tracking.shiftBy(correction);
    }
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (_applyingDimensions) {
      return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
    }
    _applyingDimensions = true;
    try {
      // Capture pixels BEFORE super clamps it to [min, max], so bottom-edge
      // deltas (e.g. keyboard closing) don't double-subtract an already-clamped
      // offset.
      final preClampPixels = hasPixels ? pixels : null;
      final result = super.applyContentDimensions(
        minScrollExtent,
        maxScrollExtent,
      );
      if (hasPixels && hasViewportDimension) {
        final adjusted = delegate?.adjustPixelsOnDimensions(
          pixels: preClampPixels ?? pixels,
          minScrollExtent: minScrollExtent,
          maxScrollExtent: maxScrollExtent,
          viewportDimension: viewportDimension,
        );
        if (adjusted != null) {
          final clamped = adjusted.clamp(minScrollExtent, maxScrollExtent);
          if ((clamped - pixels).abs() > 0.5) {
            final shift = clamped - pixels;
            correctPixels(clamped);
            if (activity case final TargetTrackingScrollActivity tracking) {
              tracking.shiftBy(shift);
            } else if (activity is BallisticScrollActivity) {
              // Cancel any overscroll ballistic started by super before we
              // snapped pixels back in-bounds.
              goIdle();
            }
            delegate?.onMetricsChanged(pixels, maxScrollExtent);
            return false;
          }
        }
        delegate?.onMetricsChanged(pixels, maxScrollExtent);
      }
      return result;
    } finally {
      _applyingDimensions = false;
    }
  }

  @override
  double setPixels(double newPixels) {
    final overscroll = super.setPixels(newPixels);
    if (hasPixels && hasContentDimensions) {
      delegate?.onMetricsChanged(pixels, maxScrollExtent);
    }
    return overscroll;
  }

  @override
  void jumpTo(double value) {
    super.jumpTo(value);
    if (hasPixels && hasContentDimensions) {
      delegate?.onMetricsChanged(pixels, maxScrollExtent);
    }
  }
}

/// A [ScrollActivity] driven by a Motor [SingleMotionController] that smoothly
/// tracks a live [resolveTarget] callback (retargeting with preserved velocity
/// when virtualized extents refine) and disposes cleanly on any user scroll.
class TargetTrackingScrollActivity extends ScrollActivity {
  /// Creates the activity.
  TargetTrackingScrollActivity(
    TurnScrollPosition super.delegate, {
    required double initialPixels,
    required double initialTarget,
    required this.resolveTarget,
    required Motion motion,
    required TickerProvider vsync,
  }) : _target = initialTarget,
       _position = delegate {
    _controller =
        SingleMotionController(
            motion: motion,
            vsync: vsync,
            initialValue: initialPixels,
          )
          ..addListener(_tick)
          ..addStatusListener(_onStatus);
  }

  final TurnScrollPosition _position;

  /// Callback queried each tick to resolve the live scroll offset target.
  final double? Function() resolveTarget;

  late final SingleMotionController _controller;
  final _completer = Completer<bool>();
  final _ended = Completer<bool>();

  /// The motor future of the latest retarget; only its `ended` counts.
  MotionFuture? _flight;
  double _target;
  var _disposed = false;
  var _retargeting = false;

  /// Completes with `true` when the scroll arrives cleanly, or `false` when
  /// interrupted or unresolvable.
  Future<bool> get done => _completer.future;

  /// Completes with `true` once the motion's perceived duration has passed
  /// (the latest retarget's [MotionFuture.ended]), even while it is still
  /// settling, or `false` if interrupted before then.
  Future<bool> get ended => _ended.future;

  @override
  bool get shouldIgnorePointer => false;

  @override
  bool get isScrolling => true;

  @override
  double get velocity => _disposed ? 0 : _controller.velocity;

  /// Begins driving the spring after [ScrollPosition.beginActivity] has
  /// installed this activity.
  void start() {
    if (_disposed) return;
    _retarget(_target);
    // Synchronous motions (such as Motion.instant()) settle immediately without
    // firing a status transition if moving downward from `dismissed`.
    if (!_disposed && !_controller.isAnimating) {
      if (_position.hasContentDimensions) {
        final clamped = _target.clamp(
          _position.minScrollExtent,
          _position.maxScrollExtent,
        );
        if ((clamped - _position.pixels).abs() > 0.01) {
          delegate.setPixels(clamped);
        }
      }
      _finish(arrived: true);
    }
  }

  /// Shifts both the active spring value and target into a new coordinate frame
  /// when layout emits a `scrollOffsetCorrection` or center shift mid-scroll.
  void shiftBy(double delta) {
    if (_disposed || delta == 0) return;
    final velocity = _controller.velocity;
    final nextValue = _controller.value + delta;
    final nextTarget = _target + delta;
    _retarget(nextTarget, from: nextValue, withVelocity: velocity);
  }

  void _retarget(double nextTarget, {double? from, double? withVelocity}) {
    _target = nextTarget;
    _retargeting = true;
    try {
      final flight = _flight = _controller.animateTo(
        nextTarget,
        from: from,
        withVelocity: withVelocity,
      );
      unawaited(
        flight.ended.then((_) {
          if (identical(_flight, flight) && !_ended.isCompleted) {
            _ended.complete(true);
          }
        }),
      );
    } finally {
      _retargeting = false;
    }
  }

  void _tick() {
    if (_disposed || _retargeting || !_position.hasContentDimensions) return;
    final raw = resolveTarget();
    if (raw == null) {
      _finish(arrived: false);
      return;
    }
    final clamped = raw.clamp(
      _position.minScrollExtent,
      _position.maxScrollExtent,
    );
    if ((clamped - _target).abs() > 0.5) {
      _retarget(clamped);
    }
    // Preserve smooth pull-back when starting from BouncingScrollPhysics
    // overscroll while preventing the spring from pushing past the legal range.
    final minAllowed = math.min(_position.minScrollExtent, _position.pixels);
    final maxAllowed = math.max(_position.maxScrollExtent, _position.pixels);
    final next = _controller.value.clamp(minAllowed, maxAllowed);
    delegate.setPixels(next);
  }

  void _onStatus(AnimationStatus status) {
    if (_disposed || _retargeting) return;
    // Directional SingleMotionController settles as `completed` when moving up
    // and `dismissed` when moving down — handle both settled states.
    if (!status.isAnimating) {
      var arrived = false;
      if (_position.hasContentDimensions) {
        // Apply the settled controller value before checking whether the live
        // target moved (Motor fires status listeners before value listeners on
        // completion, so a linear/curved motion's final step would otherwise
        // look > 1px short and spuriously restart).
        final minAllowed = math.min(
          _position.minScrollExtent,
          _position.pixels,
        );
        final maxAllowed = math.max(
          _position.maxScrollExtent,
          _position.pixels,
        );
        final settled = _controller.value.clamp(minAllowed, maxAllowed);
        if ((settled - _position.pixels).abs() > 0.01) {
          delegate.setPixels(settled);
        }
        final raw = resolveTarget();
        if (raw != null) {
          final clamped = raw.clamp(
            _position.minScrollExtent,
            _position.maxScrollExtent,
          );
          if ((clamped - _position.pixels).abs() > 1) {
            _retarget(clamped, from: _position.pixels);
            if (!_disposed && _controller.isAnimating) return;
          }
          if ((clamped - _position.pixels).abs() > 0.01) {
            delegate.setPixels(clamped);
          }
          arrived = true;
        }
      }
      _finish(arrived: arrived);
    }
  }

  void _finish({required bool arrived}) {
    if (_disposed) return;
    if (!_ended.isCompleted) _ended.complete(arrived);
    if (!_completer.isCompleted) _completer.complete(arrived);
    delegate.goIdle();
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _controller
        ..removeListener(_tick)
        ..removeStatusListener(_onStatus)
        ..dispose();
      if (!_ended.isCompleted) _ended.complete(false);
      if (!_completer.isCompleted) _completer.complete(false);
    }
    super.dispose();
  }
}
