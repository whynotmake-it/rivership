import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  group('recordVideo', () {
    testWidgets('produces an H.264 MP4 in observed mode', (tester) async {
      final recording = await snap.recordVideo(name: 'unit_observed');

      await tester.pumpWidget(const _DemoScene(progress: 0));
      for (var i = 1; i <= 8; i++) {
        await tester.pumpWidget(_DemoScene(progress: i / 8));
        await tester.pump(const Duration(milliseconds: 250));
      }

      final file = await recording.stop();
      expect(file.path, endsWith('.mp4'));
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));

      // MP4 files start with a box length followed by the 'ftyp' magic.
      // Synchronous IO only: futures/streams from dart:io never complete in
      // the test body's FakeAsync zone.
      final handle = file.openSync()..setPositionSync(0);
      final header = handle.readSync(12);
      handle.closeSync();
      expect(
        String.fromCharCodes(header.sublist(4, 8)),
        'ftyp',
      );

      // One state per painted timestamp: pumps that paint nothing and
      // re-paints at the same clock time are coalesced, so the count is
      // one per distinct painted timestamp.
      expect(recording.capturedFrameCount, greaterThanOrEqualTo(8));
      expect(recording.wasTruncated, isFalse);
    });

    testWidgets('smooth timing subdivides pumps at the frame grid', (
      tester,
    ) async {
      final recording = await snap.recordVideo(
        name: 'unit_smooth',
        settings: const SnapVideoSettings(timing: VideoTiming.smooth),
      );

      await tester.pumpWidget(const _AnimatedScene());
      // One coarse pump over the whole 2s animation: smooth timing splits
      // it into ~60 grid-aligned steps, each painting a new state.
      await tester.pump(const Duration(seconds: 2));

      // 2s at 30fps = ~60 interpolated frames plus the initial state.
      expect(recording.capturedFrameCount, greaterThanOrEqualTo(50));

      final file = await recording.stop();
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });

    testWidgets('observed timing captures one state per painted pump', (
      tester,
    ) async {
      final recording = await snap.recordVideo(
        name: 'unit_observed_coarse',
      );

      await tester.pumpWidget(const _AnimatedScene());
      // The same coarse pump: observed mode does not subdivide, so only the
      // initial frame and the end state are captured.
      await tester.pump(const Duration(seconds: 2));

      expect(recording.capturedFrameCount, lessThanOrEqualTo(3));

      await recording.stop();
    });

    testWidgets('rejects overlapping recordings, allows sequential ones', (
      tester,
    ) async {
      final first = await snap.recordVideo(name: 'unit_overlap');
      await tester.pumpWidget(const _DemoScene(progress: 0.5));
      await tester.pump();

      await expectLater(
        snap.recordVideo(name: 'unit_overlap_again'),
        throwsA(isA<SnapVideoException>()),
      );

      await first.stop();

      final second = await snap.recordVideo(name: 'unit_sequential');
      await tester.pump(const Duration(milliseconds: 100));
      final file = await second.stop();
      expect(file.existsSync(), isTrue);
    });

    testWidgets('pumps pass through untouched when not recording', (
      tester,
    ) async {
      final binding = WidgetsBinding.instance;
      expect(binding, isA<SnaptestWidgetsFlutterBinding>());

      await tester.pumpWidget(const _DemoScene(progress: 0.25));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Sanity check: nothing was recorded or written.
      final snaptestDir = Directory('.snaptest');
      final spoolDirs = snaptestDir.existsSync()
          ? snaptestDir
                .listSync()
                .whereType<Directory>()
                .where((d) => d.path.contains('.video_spool_'))
                .toList()
          : const <Directory>[];
      expect(spoolDirs, isEmpty);
    });

    testWidgets('stop() is idempotent and returns the same file', (
      tester,
    ) async {
      final recording = await snap.recordVideo(name: 'unit_idempotent');
      await tester.pumpWidget(const _DemoScene(progress: 0.5));
      await tester.pump();

      final first = await recording.stop();
      final second = await recording.stop();
      expect(identical(first, second) || first.path == second.path, isTrue);
    });

    testWidgets('fails clearly when the finder matches nothing at stop', (
      tester,
    ) async {
      final recording = await snap.recordVideo(
        name: 'unit_empty',
        from: find.byKey(const ValueKey('never-mounted')),
      );
      await tester.pumpWidget(const _DemoScene(progress: 0.5));
      await tester.pump();

      await expectLater(recording.stop(), throwsA(isA<SnapVideoException>()));
    });
  });

  group('demo app recordings', () {
    testWidgets(
      'demo video — real app, device frame, smooth 30fps',
      (tester) async {
        final recording = await snap.recordVideo(
          name: 'demo_app_framed',
          settings: const SnapVideoSettings(
            timing: VideoTiming.smooth,
            includeDeviceFrame: true,
            showPointers: true,
            finalHold: Duration(milliseconds: 400),
          ),
        );

        await tester.pumpWidget(const _DemoFeedApp());
        await tester.pump(const Duration(milliseconds: 800));

        // Open the first card.
        await tester.tap(find.byKey(const ValueKey('feed-card-0')));
        await tester.pump(const Duration(seconds: 1));

        // Back to the feed.
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 800));

        // Scroll the feed with real gestures.
        await tester.fling(find.byType(ListView), const Offset(0, -400), 900);
        await tester.pump(const Duration(milliseconds: 800));
        await tester.fling(find.byType(ListView), const Offset(0, -600), 2000);
        await tester.pump(const Duration(seconds: 1));

        // Scroll back to the top.
        await tester.fling(find.byType(ListView), const Offset(0, 600), 3000);
        await tester.pump(const Duration(seconds: 1));

        // Open the modal sheet and drag it down with a real multi-step
        // gesture (a single moveBy would teleport the sheet in one frame).
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump(const Duration(seconds: 1));
        final sheetDrag = await tester.startGesture(
          tester.getCenter(find.text('Drag me down')),
        );
        for (var i = 0; i < 12; i++) {
          await sheetDrag.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await sheetDrag.up();
        await tester.pump(const Duration(seconds: 1));

        final file = await recording.stop();
        expect(file.existsSync(), isTrue);
        // ignore: avoid_print
        print('Demo video (app, framed): ${file.path}');
      },
      variant: TestDevicesVariant({Devices.ios.iPhone16Pro}),
    );

    testWidgets(
      'demo video — real app, device frame, landscape 24fps observed',
      (tester) async {
        final recording = await snap.recordVideo(
          name: 'demo_app_landscape',
          settings: const SnapVideoSettings(
            frameRate: 24,
            includeDeviceFrame: true,
            showPointers: true,
            encoding: VideoEncoding.h264(crf: 23),
            finalHold: Duration(milliseconds: 400),
          ),
        );

        await tester.pumpWidget(const _DemoFeedApp());
        await tester.pump(const Duration(milliseconds: 800));

        // Open the modal sheet and dismiss it with a barrier tap. (A drag is
        // flaky in landscape: DeviceFrame can lay the sheet out below the
        // test view's bounds.) Pump in ~frame-sized steps so observed timing
        // captures the slide/dismiss animations instead of skipping them.
        await tester.tap(find.byType(FloatingActionButton));
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.tapAt(const Offset(20, 20));
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }

        // Fling the feed horizontally, then watch it settle frame by frame.
        await tester.fling(
          find.byKey(const ValueKey('feed-list')),
          const Offset(-600, 0),
          1200,
        );
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }

        final file = await recording.stop();
        expect(file.existsSync(), isTrue);
        // ignore: avoid_print
        print('Demo video (app, landscape): ${file.path}');
      },
      variant: TestDevicesVariant(
        {Devices.ios.iPhone16Pro},
        orientations: {Orientation.landscape},
      ),
    );
  });

  group('demo recordings', () {
    testWidgets('demo video — observed timing', (tester) async {
      final recording = await snap.recordVideo(
        name: 'demo_observed',
        settings: const SnapVideoSettings(
          finalHold: Duration(milliseconds: 500),
        ),
      );

      for (var i = 0; i <= 30; i++) {
        await tester.pumpWidget(_DemoScene(progress: i / 30));
        await tester.pump(const Duration(milliseconds: 100));
      }

      final file = await recording.stop();
      expect(file.existsSync(), isTrue);
      // ignore: avoid_print
      print('Demo video (observed): ${file.path}');
    });

    testWidgets('demo video — smooth timing', (tester) async {
      final recording = await snap.recordVideo(
        name: 'demo_smooth',
        settings: const SnapVideoSettings(
          timing: VideoTiming.smooth,
          finalHold: Duration(milliseconds: 500),
        ),
      );

      await tester.pumpWidget(const _AnimatedScene());
      await tester.pump(const Duration(seconds: 3));

      final file = await recording.stop();
      expect(file.existsSync(), isTrue);
      // ignore: avoid_print
      print('Demo video (smooth): ${file.path}');
    });
  });
}

/// A deterministic demo scene: a circle travelling across a dark backdrop
/// with a progress bar and a frame counter, driven by [progress].
class _DemoScene extends StatelessWidget {
  const _DemoScene({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF0D1117),
        child: Stack(
        children: [
          Align(
            alignment: Alignment(2 * progress - 1, 0),
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF58A6FF), Color(0xFFBC8CFF)],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF30363D),
                color: const Color(0xFF58A6FF),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.8),
            child: Text(
              'snaptest video — ${(progress * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

/// A ticker-driven scene used for smooth-timing recordings: the animation
/// advances with the test clock, so subdivided pumps capture interpolated
/// states.
class _AnimatedScene extends StatelessWidget {
  const _AnimatedScene();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOutCubic,
      builder: (context, progress, _) => _DemoScene(progress: progress),
    );
  }
}

/// A small realistic app used for the demo recordings: a scrollable card
/// feed with push navigation, a FAB, and a draggable modal sheet, all
/// driven by real gestures in the demo tests.
class _DemoFeedApp extends StatelessWidget {
  const _DemoFeedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const _FeedScreen(),
    );
  }
}

class _FeedScreen extends StatelessWidget {
  const _FeedScreen();

  static const _palette = [
    Color(0xFF6366F1),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF22C55E),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: AppBar(title: const Text('Snaptest Feed')),
      body: ListView.builder(
        key: const ValueKey('feed-list'),
        scrollDirection: isLandscape ? Axis.horizontal : Axis.vertical,
        itemCount: 30,
        itemBuilder: (context, index) => _FeedCard(
          index: index,
          color: _palette[index % _palette.length],
          landscape: isLandscape,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (context) => const _DemoSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.index,
    required this.color,
    required this.landscape,
  });

  final int index;
  final Color color;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: landscape ? 260 : null,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          key: ValueKey('feed-card-$index'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => _DetailScreen(index: index, color: color),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: color,
                child: SizedBox(
                  height: 110,
                  child: Center(
                    child: Icon(
                      Icons.widgets,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              ListTile(
                title: Text('Card $index'),
                subtitle: const Text('Tap me'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailScreen extends StatelessWidget {
  const _DetailScreen({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Card $index')),
      body: Center(
        child: ColoredBox(
          color: color,
          child: const SizedBox(
            width: 180,
            height: 180,
            child: Center(
              child: Icon(Icons.widgets, size: 72, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoSheet extends StatelessWidget {
  const _DemoSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('demo-sheet'),
      height: MediaQuery.sizeOf(context).height * 0.9,
      padding: const EdgeInsets.all(24),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Text(
            'Drag me down',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text('Sheet item $i'),
            ),
        ],
      ),
    );
  }
}
