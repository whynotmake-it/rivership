import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Delegate connecting [TurnScrollController] to its attached scroll view.
abstract interface class TurnScrollDelegate {
  /// Scrolls to where the bottom was when called.
  Future<void> jumpToBottom({required bool animate});

  /// Scrolls to the item identified by [itemId].
  Future<void> scrollTo(
    Object itemId, {
    required double alignment,
    required bool animate,
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

  /// Called whenever scroll metrics or pixels change so `isAwayFromBottom`
  /// stays current.
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
  TurnScrollDelegate? _delegate;
  var _disposed = false;
  var _notifyScheduled = false;
  double _pendingDistance = 0;
  double _pendingThreshold = 160;

  /// Whether the viewport is more than `jumpThreshold` above the bottom.
  ValueListenable<bool> get isAwayFromBottom => _isAwayFromBottom;

  /// Distance in logical pixels from the current scroll offset to
  /// `maxScrollExtent`.
  ValueListenable<double> get distanceFromBottom => _distanceFromBottom;

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
    _pendingDistance = math.max(0, distance);
    _pendingThreshold = threshold;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        if (!_disposed) _applyBottomDistance();
      });
      return;
    }
    _applyBottomDistance();
  }

  void _applyBottomDistance() {
    final clamped = _pendingDistance;
    if ((_distanceFromBottom.value - clamped).abs() > 0.5) {
      _distanceFromBottom.value = clamped;
    }
    final away = clamped > _pendingThreshold;
    if (_isAwayFromBottom.value != away) {
      _isAwayFromBottom.value = away;
    }
  }

  /// Smoothly scrolls to where the bottom was when called.
  ///
  /// When the last item is virtualized/offscreen, the spring converges across
  /// unmeasured items as they lay out and freezes as soon as the last item
  /// lays out, so newly streaming tokens never cause jittery chasing.
  Future<void> jumpToBottom({bool animate = true}) async {
    final delegate = _delegate;
    if (delegate == null) return;
    await delegate.jumpToBottom(animate: animate);
  }

  /// Scrolls to the item identified by [itemId], even if it is currently
  /// offscreen/virtualized.
  ///
  /// [alignment] `0.0` aligns the item's top to the usable top edge (below
  /// `padding.top` + safe area); `1.0` aligns its bottom to the usable bottom
  /// edge; `0.5` centers it.
  Future<void> scrollTo(
    Object itemId, {
    double alignment = 0,
    bool animate = true,
  }) async {
    final delegate = _delegate;
    if (delegate == null) return;
    await delegate.scrollTo(itemId, alignment: alignment, animate: animate);
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

  var _applyingDimensions = false;

  /// Runs a live-target Motor spring activity toward [resolveTarget].
  ///
  /// Automatically cancels if the user starts dragging, wheeling, or scrolling.
  Future<void> animateToTarget({
    required double? Function() resolveTarget,
    required Motion motion,
    TickerProvider? vsync,
  }) {
    if (!hasPixels || !hasContentDimensions) return Future.value();
    final initialTarget = resolveTarget();
    if (initialTarget == null) return Future.value();
    final clamped = initialTarget.clamp(minScrollExtent, maxScrollExtent);
    if ((pixels - clamped).abs() <= 0.5) {
      if (pixels != clamped) jumpTo(clamped);
      return Future.value();
    }
    final activity = TargetTrackingScrollActivity(
      this,
      initialPixels: pixels,
      initialTarget: clamped,
      resolveTarget: resolveTarget,
      motion: motion,
      vsync: vsync ?? context.vsync,
    );
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
  final _completer = Completer<void>();
  double _target;
  var _disposed = false;
  var _retargeting = false;

  /// Completes when the scroll arrives or is interrupted.
  Future<void> get done => _completer.future;

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
      _finish();
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
      _controller.animateTo(
        nextTarget,
        from: from,
        withVelocity: withVelocity,
      );
    } finally {
      _retargeting = false;
    }
  }

  void _tick() {
    if (_disposed || _retargeting || !_position.hasContentDimensions) return;
    final raw = resolveTarget();
    if (raw == null) {
      _finish();
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
      if (_position.hasContentDimensions) {
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
        }
      }
      _finish();
    }
  }

  void _finish() {
    if (_disposed) return;
    if (!_completer.isCompleted) _completer.complete();
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
      if (!_completer.isCompleted) _completer.complete();
    }
    super.dispose();
  }
}
