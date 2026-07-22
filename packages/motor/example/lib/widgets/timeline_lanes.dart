import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:motor/motor.dart';

/// Renders a [TrackTimeline] as horizontal lanes with a moving playhead —
/// the After Effects mental model, honest about springs.
///
/// This widget does not own time. Its caller drives [playhead], including the
/// jump to zero for [LoopMode.loop] and direction reversal for
/// [LoopMode.pingPong].
class TimelineLanes extends StatefulWidget {
  /// Creates a timeline visualization.
  const TimelineLanes({
    required this.timeline,
    required this.playhead,
    this.laneLabels = const {},
    this.laneColors = const {},
    this.height = 140,
    super.key,
  });

  /// The disposable animation plan to visualize.
  final TrackTimeline timeline;

  /// The externally owned timeline clock.
  final ValueListenable<Duration> playhead;

  /// Optional display names keyed by track identity.
  final Map<Track, String> laneLabels;

  /// Optional lane colors keyed by track identity.
  final Map<Track, Color> laneColors;

  /// The fixed height of the visualization.
  final double height;

  @override
  State<TimelineLanes> createState() => _TimelineLanesState();
}

class _TimelineLanesState extends State<TimelineLanes>
    with SingleTickerProviderStateMixin {
  late final SingleMotionController _rewrite;
  TrackTimeline? _outgoingTimeline;

  @override
  void initState() {
    super.initState();
    assert(
      widget.timeline.animations.length <= 5,
      'TimelineLanes supports at most five lanes.',
    );
    _rewrite = SingleMotionController(
      motion: const CurvedMotion(
        Duration(milliseconds: 200),
        Curves.easeOutCubic,
      ),
      vsync: this,
      initialValue: 1,
    );
  }

  @override
  void didUpdateWidget(TimelineLanes oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      widget.timeline.animations.length <= 5,
      'TimelineLanes supports at most five lanes.',
    );
    if (oldWidget.timeline != widget.timeline) {
      _outgoingTimeline = oldWidget.timeline;
      _rewrite
        ..value = 0
        ..animateTo(1);
    }
  }

  @override
  void dispose() {
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
        builder: (context, _) => ValueListenableBuilder<Duration>(
          valueListenable: widget.playhead,
          builder: (context, playhead, _) => LayoutBuilder(
            builder: (context, constraints) {
              const labelWidth = 88.0;
              final stripWidth = math.max(
                0.0,
                constraints.maxWidth - labelWidth,
              );
              final incomingUnscaled = layoutTimeline(
                widget.timeline,
                pixelsPerMillisecond: 0,
              );
              final outgoingUnscaled = switch (_outgoingTimeline) {
                final timeline? => layoutTimeline(
                  timeline,
                  pixelsPerMillisecond: 0,
                ),
                null => null,
              };
              final totalDuration = _later(
                incomingUnscaled.totalDuration,
                outgoingUnscaled?.totalDuration ?? Duration.zero,
              );
              final totalMilliseconds =
                  totalDuration.inMicroseconds /
                  Duration.microsecondsPerMillisecond;
              final pixelsPerMillisecond = totalMilliseconds == 0
                  ? 0.0
                  : stripWidth / totalMilliseconds;
              final incoming = layoutTimeline(
                widget.timeline,
                pixelsPerMillisecond: pixelsPerMillisecond,
              );
              final outgoing = switch (_outgoingTimeline) {
                final timeline? => layoutTimeline(
                  timeline,
                  pixelsPerMillisecond: pixelsPerMillisecond,
                ),
                null => null,
              };

              return CustomPaint(
                size: Size(constraints.maxWidth, widget.height),
                painter: _TimelineLanesPainter(
                  incoming: incoming,
                  outgoing: outgoing,
                  transition: _rewrite.value.clamp(0, 1),
                  playhead: playhead,
                  pixelsPerMillisecond: pixelsPerMillisecond,
                  labelWidth: labelWidth,
                  laneLabels: widget.laneLabels,
                  laneColors: widget.laneColors,
                  theme: theme,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The visual treatment used for a resolved timeline segment.
enum TimelineSegmentKind {
  /// A fixed-duration target motion.
  block,

  /// A spring whose design duration is only a perceptual guide.
  feathered,

  /// A hold, represented by the lane baseline showing through.
  gap,

  /// A synchronization barrier shared by participating lanes.
  barrier,

  /// A self-directed or otherwise unbounded motion.
  free,
}

/// A single resolved segment in a [TimelineLaneLayout].
@immutable
class TimelineSegmentLayout {
  /// Creates resolved segment geometry.
  const TimelineSegmentLayout({
    required this.kind,
    required this.start,
    required this.end,
    required this.startX,
    required this.endX,
    this.barrierToken,
  });

  /// How this segment should be painted.
  final TimelineSegmentKind kind;

  /// The resolved start time from the beginning of the timeline.
  final Duration start;

  /// The resolved end time from the beginning of the timeline.
  final Duration end;

  /// The horizontal start coordinate at the requested scale.
  final double startX;

  /// The horizontal end coordinate at the requested scale.
  final double endX;

  /// The grouping token when [kind] is [TimelineSegmentKind.barrier].
  final Object? barrierToken;
}

/// The resolved segments for one track animation.
@immutable
class TimelineLaneLayout {
  /// Creates a lane layout.
  const TimelineLaneLayout({
    required this.track,
    required this.segments,
    required this.end,
  });

  /// The track represented by this lane.
  final Track<Object> track;

  /// The lane's segments in playback order.
  final List<TimelineSegmentLayout> segments;

  /// The time at which this lane finishes.
  final Duration end;
}

/// Pure layout output for a [TrackTimeline].
@immutable
class TimelineLayout {
  /// Creates timeline layout output.
  const TimelineLayout({required this.lanes, required this.totalDuration});

  /// Resolved lane geometry.
  final List<TimelineLaneLayout> lanes;

  /// The latest resolved end across all lanes.
  final Duration totalDuration;
}

/// Resolves [timeline] into lane segments at [pixelsPerMillisecond].
///
/// Free motions and target motions without a finite duration use
/// [freePlaceholderDuration] so an unbounded simulation still occupies useful
/// visual space.
@visibleForTesting
TimelineLayout layoutTimeline(
  TrackTimeline timeline, {
  required double pixelsPerMillisecond,
  Duration freePlaceholderDuration = const Duration(milliseconds: 500),
}) {
  assert(
    pixelsPerMillisecond >= 0,
    'pixelsPerMillisecond must be non-negative',
  );
  assert(
    freePlaceholderDuration > Duration.zero,
    'freePlaceholderDuration must be positive',
  );

  final builders = <_LaneBuilder>[
    for (final animation in timeline.animations) _LaneBuilder(animation),
  ];
  final participants = <Object, Set<int>>{};
  for (var laneIndex = 0; laneIndex < builders.length; laneIndex++) {
    for (final step in builders[laneIndex].animation.steps) {
      if (step case StepSync<Object>(:final token)) {
        participants.putIfAbsent(token, () => <int>{}).add(laneIndex);
      }
    }
  }

  for (final builder in builders) {
    _advanceToBarrier(
      builder,
      freePlaceholderDuration: freePlaceholderDuration,
    );
  }

  while (builders.any((builder) => !builder.isFinished)) {
    Object? readyToken;
    for (final entry in participants.entries) {
      if (entry.value.every(
        (laneIndex) => builders[laneIndex].waitingToken == entry.key,
      )) {
        readyToken = entry.key;
        break;
      }
    }
    if (readyToken == null) {
      throw StateError(
        'Timeline sync barriers cannot be resolved in playback order.',
      );
    }

    final laneIndexes = participants[readyToken]!;
    var barrierTime = Duration.zero;
    for (final laneIndex in laneIndexes) {
      barrierTime = _later(barrierTime, builders[laneIndex].cursor);
    }
    for (final laneIndex in laneIndexes) {
      final builder = builders[laneIndex];
      builder
        ..cursor = barrierTime
        ..segments.add(
          _ResolvedSegment(
            kind: TimelineSegmentKind.barrier,
            start: barrierTime,
            end: barrierTime,
            barrierToken: readyToken,
          ),
        )
        ..stepIndex += 1;
      _advanceToBarrier(
        builder,
        freePlaceholderDuration: freePlaceholderDuration,
      );
    }
  }

  var totalDuration = Duration.zero;
  final lanes = <TimelineLaneLayout>[];
  for (final builder in builders) {
    totalDuration = _later(totalDuration, builder.cursor);
    lanes.add(
      TimelineLaneLayout(
        track: builder.animation.track,
        segments: [
          for (final segment in builder.segments)
            TimelineSegmentLayout(
              kind: segment.kind,
              start: segment.start,
              end: segment.end,
              startX: _toX(segment.start, pixelsPerMillisecond),
              endX: _toX(segment.end, pixelsPerMillisecond),
              barrierToken: segment.barrierToken,
            ),
        ],
        end: builder.cursor,
      ),
    );
  }
  return TimelineLayout(lanes: lanes, totalDuration: totalDuration);
}

void _advanceToBarrier(
  _LaneBuilder builder, {
  required Duration freePlaceholderDuration,
}) {
  final steps = builder.animation.steps;
  while (builder.stepIndex < steps.length) {
    final step = steps[builder.stepIndex];
    if (step is StepSync<Object>) return;

    final start = builder.cursor;
    switch (step) {
      case StepHold<Object>(:final duration):
        builder.cursor += duration;
        builder.segments.add(
          _ResolvedSegment(
            kind: TimelineSegmentKind.gap,
            start: start,
            end: builder.cursor,
          ),
        );
      case StepFree<Object>():
        builder.cursor += freePlaceholderDuration;
        builder.segments.add(
          _ResolvedSegment(
            kind: TimelineSegmentKind.free,
            start: start,
            end: builder.cursor,
          ),
        );
      case StepTo<Object>(
        motion: final motion,
        motionPerDimension: final motionPerDimension,
      ):
        final motions = _resolveMotions(
          builder.animation.track,
          motion,
          motionPerDimension,
        );
        final resolution = _resolveTargetMotion(
          motions,
          freePlaceholderDuration,
        );
        builder.cursor += resolution.duration;
        builder.segments.add(
          _ResolvedSegment(
            kind: resolution.kind,
            start: start,
            end: builder.cursor,
          ),
        );
      case StepAt<Object>(
        at: final at,
        motion: final motion,
        motionPerDimension: final motionPerDimension,
      ):
        if (at < start) {
          throw StateError(
            'TrackStep.at(${at.inMilliseconds}ms) precedes the resolved '
            'lane time (${start.inMilliseconds}ms).',
          );
        }
        final motions = _resolveMotions(
          builder.animation.track,
          motion,
          motionPerDimension,
        );
        // TrackStep.at defines `at` as absolute time from the start of the
        // track animation (packages/motor/lib/src/track_step.dart:131-132).
        builder.cursor = at;
        builder.segments.add(
          _ResolvedSegment(
            kind: _targetKind(motions),
            start: start,
            end: builder.cursor,
          ),
        );
      case StepSync<Object>():
        throw StateError('Sync steps are handled before lane advancement.');
    }
    builder.stepIndex++;
  }
}

List<Motion> _resolveMotions(
  Track<Object> track,
  Motion? motion,
  List<Motion>? motionPerDimension,
) {
  if (motion != null) return [motion];
  if (motionPerDimension != null) return motionPerDimension;
  if (track.motion case final defaultMotion?) return [defaultMotion];
  return track.motionPerDimension ?? const [];
}

_TargetResolution _resolveTargetMotion(
  List<Motion> motions,
  Duration placeholder,
) {
  if (motions.isEmpty || motions.any((motion) => motion.duration == null)) {
    return _TargetResolution(
      kind: TimelineSegmentKind.free,
      duration: placeholder,
    );
  }
  var duration = Duration.zero;
  for (final motion in motions) {
    duration = _later(duration, motion.duration!);
  }
  return _TargetResolution(kind: _targetKind(motions), duration: duration);
}

TimelineSegmentKind _targetKind(List<Motion> motions) =>
    motions.any((motion) => motion is SpringMotion)
    ? TimelineSegmentKind.feathered
    : TimelineSegmentKind.block;

double _toX(Duration duration, double pixelsPerMillisecond) =>
    duration.inMicroseconds /
    Duration.microsecondsPerMillisecond *
    pixelsPerMillisecond;

Duration _later(Duration a, Duration b) => a > b ? a : b;

class _LaneBuilder {
  _LaneBuilder(this.animation);

  final TrackAnimation<Object> animation;
  final List<_ResolvedSegment> segments = [];
  int stepIndex = 0;
  Duration cursor = Duration.zero;

  bool get isFinished => stepIndex >= animation.steps.length;

  Object? get waitingToken {
    if (isFinished) return null;
    return switch (animation.steps[stepIndex]) {
      StepSync<Object>(:final token) => token,
      _ => null,
    };
  }
}

@immutable
class _ResolvedSegment {
  const _ResolvedSegment({
    required this.kind,
    required this.start,
    required this.end,
    this.barrierToken,
  });

  final TimelineSegmentKind kind;
  final Duration start;
  final Duration end;
  final Object? barrierToken;
}

@immutable
class _TargetResolution {
  const _TargetResolution({required this.kind, required this.duration});

  final TimelineSegmentKind kind;
  final Duration duration;
}

class _TimelineLanesPainter extends CustomPainter {
  _TimelineLanesPainter({
    required this.incoming,
    required this.outgoing,
    required this.transition,
    required this.playhead,
    required this.pixelsPerMillisecond,
    required this.labelWidth,
    required this.laneLabels,
    required this.laneColors,
    required this.theme,
  });

  static const _captionHeight = 20.0;

  final TimelineLayout incoming;
  final TimelineLayout? outgoing;
  final double transition;
  final Duration playhead;
  final double pixelsPerMillisecond;
  final double labelWidth;
  final Map<Track, String> laneLabels;
  final Map<Track, Color> laneColors;
  final ExampleTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (outgoing case final layout?) {
      _paintLayer(
        canvas,
        size,
        layout,
        opacity: 1 - transition,
        verticalOffset: transition * 8,
      );
    }
    _paintLayer(
      canvas,
      size,
      incoming,
      opacity: transition,
      verticalOffset: (transition - 1) * 8,
    );

    final playheadX =
        labelWidth +
        _toX(
          playhead,
          pixelsPerMillisecond,
        ).clamp(0, math.max(0, size.width - labelWidth));
    canvas.drawRect(
      Rect.fromLTWH(playheadX - 1, _captionHeight, 2, size.height),
      Paint()..color = theme.textPrimary,
    );
    canvas.restore();
  }

  void _paintLayer(
    Canvas canvas,
    Size size,
    TimelineLayout layout, {
    required double opacity,
    required double verticalOffset,
  }) {
    if (opacity <= 0 || layout.lanes.isEmpty) return;
    final laneHeight = (size.height - _captionHeight) / layout.lanes.length;
    final segmentHeight = math.min(18.0, laneHeight * 0.46);

    for (var laneIndex = 0; laneIndex < layout.lanes.length; laneIndex++) {
      final lane = layout.lanes[laneIndex];
      final centerY =
          _captionHeight + laneHeight * (laneIndex + 0.5) + verticalOffset;
      final color = laneColors[lane.track] ?? theme.textSecondary;

      canvas.drawLine(
        Offset(labelWidth, centerY),
        Offset(size.width, centerY),
        Paint()
          ..color = theme.border.withValues(alpha: opacity)
          ..strokeWidth = 1,
      );
      _paintLabel(
        canvas,
        laneLabels[lane.track] ?? 'lane ${laneIndex + 1}',
        color.withValues(alpha: opacity),
        centerY,
      );

      for (final segment in lane.segments) {
        if (segment.kind == TimelineSegmentKind.gap ||
            segment.kind == TimelineSegmentKind.barrier) {
          continue;
        }
        final rect = Rect.fromLTRB(
          labelWidth + segment.startX,
          centerY - segmentHeight / 2,
          labelWidth + segment.endX,
          centerY + segmentHeight / 2,
        );
        _paintSegment(canvas, rect, segment.kind, color, opacity);
      }
    }
    _paintBarriers(
      canvas,
      size,
      layout,
      laneHeight: laneHeight,
      opacity: opacity,
      verticalOffset: verticalOffset,
    );
  }

  void _paintLabel(Canvas canvas, String label, Color color, double centerY) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: const ['monospace', 'Menlo'],
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: labelWidth - 10);
    painter.paint(canvas, Offset(0, centerY - painter.height / 2));
  }

  void _paintSegment(
    Canvas canvas,
    Rect rect,
    TimelineSegmentKind kind,
    Color color,
    double opacity,
  ) {
    if (rect.width <= 0) return;
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    switch (kind) {
      case TimelineSegmentKind.block:
        canvas
          ..drawRRect(
            rounded,
            Paint()..color = color.withValues(alpha: 0.18 * opacity),
          )
          ..drawRRect(
            rounded,
            Paint()
              ..color = color.withValues(alpha: 0.55 * opacity)
              ..style = PaintingStyle.stroke,
          );
      case TimelineSegmentKind.feathered:
        canvas.drawRRect(
          rounded,
          Paint()
            ..shader = LinearGradient(
              colors: [
                color.withValues(alpha: 0.26 * opacity),
                color.withValues(alpha: 0.26 * opacity),
                color.withValues(alpha: 0),
              ],
              stops: const [0, 0.75, 1],
            ).createShader(rect),
        );
      case TimelineSegmentKind.free:
        _drawDashedPath(
          canvas,
          Path()..addRRect(rounded),
          Paint()
            ..color = color.withValues(alpha: 0.7 * opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case TimelineSegmentKind.gap:
      case TimelineSegmentKind.barrier:
        break;
    }
  }

  void _paintBarriers(
    Canvas canvas,
    Size size,
    TimelineLayout layout, {
    required double laneHeight,
    required double opacity,
    required double verticalOffset,
  }) {
    final barriers = <(Object, Duration), List<int>>{};
    for (var laneIndex = 0; laneIndex < layout.lanes.length; laneIndex++) {
      for (final segment in layout.lanes[laneIndex].segments) {
        if (segment.kind == TimelineSegmentKind.barrier) {
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
      final laneIndexes = entry.value;
      final firstLane = laneIndexes.reduce(math.min);
      final lastLane = laneIndexes.reduce(math.max);
      final x = labelWidth + _toX(entry.key.$2, pixelsPerMillisecond);
      final top = _captionHeight + laneHeight * firstLane + verticalOffset;
      final bottom =
          _captionHeight + laneHeight * (lastLane + 1) + verticalOffset;
      final color = theme.textTertiary.withValues(alpha: opacity);
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        Paint()
          ..color = color
          ..strokeWidth = 1,
      );
      final caption = TextPainter(
        text: TextSpan(
          text: _barrierLabel(entry.key.$1),
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontFamily: 'JetBrains Mono',
            fontFamilyFallback: const ['monospace', 'Menlo'],
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(0, size.width - x));
      caption.paint(canvas, Offset(x + 3, math.max(0, top - 15)));
    }
  }

  @override
  bool shouldRepaint(_TimelineLanesPainter oldDelegate) =>
      oldDelegate.incoming != incoming ||
      oldDelegate.outgoing != outgoing ||
      oldDelegate.transition != transition ||
      oldDelegate.playhead != playhead ||
      oldDelegate.pixelsPerMillisecond != pixelsPerMillisecond ||
      oldDelegate.labelWidth != labelWidth ||
      oldDelegate.laneLabels != laneLabels ||
      oldDelegate.laneColors != laneColors ||
      oldDelegate.theme != theme;
}

void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
  const dashLength = 4.0;
  const gapLength = 3.0;
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      canvas.drawPath(
        metric.extractPath(
          distance,
          math.min(distance + dashLength, metric.length),
        ),
        paint,
      );
      distance += dashLength + gapLength;
    }
  }
}

String _barrierLabel(Object token) {
  final text = token.toString();
  const prefix = 'Symbol("';
  if (text.startsWith(prefix) && text.endsWith('")')) {
    return '#${text.substring(prefix.length, text.length - 2)}';
  }
  return text.startsWith('#') ? text : '#$text';
}
