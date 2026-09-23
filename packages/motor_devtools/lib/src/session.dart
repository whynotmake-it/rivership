import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// Session-only motion overrides and replay for a controller, built on
/// motor's inspection hooks.
extension MotorDevToolsSession on TrackController {
  static final _overrides = Expando<Map<Track<Object>, Motion>>();

  /// The motion overrides set from the tools, keyed by track.
  Map<Track<Object>, Motion> get motionOverrides =>
      Map.unmodifiable(_overrides[this] ?? const <Track<Object>, Motion>{});

  /// Uses [motion] for [track]'s target steps in future plans, or restores
  /// the authored motions when [motion] is null.
  void setMotionOverride(Track<Object> track, Motion? motion) {
    final overrides = _overrides[this] ??= {};
    if (motion == null) {
      overrides.remove(track);
    } else {
      overrides[track] = motion;
    }
    motionOverride = overrides.isEmpty ? null : (track) => overrides[track];
  }

  /// Restores the authored motions of every track.
  void clearMotionOverrides() {
    _overrides[this] = null;
    motionOverride = null;
  }

  /// Replays the most recently submitted plan from its recorded start values.
  void replay() {
    final plans = inspectPlayback().plans;
    if (plans.isEmpty) return;
    final plan = plans.last;
    stop(canceled: true);
    set(plan.startValues);
    animate(plan.animations, loop: plan.loop);
  }
}
