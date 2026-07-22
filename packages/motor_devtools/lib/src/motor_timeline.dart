import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

const _labelWidth = 76.0;
const _laneHeight = 34.0;

/// A compact, live timeline for a [TrackController].
///
/// Solid segments have been measured by Motor. Outlined segments are design
/// estimates that will be replaced as playback reaches them. Dragging pauses
/// the controller, scrubs its current plan, and resumes it on release.
class MotorTimeline extends StatefulWidget {
  /// Creates a Motor playback timeline.
  const MotorTimeline({
    required this.controller,
    this.track,
    this.accent = const Color(0xFFF4F4F4),
    super.key,
  });

  /// The controller to inspect.
  final TrackController controller;

  /// Limits the timeline to one track when provided.
  final Track<Object>? track;

  /// The primary timeline color.
  final Color accent;

  @override
  State<MotorTimeline> createState() => _MotorTimelineState();
}

class _MotorTimelineState extends State<MotorTimeline> {
  late PlaybackSnapshot _snapshot;
  var _scrubbing = false;
  var _stripWidth = 0.0;
  var _totalDuration = Duration.zero;
  Duration? _pendingScrub;
  var _scrubScheduled = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.controller.inspectPlayback();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(MotorTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_refresh);
    widget.controller.addListener(_refresh);
    _snapshot = widget.controller.inspectPlayback();
  }

  void _refresh() {
    if (mounted) {
      setState(() => _snapshot = widget.controller.inspectPlayback());
    }
  }

  bool get _canScrub =>
      _snapshot.tracks.any((playback) => playback.currentStepIndex >= 0);

  void _startScrub(DragStartDetails details) {
    if (!_canScrub) return;
    widget.controller.pause();
    setState(() => _scrubbing = true);
    _queueScrub(details.localPosition.dx);
  }

  void _updateScrub(DragUpdateDetails details) {
    if (_scrubbing) _queueScrub(details.localPosition.dx);
  }

  void _queueScrub(double x) {
    if (_stripWidth <= 0 || _totalDuration <= Duration.zero) return;
    final fraction = ((x - _labelWidth) / _stripWidth).clamp(0.0, 1.0);
    _pendingScrub = Duration(
      microseconds: (_totalDuration.inMicroseconds * fraction).round(),
    );
    if (_scrubScheduled) return;
    _scrubScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scrubScheduled = false;
      final target = _pendingScrub;
      _pendingScrub = null;
      if (mounted && target != null && _scrubbing) {
        widget.controller.scrubTo(target);
      }
    });
  }

  void _finishScrub() {
    if (!_scrubbing) return;
    final target = _pendingScrub;
    _pendingScrub = null;
    if (target != null) widget.controller.scrubTo(target);
    setState(() => _scrubbing = false);
    widget.controller.resume();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleSnapshot = _visibleSnapshot;
    final laneCount = math.max(1, visibleSnapshot.tracks.length);
    final height = 30 + laneCount * _laneHeight;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _stripWidth = math.max(0, constraints.maxWidth - _labelWidth);
          final unscaled = layoutMotorTimeline(visibleSnapshot);
          _totalDuration = unscaled.totalDuration;
          final milliseconds =
              _totalDuration.inMicroseconds /
              Duration.microsecondsPerMillisecond;
          final scale = milliseconds == 0 ? 0.0 : _stripWidth / milliseconds;
          final layout = layoutMotorTimeline(
            visibleSnapshot,
            pixelsPerMillisecond: scale,
          );
          return Semantics(
            label: 'Motor timeline',
            hint: _canScrub ? 'Drag horizontally to scrub playback' : null,
            child: GestureDetector(
              key: const ValueKey('motor-devtools-timeline'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _canScrub ? _startScrub : null,
              onHorizontalDragUpdate: _canScrub ? _updateScrub : null,
              onHorizontalDragEnd: _canScrub ? (_) => _finishScrub() : null,
              onHorizontalDragCancel: _canScrub ? _finishScrub : null,
              child: CustomPaint(
                painter: _MotorTimelinePainter(
                  layout: layout,
                  accent: widget.accent,
                  scrubbing: _scrubbing,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PlaybackSnapshot get _visibleSnapshot {
    final track = widget.track;
    if (track == null) return _snapshot;
    return PlaybackSnapshot(
      revision: _snapshot.revision,
      tickerElapsed: _snapshot.tickerElapsed,
      status: _snapshot.status,
      tracks: [
        for (final playback in _snapshot.tracks)
          if (identical(playback.track, track)) playback,
      ],
    );
  }
}

/// Whether timeline geometry came from the authored plan or live playback.
enum MotorTimelineProvenance {
  /// An authored duration estimate.
  estimated,

  /// A duration recorded by the playback engine.
  recorded,
}

/// The visual kind of one timeline segment.
enum MotorTimelineSegmentKind {
  /// A target-based motion.
  motion,

  /// A fixed hold.
  hold,

  /// A self-directed motion with no known design duration.
  free,

  /// A synchronization point.
  barrier,
}

/// Resolved geometry for one playback step.
@immutable
class MotorTimelineSegment {
  /// Creates resolved segment geometry.
  const MotorTimelineSegment({
    required this.kind,
    required this.provenance,
    required this.start,
    required this.end,
    required this.startX,
    required this.endX,
  });

  /// The segment's visual treatment.
  final MotorTimelineSegmentKind kind;

  /// Whether its timing is estimated or recorded.
  final MotorTimelineProvenance provenance;

  /// Start on the controller-aligned axis.
  final Duration start;

  /// End on the controller-aligned axis.
  final Duration end;

  /// Scaled horizontal start.
  final double startX;

  /// Scaled horizontal end.
  final double endX;
}

/// Resolved geometry for one track lane.
@immutable
class MotorTimelineLane {
  /// Creates a resolved track lane.
  const MotorTimelineLane({
    required this.track,
    required this.segments,
    required this.end,
    required this.playhead,
  });

  /// The lane's source track.
  final Track<Object> track;

  /// The lane's resolved segments.
  final List<MotorTimelineSegment> segments;

  /// The lane's resolved end.
  final Duration end;

  /// The current playback position.
  final Duration playhead;
}

/// Pure output from [layoutMotorTimeline].
@immutable
class MotorTimelineLayout {
  /// Creates timeline layout output.
  const MotorTimelineLayout({
    required this.lanes,
    required this.totalDuration,
  });

  /// Resolved lanes.
  final List<MotorTimelineLane> lanes;

  /// Latest end across every lane.
  final Duration totalDuration;
}

/// Resolves a snapshot into stable, testable timeline geometry.
@visibleForTesting
MotorTimelineLayout layoutMotorTimeline(
  PlaybackSnapshot snapshot, {
  double pixelsPerMillisecond = 0,
  Duration freePlaceholderDuration = const Duration(milliseconds: 500),
}) {
  assert(pixelsPerMillisecond >= 0, 'The timeline scale cannot be negative.');
  assert(
    freePlaceholderDuration > Duration.zero,
    'The free-motion placeholder must be positive.',
  );
  final lanes = <MotorTimelineLane>[];
  var totalDuration = Duration.zero;
  for (final playback in snapshot.tracks) {
    final lane = _layoutTrack(
      playback,
      pixelsPerMillisecond,
      freePlaceholderDuration,
    );
    lanes.add(lane);
    if (lane.end > totalDuration) totalDuration = lane.end;
  }
  return MotorTimelineLayout(lanes: lanes, totalDuration: totalDuration);
}

MotorTimelineLane _layoutTrack(
  TrackPlayback playback,
  double scale,
  Duration placeholder,
) {
  var cursor = Duration.zero;
  final segments = <MotorTimelineSegment>[];
  for (var index = 0; index < playback.steps.length; index++) {
    final step = playback.steps[index];
    final rawStart = playback.stepStarts[index];
    final recordedStart = rawStart != null && rawStart >= playback.cycleStart
        ? rawStart - playback.cycleStart
        : null;
    final start = playback.startOffset + (recordedStart ?? cursor);
    if (step is StepSync<Object>) {
      segments.add(
        MotorTimelineSegment(
          kind: MotorTimelineSegmentKind.barrier,
          provenance: recordedStart == null
              ? MotorTimelineProvenance.estimated
              : MotorTimelineProvenance.recorded,
          start: start,
          end: start,
          startX: _toX(start, scale),
          endX: _toX(start, scale),
        ),
      );
      continue;
    }
    final design = _designDuration(playback.track, step, placeholder, cursor);
    final actual = playback.stepDurations[index];
    final duration = actual ?? design.$2;
    final end = start + duration;
    segments.add(
      MotorTimelineSegment(
        kind: design.$1,
        provenance: recordedStart != null && actual != null
            ? MotorTimelineProvenance.recorded
            : MotorTimelineProvenance.estimated,
        start: start,
        end: end,
        startX: _toX(start, scale),
        endX: _toX(end, scale),
      ),
    );
    cursor = (recordedStart ?? cursor) + duration;
  }
  final end = segments.fold(
    playback.startOffset,
    (latest, segment) => segment.end > latest ? segment.end : latest,
  );
  var playhead = playback.startOffset + playback.playhead - playback.cycleStart;
  if (playhead < Duration.zero) playhead = Duration.zero;
  if (playhead > end) playhead = end;
  return MotorTimelineLane(
    track: playback.track,
    segments: segments,
    end: end,
    playhead: playhead,
  );
}

(MotorTimelineSegmentKind, Duration) _designDuration(
  Track<Object> track,
  TrackStep<Object> step,
  Duration placeholder,
  Duration cursor,
) {
  return switch (step) {
    StepHold<Object>(:final duration) => (
      MotorTimelineSegmentKind.hold,
      duration,
    ),
    StepFree<Object>() => (MotorTimelineSegmentKind.free, placeholder),
    StepAt<Object>(:final at) => (
      MotorTimelineSegmentKind.motion,
      at > cursor ? at - cursor : Duration.zero,
    ),
    StepTo<Object>(:final motion, :final motionPerDimension) => (
      MotorTimelineSegmentKind.motion,
      _motionDuration(track, motion, motionPerDimension) ?? placeholder,
    ),
    StepSync<Object>() => (MotorTimelineSegmentKind.barrier, Duration.zero),
  };
}

Duration? _motionDuration(
  Track<Object> track,
  Motion? motion,
  List<Motion>? perDimension,
) {
  final motions = motion != null
      ? [motion]
      : perDimension ??
            (track.motion != null ? [track.motion!] : track.motionPerDimension);
  if (motions == null || motions.isEmpty) return null;
  var duration = Duration.zero;
  for (final candidate in motions) {
    final value = candidate.duration;
    if (value == null) return null;
    if (value > duration) duration = value;
  }
  return duration;
}

double _toX(Duration duration, double scale) =>
    duration.inMicroseconds / Duration.microsecondsPerMillisecond * scale;

class _MotorTimelinePainter extends CustomPainter {
  const _MotorTimelinePainter({
    required this.layout,
    required this.accent,
    required this.scrubbing,
  });

  final MotorTimelineLayout layout;
  final Color accent;
  final bool scrubbing;

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.58),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    for (var index = 0; index < layout.lanes.length; index++) {
      final lane = layout.lanes[index];
      final y = 30 + index * _laneHeight;
      final label = lane.track.debugLabel ?? 'TRACK ${index + 1}';
      final painter = TextPainter(
        text: TextSpan(text: label.toUpperCase(), style: textStyle),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _labelWidth - 12);
      painter.paint(canvas, Offset(0, y - painter.height / 2));
      canvas.drawLine(
        Offset(_labelWidth, y),
        Offset(size.width, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.09)
          ..strokeWidth = 1,
      );
      for (final segment in lane.segments) {
        final start = _labelWidth + segment.startX;
        final end = _labelWidth + segment.endX;
        if (segment.kind == MotorTimelineSegmentKind.barrier) {
          canvas.drawCircle(Offset(start, y), 4, Paint()..color = accent);
          continue;
        }
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(start, y - 5, math.max(start + 2, end), y + 5),
          const Radius.circular(5),
        );
        final paint = Paint()
          ..color = segment.kind == MotorTimelineSegmentKind.hold
              ? Colors.white.withValues(alpha: 0.18)
              : accent.withValues(
                  alpha: segment.provenance == MotorTimelineProvenance.recorded
                      ? 0.9
                      : 0.32,
                )
          ..style = segment.provenance == MotorTimelineProvenance.recorded
              ? PaintingStyle.fill
              : PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(rect, paint);
      }
      final playhead =
          _labelWidth +
          _toX(
            lane.playhead,
            layout.totalDuration == Duration.zero
                ? 0
                : (size.width - _labelWidth) /
                      (layout.totalDuration.inMicroseconds /
                          Duration.microsecondsPerMillisecond),
          );
      canvas.drawCircle(
        Offset(playhead, y),
        scrubbing ? 4 : 2.5,
        Paint()..color = Colors.white,
      );
    }
    final duration = '${layout.totalDuration.inMilliseconds} MS';
    final durationPainter = TextPainter(
      text: TextSpan(text: duration, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    durationPainter.paint(
      canvas,
      Offset(size.width - durationPainter.width, 2),
    );
  }

  @override
  bool shouldRepaint(_MotorTimelinePainter oldDelegate) => true;
}
