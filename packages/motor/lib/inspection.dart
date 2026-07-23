/// Debug and tooling introspection for motor playback.
///
/// This surface exists for inspectors, debug overlays, and tests. It is
/// read-only: nothing here can mutate playback.
library motor.inspection;

export 'src/inspection/controller_registry.dart';
export 'src/inspection/playback_snapshot.dart';
