/// @docImport 'package:snaptest/src/video/pointer_overlay.dart';
/// @docImport 'package:snaptest/src/video/video_settings.dart';
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Builds the overlay drawn over every captured frame of a recording.
///
/// See [SnapVideoSettings.overlay].
typedef SnapVideoOverlayBuilder =
    Widget Function(BuildContext context, SnapVideoFrame frame);

/// Where a [SnapPointer] is in its press lifecycle.
enum SnapPointerPhase {
  /// A mouse or stylus that is over the view but not pressed.
  hovering,

  /// Between pointer-down and pointer-up.
  pressed,

  /// After pointer-up, while [SnapVideoSettings.minimumPointerDuration]
  /// keeps the pointer visible.
  ///
  /// Once that duration has passed since pointer-down, a mouse or stylus
  /// that is still over the view goes back to [hovering]; any other
  /// pointer leaves [SnapVideoFrame.pointers].
  released,
}

/// A pointer that a recording observed, as seen by one captured frame.
@immutable
class SnapPointer {
  /// Creates a pointer snapshot.
  const SnapPointer({
    required this.id,
    required this.position,
    required this.kind,
    required this.phase,
    required this.sincePhase,
  });

  /// The pointer's unique id ([PointerEvent.pointer]).
  ///
  /// Stable across frames while the pointer is visible, so overlays can key
  /// per-pointer state by it.
  final int id;

  /// The pointer's position in logical pixels, in the recorded view's
  /// coordinate space ([PointerEvent.position]).
  final Offset position;

  /// The kind of device behind the pointer.
  final PointerDeviceKind kind;

  /// Where the pointer is in its press lifecycle.
  final SnapPointerPhase phase;

  /// Simulated time spent in [phase], as of this frame.
  final Duration sincePhase;

  @override
  bool operator ==(Object other) =>
      other is SnapPointer &&
      other.id == id &&
      other.position == position &&
      other.kind == kind &&
      other.phase == phase &&
      other.sincePhase == sincePhase;

  @override
  int get hashCode => Object.hash(id, position, kind, phase, sincePhase);

  @override
  String toString() =>
      'SnapPointer($id, ${phase.name}, $position, ${kind.name}, '
      'sincePhase: $sincePhase)';
}

/// What a recording overlay knows about one captured frame.
///
/// Passed to [SnapVideoSettings.overlay] each time the recording captures a
/// frame.
@immutable
class SnapVideoFrame {
  /// Creates a frame description.
  const SnapVideoFrame({
    required this.pointers,
    required this.elapsed,
    required this.size,
  });

  /// The pointers visible in this frame: hovering, pressed, and recently
  /// released ones.
  final List<SnapPointer> pointers;

  /// Simulated time since the recording's first captured frame, which is
  /// the start of the video.
  final Duration elapsed;

  /// The logical size of the recorded view, which is also the size of the
  /// overlay.
  final Size size;

  @override
  String toString() =>
      'SnapVideoFrame(elapsed: $elapsed, size: $size, pointers: $pointers)';
}
