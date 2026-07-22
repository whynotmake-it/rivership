import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_example/main.dart' as example;
import 'package:motor_example/pages/boarding_pass.dart';
import 'package:motor_example/pages/card_stack.dart';
import 'package:motor_example/pages/curve_trap_escape.dart';
import 'package:motor_example/pages/draggable_icons.dart';
import 'package:motor_example/pages/instant_vs_animated.dart';
import 'package:motor_example/pages/meet_tracks.dart';
import 'package:motor_example/pages/payment_success.dart';
import 'package:motor_example/pages/phases.dart';
import 'package:motor_example/pages/photo_flick.dart';
import 'package:motor_example/pages/picture_in_picture.dart';
import 'package:motor_example/pages/pull_to_refresh.dart';
import 'package:motor_example/pages/snap_carousel.dart';
import 'package:motor_example/pages/spring_character.dart';
import 'package:motor_example/pages/sync_barriers.dart';
import 'package:motor_example/pages/timelines_and_steps.dart';
import 'package:motor_example/pages/toast.dart';
import 'package:motor_example/pages/toggle.dart';

// Pump enough frames to drain one-shot timers so the test's no-pending-timer
// invariant holds.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 60}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
}

void main() {
  final pages = <String, Widget Function()>{
    'Instant vs. Animated': () => const InstantVsAnimatedPage(),
    'The Curve Trap': () => const CurveTrapEscapePage(),
    'Spring Character': () => const SpringCharacterPage(),
    'More Than One Dimension': () => const PhotoFlickPage(),
    'Toggle': () => const TogglePage(),
    'Snap Carousel': () => const SnapCarouselPage(),
    'Toast': () => const ToastPage(),
    'Meet Tracks': () => const MeetTracksPage(),
    'Payment Success': () => const PaymentSuccessPage(),
    'Timelines & Steps': () => const TimelinesAndStepsPage(),
    'Sync Barriers': () => const SyncBarriersPage(),
    'Phases': () => const PhasesPage(),
    'Card Stack': () => const CardStackPage(),
    'Picture in Picture': () => const PictureInPicturePage(),
    'Pull to Refresh': () => const PullToRefreshPage(),
    'Draggable Icons': () => const DraggableIconsPage(),
    'Boarding Pass': () => const BoardingPassPage(),
  };
  test('smoke map covers every page route', () {
    expect(pages.length, example.motorRoutes.length - 1);
  });

  for (final entry in pages.entries) {
    testWidgets('${entry.key} builds and runs without exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(CupertinoApp(home: entry.value()));
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Payment Success plays the full sync-barrier timeline', (
    tester,
  ) async {
    await tester.pumpWidget(const CupertinoApp(home: PaymentSuccessPage()));
    await tester.pump();

    // Press and hold the pay button long enough to commit (hold timer is
    // 420ms), then let the orchestration run through the sync barrier.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Pay  \$42.00')),
    );
    await tester.pump(const Duration(milliseconds: 700)); // commit fires
    await gesture.up();
    // Run the timeline: morph + processing dwell + post-barrier check/receipt.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Payment sent'), findsOneWidget);
  });

  testWidgets('Curve Trap handles a mid-flight reversal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const CupertinoApp(home: CurveTrapEscapePage()));
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Close'));
    await _pumpFrames(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Photo flick returns a low-velocity fling home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const CupertinoApp(home: PhotoFlickPage()));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('photo-0')));
    await tester.pump();
    expect(
      (tester.getCenter(find.byKey(const ValueKey('opened-photo'))) -
              tester.getCenter(find.byKey(const ValueKey('photo-stage'))))
          .distance,
      lessThan(1),
    );
    await tester.fling(
      find.byKey(const ValueKey('opened-photo')),
      const Offset(36, 24),
      10,
    );
    await _pumpFrames(tester, frames: 100);

    final photoCenter = tester.getCenter(
      find.byKey(const ValueKey('opened-photo')),
    );
    final stageCenter = tester.getCenter(
      find.byKey(const ValueKey('photo-stage')),
    );
    expect((photoCenter - stageCenter).distance, lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Timelines & Steps loops and switches to pingPong', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(home: TimelinesAndStepsPage()),
    );
    await _pumpFrames(tester, frames: 240);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('pingPong'));
    await _pumpFrames(tester, frames: 120);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sync Barriers holds the runner until the walker arrives', (
    tester,
  ) async {
    await tester.pumpWidget(const CupertinoApp(home: SyncBarriersPage()));
    await tester.pump(const Duration(milliseconds: 500));

    double read(String key) {
      final widget = tester.widget<Text>(find.byKey(ValueKey(key)));
      return double.parse(widget.data!);
    }

    expect(read('runner-value'), closeTo(1, 0.01));
    expect(read('walker-value'), lessThan(1));
    expect(read('runner-value'), lessThan(1.02));

    await _pumpFrames(tester, frames: 60);
    expect(read('runner-value'), greaterThan(1.2));
    expect(read('walker-value'), greaterThan(1.2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phases settles manually and auto-plays several cycles', (
    tester,
  ) async {
    await tester.pumpWidget(const CupertinoApp(home: PhasesPage()));
    await tester.tap(find.byKey(const ValueKey('phase-card')));
    await _pumpFrames(tester, frames: 80);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('phase-status'))).data,
      contains('PhaseSettled'),
    );

    await tester.tap(find.byKey(const ValueKey('auto-play')));
    await _pumpFrames(tester, frames: 180);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Boarding Pass interrupts mid-entrance and re-books', (
    tester,
  ) async {
    await tester.pumpWidget(const CupertinoApp(home: BoardingPassPage()));
    await tester.pump();

    // Thirty display frames leaves the causal content timeline in flight.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    const ticketKey = ValueKey('boarding-pass-ticket');
    await tester.fling(find.byKey(ticketKey), const Offset(420, 0), 1800);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final viewportWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(
      tester.getCenter(find.byKey(ticketKey)).dx,
      greaterThan(viewportWidth),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Re-book'));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final gate = tester.widget<Transform>(
      find.byKey(const ValueKey('boarding-pass-gate')),
    );
    expect(gate.transform.getMaxScaleOnAxis(), greaterThan(.9));
    expect(tester.takeException(), isNull);
  });
}
