/// Debug and tooling introspection for motor playback.
///
/// This surface exists for inspectors, debug overlays, and tests. Everything
/// here is `@experimental`: it may change in minor releases, unlike the core
/// `package:motor/motor.dart` API.
///
/// Snapshots (`PlaybackSnapshot`, `TrackPlayback`) are read-only. The
/// `TrackControllerInspection` extension additionally exposes authoring hooks
/// that do change playback of a single controller: `playbackSpeed`,
/// `setMotionOverride`, and `replay`.
library motor.inspection;

export 'src/inspection/controller_registry.dart';
export 'src/inspection/playback_snapshot.dart';
