import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/style.dart';

/// How a timeline segment is drawn.
enum SegmentKind {
  /// A target-based or free motion.
  motion,

  /// A fixed hold.
  hold,

  /// Waiting at a sync barrier.
  sync,
}

/// One step of a lane, on the controller's playback clock.
@immutable
class TimelineSegment {
  /// Creates a segment from [start] to [end].
  const TimelineSegment(this.kind, this.start, this.end);

  /// How the segment is drawn.
  final SegmentKind kind;

  /// Where the segment starts.
  final Duration start;

  /// Where the segment ends, or null when the end is not known yet.
  final Duration? end;
}

/// One track's row in the timeline.
@immutable
class TimelineLane {
  /// Creates a lane for [playback].
  const TimelineLane(this.playback, this.segments);

  /// The track's playback state.
  final TrackPlayback playback;

  /// The track's segments, oldest first.
  final List<TimelineSegment> segments;

  /// The latest known end, or null when the last segment is open.
  Duration? get end =>
      segments.isEmpty ? playback.startOffset : segments.last.end;
}

/// A visible span of a controller's playback clock.
@immutable
class TimelineWindow {
  /// Creates a window from [start] to [end].
  const TimelineWindow(this.start, this.end);

  /// The clock time at the left edge.
  final Duration start;

  /// The clock time at the right edge.
  final Duration end;

  /// The window's length.
  Duration get length => end - start;

  /// Where [time] falls, from 0 at [start] to 1 at [end], unclamped.
  double fractionOf(Duration time) => length <= Duration.zero
      ? 0
      : (time - start).inMicroseconds / length.inMicroseconds;

  /// The clock time at [fraction] of the window.
  Duration timeAt(double fraction) => start + length * fraction.clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      other is TimelineWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TimelineWindow($start, $end)';
}

/// A controller's timeline, ready to draw.
@immutable
class TimelineLayout {
  /// Creates a layout.
  const TimelineLayout(this.window, this.position, this.lanes);

  /// The visible span.
  final TimelineWindow window;

  /// The controller's position on its playback clock.
  final Duration position;

  /// One lane per track.
  final List<TimelineLane> lanes;
}

/// Lays [snapshot] out on the controller's playback clock, the axis that
/// `TrackController.scrubTo` takes.
///
/// Without [window], the window spans the tracks of the latest run: tracks
/// that finished before the most recent track started are left out of it.
/// Looping plans page through one cycle at a time instead.
TimelineLayout layoutTimeline(
  PlaybackSnapshot snapshot, {
  TimelineWindow? window,
}) {
  final looping = snapshot.tracks.where((track) => track.loop != LoopMode.none);
  final horizon = window?.end ?? _loopHorizon(snapshot, looping);
  final lanes = [
    for (final playback in snapshot.tracks) _LaneBuilder(playback, horizon),
  ];
  _playAhead(lanes);
  final built = [
    for (final lane in lanes) TimelineLane(lane.playback, lane.segments),
  ];
  return TimelineLayout(
    window ?? _windowOf(snapshot, built, looping),
    snapshot.position,
    built,
  );
}

Duration _loopHorizon(
  PlaybackSnapshot snapshot,
  Iterable<TrackPlayback> looping,
) {
  if (looping.isEmpty) return snapshot.position;
  return snapshot.position + _cycleLength(looping);
}

Duration _cycleLength(Iterable<TrackPlayback> looping) {
  var longest = Duration.zero;
  for (final playback in looping) {
    final cycle = playback.estimatedStepDurations.fold(
      Duration.zero,
      (sum, duration) => sum + (duration ?? Duration.zero),
    );
    if (cycle > longest) longest = cycle;
  }
  return longest > Duration.zero ? longest : const Duration(seconds: 1);
}

TimelineWindow _windowOf(
  PlaybackSnapshot snapshot,
  List<TimelineLane> lanes,
  Iterable<TrackPlayback> looping,
) {
  final position = snapshot.position;
  if (lanes.isEmpty) return TimelineWindow(position, position);
  if (looping.isNotEmpty) {
    final cycle = _cycleLength(looping);
    final origin = looping.map((track) => track.startOffset).reduce(_min);
    final page = math.max(
      0,
      (position - origin).inMicroseconds ~/ cycle.inMicroseconds,
    );
    final start = origin + cycle * page;
    return TimelineWindow(start, start + cycle);
  }
  final latestStart = lanes
      .map((lane) => lane.playback.startOffset)
      .reduce(_max);
  var start = latestStart;
  var end = latestStart;
  for (final lane in lanes) {
    final laneEnd = lane.end ?? position;
    if (laneEnd < latestStart) continue;
    start = _min(start, lane.playback.startOffset);
    end = _max(end, laneEnd);
  }
  if (end <= start) end = start + const Duration(milliseconds: 1);
  return TimelineWindow(start, end);
}

/// Collects one lane's segments: the resolved ones, and the steps still to
/// come in the current pass, which [_playAhead] places.
class _LaneBuilder {
  _LaneBuilder(this.playback, Duration horizon) {
    final origin = playback.startOffset;
    for (final segment in playback.segments) {
      final start = origin + segment.start;
      final end = segment.end;
      if (end == null) {
        _cursor = start;
        _queue.add(segment.stepIndex);
      } else {
        segments.add(
          TimelineSegment(_kindOf(segment.stepIndex), start, origin + end),
        );
        _cursor = origin + end;
      }
    }
    final period = playback.loopPeriod;
    final repeatStart = playback.loopRepeatStart;
    if (period != null && repeatStart != null && period > Duration.zero) {
      _queue.clear();
      final repeating = [
        for (final segment in playback.segments)
          if (segment.start >= repeatStart && segment.end != null) segment,
      ];
      for (var lap = 1; repeating.isNotEmpty; lap++) {
        final offset = origin + period * lap;
        if (offset + repeatStart > horizon) break;
        for (final segment in repeating) {
          segments.add(
            TimelineSegment(
              _kindOf(segment.stepIndex),
              offset + segment.start,
              offset + segment.end!,
            ),
          );
        }
      }
      return;
    }
    if (playback.segments.isEmpty || playback.currentStepIndex < 0) return;
    final last = playback.segments.last;
    for (
      var step = last.stepIndex + last.direction;
      step >= 0 && step < playback.steps.length;
      step += last.direction
    ) {
      _queue.add(step);
    }
  }

  final TrackPlayback playback;
  final segments = <TimelineSegment>[];
  final _queue = <int>[];
  Duration? _cursor;

  SegmentKind _kindOf(int step) => switch (playback.steps[step]) {
    StepHold() => SegmentKind.hold,
    StepSync() => SegmentKind.sync,
    _ => SegmentKind.motion,
  };

  Object? get _headToken => _queue.isEmpty
      ? null
      : switch (playback.steps[_queue.first]) {
          StepSync(:final token) => token,
          _ => null,
        };

  bool _waitsFor(Object token) => _queue.any(
    (step) => switch (playback.steps[step]) {
      StepSync(token: final other) => other == token,
      _ => false,
    },
  );

  /// Places steps up to the next sync step, from their estimates.
  void _advance() {
    while (_queue.isNotEmpty && _headToken == null) {
      final step = _queue.removeAt(0);
      final estimates = playback.estimatedStepDurations;
      final duration = step < estimates.length ? estimates[step] : null;
      final start = _cursor!;
      final end = duration == null ? null : start + duration;
      segments.add(TimelineSegment(_kindOf(step), start, end));
      _cursor = end;
      if (end == null) _queue.clear();
    }
  }

  void _release(Duration at) {
    _queue.removeAt(0);
    segments.add(TimelineSegment(SegmentKind.sync, _cursor!, at));
    _cursor = at;
  }

  void _leaveOpen() {
    if (_queue.isEmpty) return;
    segments.add(TimelineSegment(SegmentKind.sync, _cursor!, null));
    _queue.clear();
  }
}

/// Plays the lanes' remaining steps ahead, releasing each sync barrier at the
/// latest arrival among the lanes that wait for it, as playback does.
void _playAhead(List<_LaneBuilder> lanes) {
  while (true) {
    for (final lane in lanes) {
      lane._advance();
    }
    final waiting = lanes.where((lane) => lane._headToken != null).toList();
    if (waiting.isEmpty) return;
    var released = false;
    for (final token in {for (final lane in waiting) lane._headToken!}) {
      final arrived = waiting.where((lane) => lane._headToken == token);
      final blocked = lanes.any(
        (lane) => lane._headToken != token && lane._waitsFor(token),
      );
      if (blocked) continue;
      final at = arrived.map((lane) => lane._cursor!).reduce(_max);
      for (final lane in arrived.toList()) {
        lane._release(at);
      }
      released = true;
    }
    if (!released) {
      for (final lane in waiting) {
        lane._leaveOpen();
      }
      return;
    }
  }
}

Duration _min(Duration a, Duration b) => a < b ? a : b;

Duration _max(Duration a, Duration b) => a > b ? a : b;

/// A live, scrubbable timeline of every track on [controller].
///
/// Dragging or tapping pauses the controller and scrubs its playback clock.
/// Playback resumes on release if it was running.
class Timeline extends StatefulWidget {
  /// Creates a timeline for [controller].
  const Timeline({required this.controller, this.selectedTrack, super.key});

  /// The controller to show.
  final TrackController controller;

  /// A track to highlight.
  final Track<Object>? selectedTrack;

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  TimelineWindow? _frozen;
  var _resumeAfterScrub = false;

  void _startScrub(double fraction, TimelineWindow window) {
    _frozen = window;
    _resumeAfterScrub = widget.controller.isAnimating;
    widget.controller
      ..pause()
      ..scrubTo(window.timeAt(fraction));
  }

  void _updateScrub(double fraction) {
    final window = _frozen;
    if (window != null) widget.controller.scrubTo(window.timeAt(fraction));
  }

  void _endScrub() {
    if (_frozen == null) return;
    setState(() => _frozen = null);
    if (_resumeAfterScrub) widget.controller.resume();
  }

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final layout = layoutTimeline(
          widget.controller.inspectPlayback(),
          window: _frozen,
        );
        final window = layout.window;
        return LayoutBuilder(
          builder: (context, constraints) {
            double fractionAt(Offset position) =>
                position.dx / constraints.maxWidth;
            return Semantics(
              label: 'Timeline',
              hint: 'Drag to scrub',
              value: formatDuration(layout.position - window.start),
              child: GestureDetector(
                key: const ValueKey('motor-devtools-timeline'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _startScrub(fractionAt(details.localPosition), window),
                onTapUp: (_) => _endScrub(),
                onTapCancel: _endScrub,
                onHorizontalDragStart: (details) {
                  if (_frozen == null) {
                    _startScrub(fractionAt(details.localPosition), window);
                  }
                },
                onHorizontalDragUpdate: (details) =>
                    _updateScrub(fractionAt(details.localPosition)),
                onHorizontalDragEnd: (_) => _endScrub(),
                onHorizontalDragCancel: _endScrub,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Ruler(layout: layout, scrubbing: _frozen != null),
                    if (layout.lanes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'Nothing has played yet',
                          textAlign: TextAlign.center,
                          style: palette.caption,
                        ),
                      ),
                    for (final (index, lane) in layout.lanes.indexed)
                      _LaneRow(
                        lane: lane,
                        index: index,
                        layout: layout,
                        value: widget.controller.value(lane.playback.track),
                        selected: identical(
                          widget.selectedTrack,
                          lane.playback.track,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({required this.layout, required this.scrubbing});

  final TimelineLayout layout;
  final bool scrubbing;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final window = layout.window;
    final elapsed = layout.position - window.start;
    return SizedBox(
      height: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                formatDuration(
                  elapsed < Duration.zero
                      ? Duration.zero
                      : elapsed > window.length
                      ? window.length
                      : elapsed,
                ),
                style: palette.numeric.copyWith(color: palette.text),
              ),
              const Spacer(),
              Text(formatDuration(window.length), style: palette.numeric),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 10,
            child: CustomPaint(
              painter: _RulerPainter(
                window.length,
                layout.lanes.isEmpty
                    ? null
                    : window.fractionOf(layout.position).clamp(0.0, 1.0),
                palette,
                scrubbing: scrubbing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaneRow extends StatelessWidget {
  const _LaneRow({
    required this.lane,
    required this.index,
    required this.layout,
    required this.value,
    required this.selected,
  });

  final TimelineLane lane;
  final int index;
  final TimelineLayout layout;
  final Object value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final playback = lane.playback;
    final label = playback.track.debugLabel ?? 'Track ${index + 1}';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: palette.caption.copyWith(
                    color: selected ? palette.text : palette.secondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (playback.isWaitingForSync)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'waiting',
                    style: palette.caption.copyWith(color: palette.tertiary),
                  ),
                ),
              Text(formatValue(value), style: palette.numeric),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 8,
            child: CustomPaint(
              painter: _LanePainter(
                lane: lane,
                window: layout.window,
                position: layout.position,
                palette: palette,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanePainter extends CustomPainter {
  const _LanePainter({
    required this.lane,
    required this.window,
    required this.position,
    required this.palette,
  });

  final TimelineLane lane;
  final TimelineWindow window;
  final Duration position;
  final DevToolsPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawRRect(
      RRect.fromLTRBR(0, mid - 0.5, size.width, mid + 0.5, Radius.zero),
      Paint()..color = palette.hairline,
    );
    final playheadX = size.width * window.fractionOf(position).clamp(0.0, 1.0);
    for (final segment in lane.segments) {
      final open = segment.end == null;
      final startX = size.width * window.fractionOf(segment.start);
      final endX = open
          ? size.width
          : size.width * window.fractionOf(segment.end!);
      if (endX < 0 || startX > size.width) continue;
      final left = startX.clamp(0.0, size.width);
      final right = endX.clamp(0.0, size.width);
      if (segment.kind == SegmentKind.sync) {
        if (right - left < 1) continue;
        final dots = Paint()..color = palette.tertiary;
        for (var x = left + 1.5; x < right - 1; x += 4) {
          canvas.drawCircle(Offset(x, mid), 0.9, dots);
        }
        continue;
      }
      if (right - left < 0.5) continue;
      final gap = right - left > 4 ? 1.0 : 0.0;
      final height = segment.kind == SegmentKind.hold ? 2.0 : size.height;
      final bar = RRect.fromLTRBR(
        left + gap,
        mid - height / 2,
        math.max(left + gap + 2, right - gap),
        mid + height / 2,
        Radius.circular(height / 2),
      );
      final future = palette.text.withValues(
        alpha: segment.kind == SegmentKind.hold ? 0.16 : 0.13,
      );
      final past = palette.text.withValues(
        alpha: segment.kind == SegmentKind.hold ? 0.45 : 0.82,
      );
      final paint = Paint()..color = future;
      if (open) {
        paint.shader = LinearGradient(
          colors: [future, future.withValues(alpha: 0)],
        ).createShader(bar.outerRect);
      }
      canvas.drawRRect(bar, paint);
      if (playheadX > bar.left) {
        canvas
          ..save()
          ..clipRect(Rect.fromLTRB(0, 0, playheadX, size.height))
          ..drawRRect(bar, Paint()..color = past)
          ..restore();
      }
    }
    if (lane.segments.isNotEmpty) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          playheadX.clamp(1, size.width - 1) - 0.75,
          -3,
          playheadX.clamp(1, size.width - 1) + 0.75,
          size.height + 3,
          const Radius.circular(1),
        ),
        Paint()..color = palette.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_LanePainter oldDelegate) => true;
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter(
    this.length,
    this.playhead,
    this.palette, {
    required this.scrubbing,
  });

  final Duration length;
  final double? playhead;
  final DevToolsPalette palette;
  final bool scrubbing;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = length.inMicroseconds / Duration.microsecondsPerMillisecond;
    if (ms <= 0) return;
    const steps = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000];
    final step = steps.firstWhere((s) => ms / s <= 12, orElse: () => 20000);
    final paint = Paint()
      ..color = palette.tertiary.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var t = 0.0, i = 0; t <= ms + 0.001; t += step, i++) {
      final x = (size.width * t / ms).clamp(0.5, size.width - 0.5);
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, i.isEven ? size.height - 6 : size.height - 3),
        paint,
      );
    }
    final fraction = playhead;
    if (fraction == null) return;
    final x = (size.width * fraction).clamp(1.0, size.width - 1);
    final accent = Paint()..color = palette.accent;
    canvas
      ..drawRRect(
        RRect.fromLTRBR(
          x - 0.75,
          4,
          x + 0.75,
          size.height + 6,
          const Radius.circular(1),
        ),
        accent,
      )
      ..drawCircle(Offset(x, 4), scrubbing ? 4.5 : 3.5, accent);
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      oldDelegate.length != length ||
      oldDelegate.playhead != playhead ||
      oldDelegate.scrubbing != scrubbing ||
      oldDelegate.palette != palette;
}
