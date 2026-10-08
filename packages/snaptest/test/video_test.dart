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
