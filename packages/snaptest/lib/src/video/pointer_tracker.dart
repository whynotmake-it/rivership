import 'package:flutter/gestures.dart';
import 'package:meta/meta.dart';
import 'package:snaptest/src/video/video_frame.dart';

class _TrackedPointer {
  _TrackedPointer({
    required this.position,
    required this.kind,
    required this.phase,
    required this.phaseUs,
    required this.downUs,
  });

  Offset position;
  PointerDeviceKind kind;
  SnapPointerPhase phase;
  int phaseUs;
  int downUs;
  int? expiresUs;
}

/// A recording's pointer timeline in simulated time, independent of pumps.
///
/// Tracks hover, down, move, up, cancel, added and removed events and turns
/// them into [SnapPointer] snapshots for the recording overlay.
@internal
class PointerTracker {
  /// Creates a timeline that keeps released pointers until
  /// [minimumDuration] has passed since their pointer-down.
  PointerTracker(this.minimumDuration);

  /// Minimum display duration, measured from down rather than release.
  final Duration minimumDuration;

  final _pointers = <int, _TrackedPointer>{};

  /// Pointers that are still attached to the view and can hover: those
  /// that were added or hovered and not removed since.
  final _present = <int>{};

  final _changes = <({int timeUs, List<SnapPointer> pointers})>[];

  /// The visible pointers at [timeUs], applying any expiry up to then.
  List<SnapPointer> pointersAt(int timeUs) {
    _advance(timeUs);
    return _snapshot(timeUs);
  }

  /// Records a pointer event at the test clock's [timeUs].
  void handle(PointerEvent event, int timeUs) {
    _advance(timeUs);
    final id = event.pointer;
    final existing = _pointers[id];
    switch (event) {
      case PointerAddedEvent():
        _present.add(id);
        return;
      case PointerRemovedEvent():
        _present.remove(id);
        if (existing == null || existing.phase != SnapPointerPhase.hovering) {
          return;
        }
        _pointers.remove(id);
      case PointerHoverEvent():
        _present.add(id);
        if (existing == null) {
          _pointers[id] = _TrackedPointer(
            position: event.position,
            kind: event.kind,
            phase: SnapPointerPhase.hovering,
            phaseUs: timeUs,
            downUs: timeUs,
          );
        } else {
          // A released pointer keeps its phase until it expires.
          existing.position = event.position;
        }
      case PointerDownEvent():
        _pointers[id] = _TrackedPointer(
          position: event.position,
          kind: event.kind,
          phase: SnapPointerPhase.pressed,
          phaseUs: timeUs,
          downUs: timeUs,
        );
      case PointerMoveEvent():
        if (existing == null || existing.phase != SnapPointerPhase.pressed) {
          // A move is always pressed; this covers a recording that started
          // mid-press.
          _pointers[id] = _TrackedPointer(
            position: event.position,
            kind: event.kind,
            phase: SnapPointerPhase.pressed,
            phaseUs: timeUs,
            downUs: timeUs,
          );
        } else {
          existing.position = event.position;
        }
      case PointerUpEvent():
        if (existing == null) return;
        // Released pointers stay where they were last seen.
        existing
          ..phase = SnapPointerPhase.released
          ..phaseUs = timeUs
          ..expiresUs = existing.downUs + minimumDuration.inMicroseconds;
        if (existing.expiresUs! <= timeUs) _expire(id, timeUs);
      case PointerCancelEvent():
        if (_pointers.remove(id) == null) return;
      default:
        return;
    }
    _record(timeUs);
  }

  /// Drains the timeline's changes through [timeUs], including expiries.
  ///
  /// Each change is the full set of visible pointers from its timestamp
  /// on; changes at the same timestamp are coalesced into the last one.
  List<({int timeUs, List<SnapPointer> pointers})> takeChangesThrough(
    int timeUs,
  ) {
    _advance(timeUs);
    final changes = List.of(_changes);
    _changes.clear();
    return changes;
  }

  void _advance(int timeUs) {
    while (true) {
      final expiries = _pointers.values.map((p) => p.expiresUs).nonNulls;
      if (expiries.isEmpty) return;
      final next = expiries.reduce((a, b) => a < b ? a : b);
      if (next > timeUs) return;
      for (final id in [
        for (final MapEntry(:key, :value) in _pointers.entries)
          if (value.expiresUs == next) key,
      ]) {
        _expire(id, next);
      }
      _record(next);
    }
  }

  /// Ends a released pointer's linger: a pointer that can still hover goes
  /// back to hovering, any other pointer disappears.
  void _expire(int id, int timeUs) {
    if (_present.contains(id)) {
      _pointers[id]!
        ..phase = SnapPointerPhase.hovering
        ..phaseUs = timeUs
        ..expiresUs = null;
    } else {
      _pointers.remove(id);
    }
  }

  void _record(int timeUs) {
    if (_changes.isNotEmpty && _changes.last.timeUs == timeUs) {
      _changes.removeLast();
    }
    _changes.add((timeUs: timeUs, pointers: _snapshot(timeUs)));
  }

  List<SnapPointer> _snapshot(int timeUs) => [
    for (final MapEntry(key: id, value: p) in _pointers.entries)
      SnapPointer(
        id: id,
        position: p.position,
        kind: p.kind,
        phase: p.phase,
        sincePhase: Duration(microseconds: timeUs - p.phaseUs),
      ),
  ];
}
