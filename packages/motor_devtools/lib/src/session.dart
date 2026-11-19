import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// Session-only motion overrides and replay for a controller, built on
/// motor's inspection hooks.
extension MotorDevToolsSession on TrackController {
  static final _overrides = Expando<Map<Track<Object>, Motion>>();
  static final _groupOverrides = Expando<Motion? Function(Track<Object>)>();

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
    _install();
  }

  /// Motions shared by this controller's group, used for tracks without
  /// an override of their own. See [groupMotionResolver].
  set groupMotionOverride(Motion? Function(Track<Object>)? resolve) {
    _groupOverrides[this] = resolve;
    _install();
  }

  /// Whether a group motion applies to this controller.
  bool get hasGroupMotionOverride => _groupOverrides[this] != null;

  /// Removes this controller's own overrides, keeping its group's motion.
  void clearOwnMotionOverrides() {
    _overrides[this] = null;
    _install();
  }

  /// Restores the authored motions of every track.
  void clearMotionOverrides() {
    _overrides[this] = null;
    _groupOverrides[this] = null;
    motionOverride = null;
  }

  void _install() {
    final own = _overrides[this];
    final group = _groupOverrides[this];
    motionOverride = (own == null || own.isEmpty) && group == null
        ? null
        : (track) => own?[track] ?? group?.call(track);
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

/// Picks a group's motion for each of [member]'s tracks.
///
/// [overrides] are keyed by track `debugLabel`; the null key applies to all
/// tracks. A track gets the override for its label. When none of the
/// member's track labels match any override, every track gets the first
/// override, so groups with differently labeled tracks still apply.
Motion? Function(Track<Object>) groupMotionResolver(
  TrackController member,
  Map<String?, Motion> overrides,
) {
  final seen = <String?>{};
  return (track) {
    final label = track.debugLabel;
    seen.add(label);
    if (overrides[label] case final motion? when label != null) return motion;
    if (overrides[null] case final motion?) return motion;
    final known = {
      ...seen,
      for (final playback in member.inspectPlayback().tracks)
        playback.track.debugLabel,
    };
    if (overrides.keys.any(known.contains)) return null;
    return overrides.values.firstOrNull;
  };
}
