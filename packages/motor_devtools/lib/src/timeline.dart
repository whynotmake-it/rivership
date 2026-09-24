import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/flag.dart';
import 'package:motor_devtools/src/motion_editor.dart';
import 'package:motor_devtools/src/naming.dart';
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

/// A live timeline of every track on [controller].
///
/// When [interactive], dragging or tapping pauses the controller and scrubs
/// its playback clock, resuming on release if it was running. When
/// [collapsible], it shows one summary lane and unfolds the tracks on tap.
class Timeline extends StatefulWidget {
  /// Creates a timeline for [controller].
  const Timeline({
    required this.controller,
    this.trackMotion,
    this.trackEditor,
    this.onResetTrack,
    this.interactive = true,
    this.collapsible = true,
    this.lanes,
    super.key,
  });

  /// The lanes to show, or null for one per track.
  final List<MotorTimelineLane>? lanes;

  /// The controller to show.
  final TrackController controller;

  /// Describes the motion that replaces a track's authored one, or null
  /// when there is none.
  final String? Function(Track<Object> track)? trackMotion;

  /// The editor that opens under a track's row when it is tapped. Rows
  /// without it can't be edited.
  final Widget Function(Track<Object> track)? trackEditor;

  /// Restores a track's authored motion.
  final void Function(Track<Object> track)? onResetTrack;

  /// Whether dragging and tapping scrubs the controller.
  final bool interactive;

  /// Whether the tracks start folded into a summary lane.
  final bool collapsible;

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  TimelineWindow? _frozen;
  var _resumeAfterScrub = false;
  var _showTracks = false;
  Track<Object>? _openTrack;

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

  Widget _scrubArea(
    TimelineWindow window,
    double width,
    Widget child, {
    Key? key,
  }) {
    if (!widget.interactive) return child;
    double fractionAt(Offset position) => position.dx / width;
    return GestureDetector(
      key: key,
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
      child: child,
    );
  }

  Widget _trackRow(
    TimelineLane lane,
    int index,
    TimelineLayout layout,
    Widget Function(Widget bar) bar,
  ) {
    final track = lane.playback.track;
    final label = track.debugLabel ?? guessTrackName(lane.playback, index);
    final value = lane.playback.isWaitingForSync
        ? 'waiting'
        : formatValue(widget.controller.value<Object>(track));
    final laneBar = _LaneBar(segments: lane.segments, layout: layout);
    final editor = widget.trackEditor;
    if (editor == null) {
      return _LaneRow(label: label, value: value, bar: bar(laneBar));
    }
    final editing = identical(_openTrack, track);
    return Padding(
      key: ObjectKey(track),
      padding: const EdgeInsets.only(top: 10),
      child: EditableTrack(
        name: label,
        tuned: widget.trackMotion?.call(track),
        value: value,
        editing: editing,
        dimmed: _openTrack != null && !editing,
        onEdit: () => setState(() => _openTrack = track),
        onDone: () => setState(() => _openTrack = null),
        onReset: widget.onResetTrack == null
            ? null
            : () => widget.onResetTrack!(track),
        body: bar(laneBar),
        editor: editor(track),
      ),
    );
  }

  Widget _laneFor(MotorTimelineLane lane, TimelineLayout layout) {
    final members = [
      for (final playback in layout.lanes)
        if (lane.tracks.contains(playback.playback.track)) playback,
    ];
    final waiting = members.any((member) => member.playback.isWaitingForSync);
    return _LaneRow(
      label: lane.label,
      value: waiting
          ? 'waiting'
          : lane.tracks.length == 1
          ? formatValue(widget.controller.value<Object>(lane.tracks.single))
          : null,
      bar: _LaneBar(
        segments: members.length == 1
            ? members.single.segments
            : summarySegments(members),
        layout: layout,
        color: lane.color,
      ),
    );
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
            final width = constraints.maxWidth;
            Widget lanesWith(Widget Function(Widget bar) bar) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.lanes case final lanes?)
                  for (final lane in lanes) _laneFor(lane, layout)
                else
                  for (final (index, lane) in layout.lanes.indexed)
                    _trackRow(lane, index, layout, bar),
              ],
            );
            final lanes = lanesWith((bar) => bar);
            if (!widget.collapsible) {
              return _scrubArea(
                window,
                width,
                key: const ValueKey('motor-devtools-timeline'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Ruler(layout: layout, scrubbing: _frozen != null),
                    lanes,
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: 'Timeline',
                  hint: widget.interactive ? 'Drag to scrub' : null,
                  value: formatDuration(layout.position - window.start),
                  child: _scrubArea(
                    window,
                    width,
                    key: const ValueKey('motor-devtools-timeline'),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Ruler(layout: layout, scrubbing: _frozen != null),
                        if (layout.lanes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Nothing has played yet',
                              textAlign: TextAlign.center,
                              style: palette.caption,
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              height: 8,
                              child: CustomPaint(
                                painter: _LanePainter(
                                  segments: summarySegments(layout.lanes),
                                  window: window,
                                  position: layout.position,
                                  palette: palette,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (layout.lanes.isNotEmpty) ...[
                  DisclosureRow(
                    key: const ValueKey('motor-devtools-tracks'),
                    open: _showTracks,
                    onTap: () => setState(() => _showTracks = !_showTracks),
                    title: layout.lanes.length == 1
                        ? '1 track'
                        : '${layout.lanes.length} tracks',
                  ),
                  Disclosure(
                    open: _showTracks,
                    child: lanesWith(
                      (bar) => _scrubArea(window, width, bar),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// One lane of a [MotorTimeline]: one or more tracks drawn together.
@immutable
class MotorTimelineLane {
  /// Draws [tracks] in one lane named [label].
  const MotorTimelineLane(this.label, this.tracks, {this.color});

  /// The lane's name.
  final String label;

  /// The tracks drawn in this lane. Several tracks are merged.
  final List<Track<Object>> tracks;

  /// The color of the lane's bars, or null for the text color.
  final Color? color;
}

/// A read-only, live timeline of [controller]'s tracks: one lane per track
/// with its steps, sync waits, and a playhead.
///
/// It takes its font and color from the ambient [DefaultTextStyle]. While
/// shown, it attaches motor's inspection registry, which turns on inspection
/// bookkeeping for every controller in the app: plan history, up to about a
/// thousand retained steps for loops that can't repeat exactly, and
/// look-ahead duration estimates. Treat it as a demo or tooling widget, not
/// a regular production one. With [kMotorDevTools] false it does not attach,
/// so it shows only the steps resolved so far.
///
/// ```dart
/// MotorTimeline(
///   controller: controller,
///   lanes: [
///     MotorTimelineLane('Card', [cardOffset], color: Colors.orange),
///     MotorTimelineLane('Dots', [dotA, dotB]),
///   ],
/// )
/// ```
class MotorTimeline extends StatefulWidget {
  /// Creates a read-only timeline of [controller].
  const MotorTimeline({
    required this.controller,
    this.lanes,
    this.playheadColor,
    super.key,
  });

  /// The controller to show.
  final TrackController controller;

  /// The lanes to show, in order, or null for one lane per track.
  final List<MotorTimelineLane>? lanes;

  /// The playhead's color.
  final Color? playheadColor;

  @override
  State<MotorTimeline> createState() => _MotorTimelineState();
}

class _MotorTimelineState extends State<MotorTimeline> {
  MotorInspectionSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    if (kMotorDevTools) {
      _subscription = MotorInspectionRegistry.attach(_QuietObserver());
    }
  }

  @override
  void dispose() {
    _subscription?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness =
        MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    final base = DevToolsPalette.of(brightness);
    final text = DefaultTextStyle.of(context).style.color ?? base.text;
    return DevToolsTheme(
      palette: base.withText(text, accent: widget.playheadColor),
      child: Timeline(
        controller: widget.controller,
        interactive: false,
        collapsible: false,
        lanes: widget.lanes,
      ),
    );
  }
}

class _QuietObserver implements MotorInspectionObserver {
  @override
  void didRegisterController(TrackController controller) {}

  @override
  void didUnregisterController(TrackController controller) {}
}

/// All of a controller's tracks merged into one lane.
class SummaryLane extends StatelessWidget {
  /// Creates a summary lane for [snapshot].
  const SummaryLane({required this.snapshot, super.key});

  /// The controller's playback.
  final PlaybackSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final layout = layoutTimeline(snapshot);
    return CustomPaint(
      painter: _LanePainter(
        segments: summarySegments(layout.lanes),
        window: layout.window,
        position: layout.position,
        palette: DevToolsTheme.of(context),
      ),
    );
  }
}

/// The motion and hold spans of all [lanes] merged into one summary lane.
List<TimelineSegment> summarySegments(List<TimelineLane> lanes) {
  List<TimelineSegment> merge(SegmentKind kind, bool Function(SegmentKind) of) {
    final spans = [
      for (final lane in lanes)
        for (final segment in lane.segments)
          if (of(segment.kind)) segment,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <TimelineSegment>[];
    for (final span in spans) {
      final last = merged.lastOrNull;
      final lastEnd = last?.end;
      if (last != null && (lastEnd == null || span.start <= lastEnd)) {
        final end = span.end;
        merged[merged.length - 1] = TimelineSegment(
          kind,
          last.start,
          lastEnd == null || end == null ? null : _max(lastEnd, end),
        );
      } else {
        merged.add(TimelineSegment(kind, span.start, span.end));
      }
    }
    return merged;
  }

  return [
    ...merge(SegmentKind.hold, (kind) => kind != SegmentKind.motion),
    ...merge(SegmentKind.motion, (kind) => kind == SegmentKind.motion),
  ];
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
          Text.rich(
            TextSpan(
              text: formatDuration(
                elapsed < Duration.zero
                    ? Duration.zero
                    : elapsed > window.length
                    ? window.length
                    : elapsed,
              ),
              style: palette.numeric.copyWith(color: palette.text),
              children: [
                TextSpan(
                  text: '  /  ${formatDuration(window.length)}',
                  style: palette.numeric.copyWith(color: palette.tertiary),
                ),
              ],
            ),
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

class _LaneBar extends StatelessWidget {
  const _LaneBar({required this.segments, required this.layout, this.color});

  final List<TimelineSegment> segments;
  final TimelineLayout layout;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 8,
    child: CustomPaint(
      painter: _LanePainter(
        segments: segments,
        window: layout.window,
        position: layout.position,
        palette: DevToolsTheme.of(context),
        color: color,
      ),
    ),
  );
}

class _LaneRow extends StatelessWidget {
  const _LaneRow({required this.label, required this.bar, this.value});

  final String label;
  final String? value;
  final Widget bar;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
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
                  style: palette.caption.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              if (value case final value? when value.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: palette.numeric,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          bar,
        ],
      ),
    );
  }
}

class _LanePainter extends CustomPainter {
  const _LanePainter({
    required this.segments,
    required this.window,
    required this.position,
    required this.palette,
    this.color,
  });

  final List<TimelineSegment> segments;
  final Color? color;
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
    for (final segment in segments) {
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
        Radius.zero,
      );
      final base = color ?? palette.text;
      final future = base.withValues(
        alpha: segment.kind == SegmentKind.hold ? 0.16 : 0.13,
      );
      final past = base.withValues(
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
    if (segments.isNotEmpty) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          playheadX.clamp(1, size.width - 1) - 0.75,
          -3,
          playheadX.clamp(1, size.width - 1) + 0.75,
          size.height + 3,
          Radius.zero,
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
          Radius.zero,
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
