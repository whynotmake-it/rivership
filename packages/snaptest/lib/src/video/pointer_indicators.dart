import 'package:flutter/gestures.dart';
import 'package:meta/meta.dart';

/// A simulated-time overlay timeline, independent of widget pumps.
@internal
class PointerIndicators {
  /// Creates an overlay timeline with a minimum pointer-down duration.
  PointerIndicators(this.minimumDuration);

  /// Minimum display duration, measured from down rather than release.
  final Duration minimumDuration;
  final _pointers = <int, ({Offset position, int downUs, int? expiresUs})>{};
  final _changes = <({int timeUs, List<Offset> positions})>[];

  /// Current visible positions, including briefly retained released pointers.
  List<Offset> get positions => [for (final p in _pointers.values) p.position];

  /// Records a pointer event at the test clock's [timeUs].
  void handle(PointerEvent event, int timeUs) {
    _advance(timeUs);
    if (event is PointerDownEvent) {
      _pointers[event.pointer] = (
        position: event.position,
        downUs: timeUs,
        expiresUs: null,
      );
    } else if (event is PointerMoveEvent) {
      final previous = _pointers[event.pointer];
      if (previous == null) return;
      _pointers[event.pointer] = (
        position: event.position,
        downUs: previous.downUs,
        expiresUs: null,
      );
    } else if (event is PointerUpEvent) {
      final previous = _pointers[event.pointer];
      if (previous == null) return;
      final expires = previous.downUs + minimumDuration.inMicroseconds;
      if (expires > timeUs) {
        _pointers[event.pointer] = (
          position: previous.position,
          downUs: previous.downUs,
          expiresUs: expires,
        );
      } else {
        _pointers.remove(event.pointer);
      }
    } else if (event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
    } else {
      return;
    }
    _snapshot(timeUs);
  }

  /// Drains overlay changes through [timeUs], including expiry timestamps.
  List<({int timeUs, List<Offset> positions})> takeChangesThrough(int timeUs) {
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
      _pointers.removeWhere((_, p) => p.expiresUs == next);
      _snapshot(next);
    }
  }

  void _snapshot(int timeUs) {
    if (_changes.isNotEmpty && _changes.last.timeUs == timeUs) {
      _changes.removeLast();
    }
    _changes.add((timeUs: timeUs, positions: positions));
  }
}
