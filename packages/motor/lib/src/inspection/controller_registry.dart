import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/track_controller.dart';

/// Observes the lifecycle of controllers created while it is attached.
///
/// This is intended for optional developer tooling. Motor does not retain a
/// controller registry until the first observer attaches, so applications
/// that do not import a tool pay only a nullable hook check per controller.
abstract interface class MotorInspectionObserver {
  /// Called after [controller] is created.
  void didRegisterController(TrackController controller);

  /// Called immediately before [controller] is disposed.
  void didUnregisterController(TrackController controller);
}

/// A removable attachment to [MotorInspectionRegistry].
class MotorInspectionSubscription {
  MotorInspectionSubscription._(this._observer);

  MotorInspectionObserver? _observer;

  /// Stops observing controller lifecycle events.
  void dispose() {
    final observer = _observer;
    if (observer == null) return;
    _observer = null;
    MotorInspectionRegistry._removeObserver(observer);
  }
}

/// The opt-in bridge between Motor controllers and external inspection tools.
///
/// A root devtools widget attaches an observer before mounting its child.
/// Controllers created beneath that root are then discovered automatically.
/// When no observer is attached, Motor keeps no global collection of
/// controllers.
abstract final class MotorInspectionRegistry {
  static final _observers = <MotorInspectionObserver>{};
  static Set<TrackController>? _activeControllers;

  /// Attaches [observer] and reports controllers already known to another
  /// active observer.
  static MotorInspectionSubscription attach(
    MotorInspectionObserver observer,
  ) {
    final active = _activeControllers ??= <TrackController>{};
    _observers.add(observer);
    for (final controller in active) {
      observer.didRegisterController(controller);
    }
    return MotorInspectionSubscription._(observer);
  }

  static void _removeObserver(MotorInspectionObserver observer) {
    _observers.remove(observer);
    if (_observers.isEmpty) _activeControllers = null;
  }

  /// Reports a newly created controller to attached tooling.
  @internal
  static void registerController(TrackController controller) {
    final active = _activeControllers;
    if (active == null || !active.add(controller)) return;
    for (final observer in _observers.toList(growable: false)) {
      observer.didRegisterController(controller);
    }
  }

  /// Reports a disposing controller to attached tooling.
  @internal
  static void unregisterController(TrackController controller) {
    final active = _activeControllers;
    if (active == null || !active.remove(controller)) return;
    for (final observer in _observers.toList(growable: false)) {
      observer.didUnregisterController(controller);
    }
  }

  /// Whether any inspection tool is currently attached.
  @visibleForTesting
  static bool get hasObservers => _observers.isNotEmpty;

  /// Whether playback should capture inspection-only duration estimates.
  @internal
  static bool get durationEstimationEnabled => _observers.isNotEmpty;
}
