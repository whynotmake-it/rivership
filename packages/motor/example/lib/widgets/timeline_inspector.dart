import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

const _labelWidth = 82.0;

/// Attaches to a [TrackController] and renders its live playback as lanes.
///
/// Solid segments use timings recorded by the engine; translucent dotted
/// segments are still estimates based on the motion's design duration. Drag
/// across the strip to pause, inspect a point in time, and resume from it.
class TimelineInspector extends StatefulWidget {
  /// Creates a live playback inspector.
  const TimelineInspector({
    required this.controller,
    this.laneLabels = const {},
    this.laneColors = const {},
    this.laneGroups = const [],
    this.scrubbable = true,
    this.height = 164,
    super.key,
  });

  /// The controller whose running plans and timing should be inspected.
  final TrackController controller;

  /// Optional display names keyed by track identity.
  final Map<Track, String> laneLabels;

  /// Optional colors keyed by track identity.
  final Map<Track, Color> laneColors;

  /// Track sets that should be collapsed into one union lane.
  final List<Set<Track>> laneGroups;

  /// Whether dragging the strip pauses and scrubs the controller.
  final bool scrubbable;

  /// The fixed inspector height.
  final double height;

  @override
  State<TimelineInspector> createState() => _TimelineInspectorState();
}

class _TimelineInspectorState extends State<TimelineInspector>
    with SingleTickerProviderStateMixin {
  late final SingleMotionController _rewrite;
  late PlaybackSnapshot _snapshot;
  PlaybackSnapshot? _outgoing;
  var _scrubbing = false;
  var _totalDuration = Duration.zero;
  var _stripWidth = 0.0;
  Duration? _pendingScrub;
  var _scrubScheduled = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.controller.inspectPlayback();
    widget.controller.addListener(_onControllerChanged);
    _rewrite = SingleMotionController(
      motion: const CurvedMotion(
        Duration(milliseconds: 220),
        Curves.easeOutCubic,
      ),
      vsync: this,
      initialValue: 1,
    );
  }

  @override
  void didUpdateWidget(TimelineInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _snapshot = widget.controller.inspectPlayback();
      _outgoing = null;
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final next = widget.controller.inspectPlayback();
    final rewrote = next.revision != _snapshot.revision && !_scrubbing;
    setState(() {
      if (rewrote) _outgoing = _snapshot;
      _snapshot = next;
    });
    if (rewrote) {
      _rewrite
        ..value = 0
        ..animateTo(1);
    }
  }

  bool get _canScrub =>
      widget.scrubbable &&
      _snapshot.tracks.any((playback) => playback.currentStepIndex >= 0);

  void _onPanStart(DragStartDetails details) {
    if (!_canScrub) return;
    widget.controller.pause();
    setState(() => _scrubbing = true);
    _queueScrub(details.localPosition.dx);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_scrubbing) return;
    _queueScrub(details.localPosition.dx);
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
      if (target != null && _scrubbing) widget.controller.scrubTo(target);
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
    widget.controller.removeListener(_onControllerChanged);
    _rewrite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ExampleTheme.of(context);
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _rewrite,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            _stripWidth = math.max(0, constraints.maxWidth - _labelWidth);
            final unscaled = layoutPlayback(
              _snapshot,
              pixelsPerMillisecond: 0,
              laneGroups: widget.laneGroups,
            );
            final outgoingUnscaled = switch (_outgoing) {
              final snapshot? => layoutPlayback(
                snapshot,
                pixelsPerMillisecond: 0,
                laneGroups: widget.laneGroups,
              ),
              null => null,
            };
            _totalDuration = _later(
              unscaled.totalDuration,
              outgoingUnscaled?.totalDuration ?? Duration.zero,
            );
            final milliseconds =
                _totalDuration.inMicroseconds /
                Duration.microsecondsPerMillisecond;
            final scale = milliseconds == 0 ? 0.0 : _stripWidth / milliseconds;
            final incoming = layoutPlayback(
              _snapshot,
              pixelsPerMillisecond: scale,
              laneGroups: widget.laneGroups,
            );
            final outgoing = switch (_outgoing) {
              final snapshot? => layoutPlayback(
                snapshot,
                pixelsPerMillisecond: scale,
                laneGroups: widget.laneGroups,
              ),
              null => null,
            };

            return Semantics(
              label: 'Live timeline inspector',
              hint: _canScrub ? 'Drag horizontally to scrub playback' : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _canScrub ? _onPanStart : null,
                onHorizontalDragUpdate: _canScrub ? _onPanUpdate : null,
                onHorizontalDragEnd: _canScrub ? (_) => _finishScrub() : null,
                onHorizontalDragCancel: _canScrub ? _finishScrub : null,
                child: CustomPaint(
                  key: const ValueKey('timeline-inspector-canvas'),
                  size: Size(constraints.maxWidth, widget.height),
                  painter: _TimelineInspectorPainter(
                    incoming: incoming,
                    outgoing: outgoing,
                    transition: _rewrite.value.clamp(0, 1),
                    pixelsPerMillisecond: scale,
                    laneLabels: widget.laneLabels,
                    laneColors: widget.laneColors,
                    theme: theme,
                    paused: _scrubbing,
                    enabled: _canScrub,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Whether segment geometry is estimated or measured by the engine.
enum TimelineTimingProvenance {
  /// Geometry derived from the motion's design duration.
  estimated,

  /// Geometry recorded from actual playback.
  recorded,
}

/// The visual treatment used for a resolved playback segment.
enum TimelineSegmentKind {
  /// A fixed-duration target motion.
  block,

  /// A spring with a feathered settling tail.
  feathered,

  /// A hold represented by the lane baseline.
  gap,

  /// A synchronization barrier shared by participating lanes.
  barrier,

  /// A self-directed or otherwise unbounded motion.
  free,
}

/// A segment resolved from a live playback snapshot.
@immutable
class TimelineSegmentLayout {
  /// Creates resolved segment geometry.
  const TimelineSegmentLayout({
    required this.kind,
    required this.provenance,
    required this.start,
    required this.end,
    required this.startX,
    required this.endX,
    this.barrierToken,
  });

  /// How this segment should be painted.
  final TimelineSegmentKind kind;

  /// Whether the timing is estimated or recorded.
  final TimelineTimingProvenance provenance;

  /// Resolved start time on the controller-aligned axis.
  final Duration start;

  /// Resolved end time on the controller-aligned axis.
  final Duration end;

  /// Horizontal start coordinate at the requested scale.
  final double startX;

  /// Horizontal end coordinate at the requested scale.
  final double endX;

  /// The synchronization token for barrier segments.
  final Object? barrierToken;
}

/// Resolved geometry and playhead for one rendered lane.
@immutable
class TimelineLaneLayout {
  /// Creates a lane layout.
  const TimelineLaneLayout({
    required this.track,
    required this.tracks,
    required this.segments,
    required this.end,
    required this.playhead,
  });

  /// The primary track used for labels and colors.
  final Track<Object> track;

  /// Every track represented by this lane.
  final Set<Track<Object>> tracks;

  /// The lane's segments in playback order.
  final List<TimelineSegmentLayout> segments;

  /// The time at which this lane finishes.
  final Duration end;

  /// The visible playhead position for this lane.
  final Duration playhead;
}

/// Pure layout output for a playback snapshot.
@immutable
class TimelineInspectorLayout {
  /// Creates inspector layout output.
  const TimelineInspectorLayout({
    required this.lanes,
    required this.totalDuration,
  });

  /// Resolved lane geometry.
  final List<TimelineLaneLayout> lanes;

  /// The latest resolved end across all lanes.
  final Duration totalDuration;
}

/// Resolves [snapshot] into controller-aligned live lane geometry.
///
/// Recorded starts and settle durations replace estimates as they become
/// available. [laneGroups] collapse related tracks into union lanes.
@visibleForTesting
TimelineInspectorLayout layoutPlayback(
  PlaybackSnapshot snapshot, {
  required double pixelsPerMillisecond,
  List<Set<Track>> laneGroups = const [],
  Duration freePlaceholderDuration = const Duration(milliseconds: 500),
}) {
  assert(pixelsPerMillisecond >= 0);
  assert(freePlaceholderDuration > Duration.zero);

  final byTrack = <Track, TrackPlayback>{
    for (final playback in snapshot.tracks) playback.track: playback,
  };
  final consumed = <Track>{};
  final lanes = <TimelineLaneLayout>[];

  for (final playback in snapshot.tracks) {
    if (consumed.contains(playback.track)) continue;
    final group = laneGroups.where((group) => group.contains(playback.track));
    if (group.isEmpty) {
      lanes.add(
        _layoutTrack(
          playback,
          pixelsPerMillisecond: pixelsPerMillisecond,
          freePlaceholderDuration: freePlaceholderDuration,
        ),
      );
      consumed.add(playback.track);
      continue;
    }
    final members = [
      for (final track in group.first)
        if (byTrack[track] case final member?) member,
    ];
    consumed.addAll(group.first);
    if (members.isNotEmpty) {
      lanes.add(
        _mergeGroup(
          members,
          pixelsPerMillisecond: pixelsPerMillisecond,
          freePlaceholderDuration: freePlaceholderDuration,
        ),
      );
    }
  }

  assert(lanes.length <= 5, 'TimelineInspector supports at most five lanes.');
  var total = Duration.zero;
  for (final lane in lanes) {
    total = _later(total, lane.end);
  }
  return TimelineInspectorLayout(lanes: lanes, totalDuration: total);
}

TimelineLaneLayout _layoutTrack(
  TrackPlayback playback, {
  required double pixelsPerMillisecond,
  required Duration freePlaceholderDuration,
}) {
  final axisStart = playback.startOffset > Duration.zero
      ? playback.startOffset
      : Duration.zero;
  var cursor = Duration.zero;
  final segments = <TimelineSegmentLayout>[];

  for (var index = 0; index < playback.steps.length; index++) {
    final step = playback.steps[index];
    final rawStart = playback.stepStarts[index];
    final recordedStart = rawStart != null && rawStart >= playback.cycleStart
        ? rawStart - playback.cycleStart
        : null;
    final localStart = recordedStart ?? cursor;

    if (step case StepSync<Object>(:final token)) {
      final rawRelease = index + 1 < playback.stepStarts.length
          ? playback.stepStarts[index + 1]
          : null;
      final release = rawRelease != null && rawRelease >= playback.cycleStart
          ? rawRelease - playback.cycleStart
          : localStart;
      final point = axisStart + release;
      segments.add(
        TimelineSegmentLayout(
          kind: TimelineSegmentKind.barrier,
          provenance: rawRelease == null
              ? TimelineTimingProvenance.estimated
              : TimelineTimingProvenance.recorded,
          start: point,
          end: point,
          startX: _toX(point, pixelsPerMillisecond),
          endX: _toX(point, pixelsPerMillisecond),
          barrierToken: token,
        ),
      );
      cursor = release;
      continue;
    }

    final design = _designSegment(
      playback.track,
      step,
      start: localStart,
      freePlaceholderDuration: freePlaceholderDuration,
    );
    final actual = playback.stepDurations[index];
    final duration = actual ?? design.$2;
    final localEnd = localStart + duration;
    final start = axisStart + localStart;
    final end = axisStart + localEnd;
    segments.add(
      TimelineSegmentLayout(
        kind: design.$1,
        provenance: recordedStart != null && actual != null
            ? TimelineTimingProvenance.recorded
            : TimelineTimingProvenance.estimated,
        start: start,
        end: end,
        startX: _toX(start, pixelsPerMillisecond),
        endX: _toX(end, pixelsPerMillisecond),
      ),
    );
    cursor = localEnd;
  }

  final end = segments.fold<Duration>(
    axisStart,
    (latest, segment) => _later(latest, segment.end),
  );
  var within = playback.playhead - playback.cycleStart;
  if (within < Duration.zero) within = Duration.zero;
  if (playback.direction < 0) {
    within = cursor - within;
  }
  final playhead = axisStart + within;
  return TimelineLaneLayout(
    track: playback.track,
    tracks: {playback.track},
    segments: segments,
    end: end,
    playhead: playhead.clamp(Duration.zero, end),
  );
}

TimelineLaneLayout _mergeGroup(
  List<TrackPlayback> playbacks, {
  required double pixelsPerMillisecond,
  required Duration freePlaceholderDuration,
}) {
  final source = [
    for (final playback in playbacks)
      _layoutTrack(
        playback,
        pixelsPerMillisecond: pixelsPerMillisecond,
        freePlaceholderDuration: freePlaceholderDuration,
      ),
  ];
  final merged = <TimelineSegmentLayout>[];
  final count = source.fold<int>(
    0,
    (value, lane) => math.max(value, lane.segments.length),
  );
  for (var index = 0; index < count; index++) {
    final parts = [
      for (final lane in source)
        if (index < lane.segments.length) lane.segments[index],
    ];
    if (parts.isEmpty) continue;
    var start = parts.first.start;
    var end = parts.first.end;
    for (final part in parts.skip(1)) {
      if (part.start < start) start = part.start;
      if (part.end > end) end = part.end;
    }
    final kind = _strongestKind(parts.map((part) => part.kind));
    merged.add(
      TimelineSegmentLayout(
        kind: kind,
        provenance:
            parts.every(
              (part) => part.provenance == TimelineTimingProvenance.recorded,
            )
            ? TimelineTimingProvenance.recorded
            : TimelineTimingProvenance.estimated,
        start: start,
        end: end,
        startX: _toX(start, pixelsPerMillisecond),
        endX: _toX(end, pixelsPerMillisecond),
        barrierToken: parts
            .firstWhere(
              (part) => part.barrierToken != null,
              orElse: () => parts.first,
            )
            .barrierToken,
      ),
    );
  }
  final end = source.fold<Duration>(
    Duration.zero,
    (value, lane) => _later(value, lane.end),
  );
  final playhead = source.fold<Duration>(
    Duration.zero,
    (value, lane) => _later(value, lane.playhead),
  );
  return TimelineLaneLayout(
    track: playbacks.first.track,
    tracks: {for (final playback in playbacks) playback.track},
    segments: merged,
    end: end,
    playhead: playhead.clamp(Duration.zero, end),
  );
}

(TimelineSegmentKind, Duration) _designSegment(
  Track<Object> track,
  TrackStep<Object> step, {
  required Duration start,
  required Duration freePlaceholderDuration,
}) {
  return switch (step) {
    StepHold<Object>(:final duration) => (TimelineSegmentKind.gap, duration),
    StepFree<Object>() => (TimelineSegmentKind.free, freePlaceholderDuration),
    StepAt<Object>(:final at, :final motion, :final motionPerDimension) => (
      _targetKind(_resolveMotions(track, motion, motionPerDimension)),
      at > start ? at - start : Duration.zero,
    ),
    StepTo<Object>(:final motion, :final motionPerDimension) =>
      _targetResolution(
        _resolveMotions(track, motion, motionPerDimension),
        freePlaceholderDuration,
      ),
    StepSync<Object>() => (TimelineSegmentKind.barrier, Duration.zero),
  };
}

List<Motion> _resolveMotions(
  Track<Object> track,
  Motion? motion,
  List<Motion>? motionPerDimension,
) {
  if (motion != null) return [motion];
  if (motionPerDimension != null) return motionPerDimension;
  if (track.motion case final fallback?) return [fallback];
  return track.motionPerDimension ?? const [];
}

(TimelineSegmentKind, Duration) _targetResolution(
  List<Motion> motions,
  Duration placeholder,
) {
  if (motions.isEmpty || motions.any((motion) => motion.duration == null)) {
    return (TimelineSegmentKind.free, placeholder);
  }
  var duration = Duration.zero;
  for (final motion in motions) {
    duration = _later(duration, motion.duration!);
  }
  return (_targetKind(motions), duration);
}

TimelineSegmentKind _targetKind(List<Motion> motions) =>
    motions.any((motion) => motion is SpringMotion)
    ? TimelineSegmentKind.feathered
    : TimelineSegmentKind.block;

TimelineSegmentKind _strongestKind(Iterable<TimelineSegmentKind> kinds) {
  const order = [
    TimelineSegmentKind.gap,
    TimelineSegmentKind.free,
    TimelineSegmentKind.block,
    TimelineSegmentKind.feathered,
    TimelineSegmentKind.barrier,
  ];
  return kinds.reduce((a, b) => order.indexOf(a) > order.indexOf(b) ? a : b);
}

class _TimelineInspectorPainter extends CustomPainter {
  _TimelineInspectorPainter({
    required this.incoming,
    required this.outgoing,
    required this.transition,
    required this.pixelsPerMillisecond,
    required this.laneLabels,
    required this.laneColors,
    required this.theme,
    required this.paused,
    required this.enabled,
  });

  static const _headerHeight = 28.0;

  final TimelineInspectorLayout incoming;
  final TimelineInspectorLayout? outgoing;
  final double transition;
  final double pixelsPerMillisecond;
  final Map<Track, String> laneLabels;
  final Map<Track, Color> laneColors;
  final ExampleTheme theme;
  final bool paused;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
    );
    _paintHeader(canvas, size);
    if (outgoing case final layout?) {
      _paintLayer(
        canvas,
        size,
        layout,
        opacity: 1 - transition,
        verticalOffset: transition * 7,
      );
    }
    _paintLayer(
      canvas,
      size,
      incoming,
      opacity: transition,
      verticalOffset: (transition - 1) * 7,
    );
    canvas.restore();
  }

  void _paintHeader(Canvas canvas, Size size) {
    _text(
      canvas,
      'LIVE PLAYBACK',
      const Offset(12, 0),
      color: theme.textTertiary,
      size: 9,
      weight: FontWeight.w600,
      letterSpacing: 1.1,
      maxWidth: size.width,
    );
    final state = paused ? 'PAUSED · RELEASE TO PLAY' : 'DRAG TO SCRUB';
    final color = paused ? ExampleTheme.marigold : theme.textTertiary;
    final painter = _textPainter(
      state,
      color: color,
      size: 9,
      weight: FontWeight.w600,
      letterSpacing: .5,
    )..layout();
    painter.paint(canvas, Offset(size.width - painter.width - 12, 0));

    final legendY = 16.0;
    canvas.drawLine(
      Offset(_labelWidth, legendY),
      Offset(_labelWidth + 14, legendY),
      Paint()
        ..color = theme.textSecondary
        ..strokeWidth = 2,
    );
    _text(
      canvas,
      'measured',
      const Offset(_labelWidth + 18, 10),
      color: theme.textTertiary,
      size: 8,
      maxWidth: 60,
    );
    _drawDashedLine(
      canvas,
      Offset(_labelWidth + 79, legendY),
      Offset(_labelWidth + 93, legendY),
      Paint()..color = theme.textTertiary,
    );
    _text(
      canvas,
      'estimate',
      const Offset(_labelWidth + 97, 10),
      color: theme.textTertiary,
      size: 8,
      maxWidth: 60,
    );
  }

  void _paintLayer(
    Canvas canvas,
    Size size,
    TimelineInspectorLayout layout, {
    required double opacity,
    required double verticalOffset,
  }) {
    if (opacity <= 0 || layout.lanes.isEmpty) {
      if (layout.lanes.isEmpty) {
        _text(
          canvas,
          'Play a timeline to inspect it',
          Offset(_labelWidth, _headerHeight + 28),
          color: theme.textTertiary,
          size: 11,
          maxWidth: size.width - _labelWidth,
        );
      }
      return;
    }
    final laneHeight = (size.height - _headerHeight) / layout.lanes.length;
    final segmentHeight = math.min(18.0, laneHeight * .46);
    for (var laneIndex = 0; laneIndex < layout.lanes.length; laneIndex++) {
      final lane = layout.lanes[laneIndex];
      final y = _headerHeight + laneHeight * (laneIndex + .5) + verticalOffset;
      final color = laneColors[lane.track] ?? theme.textSecondary;
      canvas.drawLine(
        Offset(_labelWidth, y),
        Offset(size.width, y),
        Paint()..color = theme.border.withValues(alpha: opacity),
      );
      _text(
        canvas,
        laneLabels[lane.track] ?? 'lane ${laneIndex + 1}',
        Offset(0, y - 7),
        color: color.withValues(alpha: opacity),
        size: 10,
        maxWidth: _labelWidth - 8,
      );
      for (final segment in lane.segments) {
        if (segment.kind == TimelineSegmentKind.gap ||
            segment.kind == TimelineSegmentKind.barrier) {
          continue;
        }
        final rect = Rect.fromLTRB(
          _labelWidth + segment.startX,
          y - segmentHeight / 2,
          _labelWidth + segment.endX,
          y + segmentHeight / 2,
        );
        _paintSegment(canvas, rect, segment, color, opacity);
      }
      final playheadX =
          _labelWidth +
          _toX(
            lane.playhead,
            pixelsPerMillisecond,
          ).clamp(0, math.max(0, size.width - _labelWidth));
      canvas.drawCircle(
        Offset(playheadX, y),
        paused ? 5 : 3.5,
        Paint()
          ..color = (enabled ? theme.textPrimary : theme.textTertiary)
              .withValues(alpha: opacity),
      );
    }
    _paintBarriers(canvas, size, layout, laneHeight, opacity, verticalOffset);
  }

  void _paintSegment(
    Canvas canvas,
    Rect rect,
    TimelineSegmentLayout segment,
    Color color,
    double opacity,
  ) {
    if (rect.width <= 0) return;
    final recorded = segment.provenance == TimelineTimingProvenance.recorded;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    final alpha = (recorded ? .30 : .13) * opacity;
    switch (segment.kind) {
      case TimelineSegmentKind.feathered:
        canvas.drawRRect(
          rrect,
          Paint()
            ..shader = LinearGradient(
              colors: [
                color.withValues(alpha: alpha),
                color.withValues(alpha: alpha),
                color.withValues(alpha: 0),
              ],
              stops: const [0, .7, 1],
            ).createShader(rect),
        );
      case TimelineSegmentKind.free:
        _drawDashedPath(
          canvas,
          Path()..addRRect(rrect),
          Paint()
            ..color = color.withValues(alpha: .65 * opacity)
            ..style = PaintingStyle.stroke,
        );
      case TimelineSegmentKind.block:
        canvas.drawRRect(
          rrect,
          Paint()..color = color.withValues(alpha: alpha),
        );
      case TimelineSegmentKind.gap:
      case TimelineSegmentKind.barrier:
        break;
    }
    final border = Paint()
      ..color = color.withValues(alpha: (recorded ? .8 : .42) * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = recorded ? 1.25 : 1;
    if (recorded) {
      canvas.drawRRect(rrect, border);
    } else {
      _drawDashedPath(canvas, Path()..addRRect(rrect), border);
    }
  }

  void _paintBarriers(
    Canvas canvas,
    Size size,
    TimelineInspectorLayout layout,
    double laneHeight,
    double opacity,
    double verticalOffset,
  ) {
    final barriers = <(Object, Duration), List<int>>{};
    for (var laneIndex = 0; laneIndex < layout.lanes.length; laneIndex++) {
      for (final segment in layout.lanes[laneIndex].segments) {
        if (segment.kind == TimelineSegmentKind.barrier &&
            segment.barrierToken != null) {
          barriers
              .putIfAbsent((
                segment.barrierToken!,
                segment.start,
              ), () => <int>[])
              .add(laneIndex);
        }
      }
    }
    for (final entry in barriers.entries) {
      final first = entry.value.reduce(math.min);
      final last = entry.value.reduce(math.max);
      final x = _labelWidth + _toX(entry.key.$2, pixelsPerMillisecond);
      final top = _headerHeight + laneHeight * first + verticalOffset;
      final bottom = _headerHeight + laneHeight * (last + 1) + verticalOffset;
      final paint = Paint()
        ..color = ExampleTheme.marigold.withValues(alpha: .72 * opacity)
        ..strokeWidth = 1;
      _drawDashedLine(canvas, Offset(x, top), Offset(x, bottom), paint);
      _text(
        canvas,
        _barrierLabel(entry.key.$1),
        Offset(x + 3, math.max(_headerHeight, top - 13)),
        color: ExampleTheme.marigold.withValues(alpha: opacity),
        size: 8,
        maxWidth: math.max(0, size.width - x),
      );
    }
  }

  @override
  bool shouldRepaint(_TimelineInspectorPainter oldDelegate) => true;
}

TextPainter _textPainter(
  String value, {
  required Color color,
  required double size,
  FontWeight? weight,
  double? letterSpacing,
}) => TextPainter(
  text: TextSpan(
    text: value,
    style: TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: const ['monospace', 'Menlo'],
    ),
  ),
  maxLines: 1,
  ellipsis: '…',
  textDirection: TextDirection.ltr,
);

void _text(
  Canvas canvas,
  String value,
  Offset offset, {
  required Color color,
  required double size,
  required double maxWidth,
  FontWeight? weight,
  double? letterSpacing,
}) {
  final painter = _textPainter(
    value,
    color: color,
    size: size,
    weight: weight,
    letterSpacing: letterSpacing,
  )..layout(maxWidth: math.max(0, maxWidth));
  painter.paint(canvas, offset);
}

void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      canvas.drawPath(
        metric.extractPath(distance, math.min(distance + 4, metric.length)),
        paint,
      );
      distance += 7;
    }
  }
}

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  final path = Path()
    ..moveTo(start.dx, start.dy)
    ..lineTo(end.dx, end.dy);
  _drawDashedPath(canvas, path, paint);
}

String _barrierLabel(Object token) {
  final text = token.toString();
  const prefix = 'Symbol("';
  if (text.startsWith(prefix) && text.endsWith('")')) {
    return '#${text.substring(prefix.length, text.length - 2)}';
  }
  return text.startsWith('#') ? text : '#$text';
}

double _toX(Duration duration, double pixelsPerMillisecond) =>
    duration.inMicroseconds /
    Duration.microsecondsPerMillisecond *
    pixelsPerMillisecond;

Duration _later(Duration a, Duration b) => a > b ? a : b;

extension on Duration {
  Duration clamp(Duration lower, Duration upper) {
    if (this < lower) return lower;
    if (this > upper) return upper;
    return this;
  }
}
