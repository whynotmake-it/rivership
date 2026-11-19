/// Debug and tooling introspection for motor playback.
///
/// This surface exists for inspectors, debug overlays, and tests. Everything
/// here is `@experimental`: it may change in minor releases, unlike the core
/// `package:motor/motor.dart` API.
///
/// Snapshots (`PlaybackSnapshot`, `TrackPlayback`, `PlaybackPlan`) are
/// read-only. The `TrackControllerInspection` extension additionally exposes
/// two hooks that do change playback of a single controller:
/// `playbackSpeed` and `motionOverride`.
///
/// While a tool is attached, controllers keep more for
/// `TrackController.scrubTo`:
///
/// - Plans a track has since been redirected away from, so scrubbing back
///   shows them. They are only for viewing: playback, including `resume`
///   from such a time, always continues each track's current plan, holding
///   its start until the timeline reaches it.
/// - About a thousand steps of a looping plan that cannot repeat exactly,
///   such as every looping phase timeline, instead of its two most recent
///   cycles.
library motor.inspection;

export 'src/inspection/controller_registry.dart';
export 'src/inspection/inspection_scope.dart';
export 'src/inspection/playback_snapshot.dart';
