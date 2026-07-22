import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/timeline_lanes.dart';

Track<double> _track() => Track(const SingleMotionConverter(), initial: 0);

const _linear100 = LinearMotion(Duration(milliseconds: 100));

void main() {
  group('layoutTimeline', () {
    test('uses the latest lane end as the total span', () {
      final short = _track();
      final long = _track();
      final layout = layoutTimeline(
        TrackTimeline([
          short.to(1, motion: _linear100),
          long.to(1, motion: const LinearMotion(Duration(milliseconds: 300))),
        ]),
        pixelsPerMillisecond: 1,
      );

      expect(layout.totalDuration, const Duration(milliseconds: 300));
      expect(layout.lanes[0].end, const Duration(milliseconds: 100));
      expect(layout.lanes[1].end, const Duration(milliseconds: 300));
    });

    test('resolves a hold as a baseline gap', () {
      final track = _track();
      final layout = layoutTimeline(
        TrackTimeline([
          track([
            const TrackStep.hold(Duration(milliseconds: 120)),
            const TrackStep.to(1, motion: _linear100),
          ]),
        ]),
        pixelsPerMillisecond: 2,
      );

      final gap = layout.lanes.single.segments.first;
      expect(gap.kind, TimelineSegmentKind.gap);
      expect(gap.start, Duration.zero);
      expect(gap.end, const Duration(milliseconds: 120));
      expect(gap.startX, 0);
      expect(gap.endX, 240);
    });

    test('aligns unequal arrivals at a shared sync barrier', () {
      final early = _track();
      final late = _track();
      final layout = layoutTimeline(
        TrackTimeline([
          early([
            const TrackStep.to(1, motion: _linear100),
            const TrackStep.sync(token: #ready),
            const TrackStep.to(
              2,
              motion: LinearMotion(Duration(milliseconds: 50)),
            ),
          ]),
          late([
            const TrackStep.hold(Duration(milliseconds: 250)),
            const TrackStep.sync(token: #ready),
            const TrackStep.to(
              2,
              motion: LinearMotion(Duration(milliseconds: 70)),
            ),
          ]),
        ]),
        pixelsPerMillisecond: 1,
      );

      for (final lane in layout.lanes) {
        final barrier = lane.segments.firstWhere(
          (segment) => segment.kind == TimelineSegmentKind.barrier,
        );
        expect(barrier.start, const Duration(milliseconds: 250));
        final afterBarrier = lane.segments[lane.segments.indexOf(barrier) + 1];
        expect(afterBarrier.start, const Duration(milliseconds: 250));
      }
      expect(layout.totalDuration, const Duration(milliseconds: 320));
    });

    test('marks a spring target as feathered', () {
      final track = _track();
      final layout = layoutTimeline(
        TrackTimeline([
          track.to(
            1,
            motion: const CupertinoMotion(
              duration: Duration(milliseconds: 400),
            ),
          ),
        ]),
        pixelsPerMillisecond: 1,
      );

      expect(
        layout.lanes.single.segments.single.kind,
        TimelineSegmentKind.feathered,
      );
    });

    test('keeps a curved target sharp-edged', () {
      final track = _track();
      final layout = layoutTimeline(
        TrackTimeline([
          track.to(
            1,
            motion: const CurvedMotion(
              Duration(milliseconds: 180),
              Curves.easeInOut,
            ),
          ),
        ]),
        pixelsPerMillisecond: 1,
      );

      expect(
        layout.lanes.single.segments.single.kind,
        TimelineSegmentKind.block,
      );
    });

    test('gives a free motion the placeholder treatment', () {
      final track = _track();
      final layout = layoutTimeline(
        TrackTimeline([track.free(const FrictionMotion())]),
        pixelsPerMillisecond: 1,
      );

      final segment = layout.lanes.single.segments.single;
      expect(segment.kind, TimelineSegmentKind.free);
      expect(segment.end, const Duration(milliseconds: 500));
      expect(layout.totalDuration, const Duration(milliseconds: 500));
    });

    test('treats TrackStep.at as absolute from the lane start', () {
      final track = _track();
      final layout = layoutTimeline(
        TrackTimeline([
          track([
            const TrackStep.hold(Duration(milliseconds: 80)),
            const TrackStep.at(
              Duration(milliseconds: 300),
              1,
              motion: _linear100,
            ),
          ]),
        ]),
        pixelsPerMillisecond: 1,
      );

      final scheduled = layout.lanes.single.segments.last;
      expect(scheduled.start, const Duration(milliseconds: 80));
      expect(scheduled.end, const Duration(milliseconds: 300));
      expect(layout.totalDuration, const Duration(milliseconds: 300));
    });
  });

  testWidgets('renders three lanes and follows the external playhead', (
    tester,
  ) async {
    final first = _track();
    final second = _track();
    final third = _track();
    final playhead = ValueNotifier(Duration.zero);
    addTearDown(playhead.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 600,
            child: TimelineLanes(
              timeline: TrackTimeline([
                first.to(1, motion: _linear100),
                second([
                  const TrackStep.hold(Duration(milliseconds: 40)),
                  const TrackStep.to(1, motion: _linear100),
                ]),
                third.free(const FrictionMotion()),
              ]),
              playhead: playhead,
              laneLabels: {
                first: 'position',
                second: 'opacity',
                third: 'velocity',
              },
            ),
          ),
        ),
      ),
    );
    playhead.value = const Duration(milliseconds: 75);
    await tester.pump();

    expect(find.byType(TimelineLanes), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
