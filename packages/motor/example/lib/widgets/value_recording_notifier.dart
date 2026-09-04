import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// Records a rolling window of recent [double] samples for plotting.
///
/// Ported from the physical_ui talk: each frame a value is [record]ed, and the
/// notifier keeps only the most recent [window] samples so a graph can show a
/// trajectory over time.
class ValueRecordingNotifier extends ValueNotifier<List<double>> {
  ValueRecordingNotifier({this.window = 220}) : super(const []);

  /// The maximum number of samples to retain.
  final int window;

  void reset() => value = const [];

  void record(double sample) {
    final next = [...value, sample];
    value = next.length > window
        ? next.sublist(next.length - window)
        : next;
  }

  /// Converts the recorded samples to normalized points in `0..1` for both
  /// axes, with the most recent sample pinned to the right edge.
  ///
  /// [minY] and [maxY] fix the vertical range so the line doesn't rescale as
  /// values change.
  List<Offset> toPoints({required double minY, required double maxY}) {
    final values = value;
    if (values.isEmpty) return const [];
    final range = maxY - minY;
    final denom = math.max(window - 1, 1);
    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          1 - (values.length - 1 - i) / denom,
          range == 0 ? 0.5 : 1 - ((values[i] - minY) / range).clamp(0, 1),
        ),
    ];
  }
}
