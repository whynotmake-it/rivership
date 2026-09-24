import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/track_controller.dart';

/// Observes the lifecycle of controllers created while it is attached.
///
/// This is intended for optional developer tooling. Motor does not retain a
/// controller registry until the first observer attaches, so applications
/// that do not import a tool pay only a nullable hook check per controller.
@experimental
abstract interface class MotorInspectionObserver {
  /// Called after [controller] is created.
  void didRegisterController(TrackController controller);

  /// Called immediately before [controller] is disposed.
  void didUnregisterController(TrackController controller);
}

/// A removable attachment to [MotorInspectionRegistry].
@experimental
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
/// A devtools widget typically attaches an observer before mounting its
/// child. From then on, every [TrackController] created anywhere in the
/// process (not just beneath that widget) is reported, until the last
/// observer detaches. Controllers created before the first observer attaches
/// are never reported. When no observer is attached, Motor keeps no global
/// collection of controllers.
@experimental
abstract final class MotorInspectionRegistry {
  static final _observers = <MotorInspectionObserver>{};
  static Set<TrackController>? _activeControllers;

  static Object? _pendingCreator;
  static final _creators = Expando<Object>();

  /// Attaches [observer] and immediately reports controllers already known to
  /// another active observer.
  ///
  /// Dispose the returned subscription to detach.
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
    if (_pendingCreator case final creator?) _creators[controller] = creator;
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

  /// Whether controllers should keep inspection-only data, such as duration
  /// estimates and recently submitted plans.
  @internal
  // Null unless attached, so compilers remove every inspection-only branch
  // when nothing calls [attach].
  static bool get isInspecting => _activeControllers != null;

  /// Runs [create], recording [creator] as the creator of the controllers it
  /// creates. Only in debug builds while a tool is attached.
  @internal
  static T withCreator<T>(Object creator, T Function() create) {
    if (!kDebugMode || !isInspecting) return create();
    final previous = _pendingCreator;
    _pendingCreator = creator;
    try {
      return create();
    } finally {
      _pendingCreator = previous;
    }
  }

  /// What created [controller], such as a builder widget's `Element`, if it
  /// was recorded.
  @internal
  static Object? creatorOf(TrackController controller) => _creators[controller];
}
