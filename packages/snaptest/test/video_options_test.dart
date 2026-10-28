import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:snaptest/snaptest.dart';

void main() {
  testWidgets('stopping without any scene reports no frames', (tester) async {
    final recording = await snap.recordVideo(name: 'no_scene');
    await expectLater(
      recording.stop(),
      throwsA(
        isA<SnapVideoException>().having(
          (e) => e.toString(),
          'diagnostic',
          contains('captured no frames'),
        ),
      ),
    );
  });

  testWidgets('negative pointer duration is rejected before recording', (
    tester,
  ) async {
    await expectLater(
      snap.recordVideo(
        settings: const SnapVideoSettings(
          minimumPointerDuration: Duration(microseconds: -1),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      (tester.binding as SnaptestWidgetsFlutterBinding).activeRecording,
      isNull,
    );
  });

  testWidgets('real shadows repaint an existing scene and restore binding', (
    tester,
  ) async {
    _smallView(tester);
    await tester.pumpWidget(const _ShadowScene());
    final binding = tester.binding as SnaptestWidgetsFlutterBinding;
    expect(binding.disableShadows, isTrue);
    final flat = await snap.recordVideo(name: 'shadows_flat');
    final flatPixels = await _decode(tester, await flat.stop());
    final before = binding.clock.now();
    final real = await snap.recordVideo(
      name: 'shadows_real',
      settings: const SnapVideoSettings(renderShadows: true),
    );
    expect(binding.clock.now(), before);
    expect(binding.disableShadows, isFalse);
    expect(debugDisableShadows, isFalse);
    final realPixels = await _decode(tester, await real.stop());
    expect(realPixels, isNot(orderedEquals(flatPixels)));
    // This point is beyond the unblurred shadow's bounds.
    final red = realPixels[(56 * 96 + 76) * 4];
    expect(red, inExclusiveRange(0, 255));
    expect(binding.disableShadows, isTrue);
    expect(debugDisableShadows, isTrue);
    expect(real.capturedFrameCount, 1);
    final again = await snap.recordVideo(name: 'shadows_restored');
    await tester.pumpWidget(const _ShadowScene());
    expect(
      await _decode(tester, await again.stop()),
      orderedEquals(flatPixels),
    );
  });

  testWidgets('shadow policy restores on truncation', (tester) async {
    _smallView(tester);
    final recording = await snap.recordVideo(
      name: 'shadows_truncated',
      settings: const SnapVideoSettings(
        renderShadows: true,
        maxCapturedFrames: 1,
      ),
    );
    await tester.pumpWidget(const _ShadowScene());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const ColoredBox(color: Colors.blue));
    expect(recording.wasTruncated, isTrue);
    expect(debugDisableShadows, isTrue);
    await recording.stop();
  });

  testWidgets('shadow policy restores on a capture failure', (tester) async {
    _smallView(tester);
    await tester.pumpWidget(const _ShadowScene());
    final recording = await snap.recordVideo(
      name: 'shadows_failed',
      from: find.byWidgetPredicate((w) => w is SizedBox || w is DecoratedBox),
      settings: const SnapVideoSettings(
        renderShadows: true,
        onFailure: VideoFailurePolicy.warn,
      ),
    );
    expect(recording.isCapturing, isFalse);
    expect(debugDisableShadows, isTrue);
    await recording.stop();
  });

  testWidgets('shadow policy restores at automatic teardown', (tester) async {
    _smallView(tester);
    await snap.recordVideo(
      name: 'shadows_automatic',
      settings: const SnapVideoSettings(renderShadows: true),
    );
    await tester.pumpWidget(const _ShadowScene());
  });

  testWidgets('no recording leaves the normal binding shadow policy', (
    tester,
  ) async {
    expect(debugDisableShadows, isTrue);
    expect(
      (tester.binding as SnaptestWidgetsFlutterBinding).disableShadows,
      isTrue,
    );
  });

  for (final smooth in [false, true]) {
    testWidgets('quick tap duration, static gaps, and scene timing: $smooth', (
      tester,
    ) async {
      _smallView(tester);
      var color = Colors.white;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ColoredBox(color: color);
          },
        ),
      );
      final recording = await snap.recordVideo(
        name: 'quick_tap_$smooth',
        settings: SnapVideoSettings(
          frameRate: 20,
          encoding: const VideoEncoding.h264(crf: 0),
          timing: smooth ? VideoTiming.smooth : VideoTiming.observed,
          showPointers: true,
          minimumPointerDuration: const Duration(milliseconds: 100),
          pointerIndicator: _redPointer,
        ),
      );
      final before = tester.binding.clock.now();
      await tester.tapAt(const Offset(48, 48));
      update(() => color = Colors.blue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.binding.clock.now().difference(before),
        const Duration(milliseconds: 200),
      );
      final pixels = await _decode(tester, await recording.stop());
      expect(pixels.length ~/ (96 * 96 * 4), 5);
      expect(_rgb(pixels, 0, 48, 48), [255, 0, 0]);
      expect(_rgb(pixels, 1, 48, 48), [255, 0, 0]);
      expect(_rgb(pixels, 2, 48, 48), isNot([255, 0, 0]));
      // The newly-painted blue scene must not leak back into old timestamps.
      expect(_rgb(pixels, 0, 0, 0), [255, 255, 255]);
      expect(_rgb(pixels, 4, 0, 0)[2], greaterThan(200));
    });
  }

  testWidgets('a quick tap uses finalHold but does not extend the timeline', (
    tester,
  ) async {
    _smallView(tester);
    await tester.pumpWidget(const ColoredBox(color: Colors.white));
    final recording = await snap.recordVideo(
      name: 'quick_tap_final_hold',
      settings: const SnapVideoSettings(
        frameRate: 20,
        encoding: VideoEncoding.h264(crf: 0),
        finalHold: Duration(milliseconds: 300),
        minimumPointerDuration: Duration(milliseconds: 100),
        pointerIndicator: _redPointer,
      ),
    );
    final before = tester.binding.clock.now();
    await tester.tapAt(const Offset(48, 48));
    final pixels = await _decode(tester, await recording.stop());
    expect(tester.binding.clock.now(), before);
    expect(pixels.length ~/ (96 * 96 * 4), 6);
    expect(_rgb(pixels, 0, 48, 48), [255, 0, 0]);
    expect(_rgb(pixels, 1, 48, 48), [255, 0, 0]);
    expect(_rgb(pixels, 2, 48, 48), [255, 255, 255]);
    expect(_rgb(pixels, 5, 48, 48), [255, 255, 255]);
  });

  for (final minimum in [Duration.zero, const Duration(milliseconds: 100)]) {
    testWidgets('instant stop never adds time: $minimum', (tester) async {
      _smallView(tester);
      await tester.pumpWidget(const ColoredBox(color: Colors.white));
      final recording = await snap.recordVideo(
        name: 'instant_${minimum.inMilliseconds}',
        settings: SnapVideoSettings(
          frameRate: 20,
          encoding: const VideoEncoding.h264(crf: 0),
          minimumPointerDuration: minimum,
          pointerIndicator: _redPointer,
        ),
      );
      await tester.tapAt(const Offset(48, 48));
      final pixels = await _decode(tester, await recording.stop());
      expect(pixels.length, 96 * 96 * 4);
      expect(
        _rgb(pixels, 0, 48, 48),
        minimum == Duration.zero ? [255, 255, 255] : [255, 0, 0],
      );
    });
  }

  for (final prefix in [
    '',
    '../exports',
    'absolute',
    'exports with # spaces',
  ]) {
    testWidgets('both output APIs respect the directory prefix: $prefix', (
      tester,
    ) async {
      _smallView(tester);
      final directory = Directory.systemTemp.createTempSync('snaptest_paths_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final previous = goldenFileComparator;
      final scriptDir = Directory(path.join(directory.path, '.snaptest'))
        ..createSync();
      goldenFileComparator = LocalFileComparator(
        Uri.file(path.join(scriptDir.path, 'demo_test.dart')),
      );
      addTearDown(() => goldenFileComparator = previous);
      final actualPrefix = prefix == 'absolute'
          ? path.join(directory.path, 'absolute')
          : prefix;
      final expectedDir = path.normalize(
        path.isAbsolute(actualPrefix)
            ? actualPrefix
            : path.join(scriptDir.path, actualPrefix),
      );
      await tester.pumpWidget(const ColoredBox(color: Colors.green));
      final shots = await snap(
        name: 'output_paths',
        settings: SnaptestSettings(pathPrefix: actualPrefix),
      );
      final recording = await snap.recordVideo(
        name: 'output_paths',
        settings: SnapVideoSettings(pathPrefix: actualPrefix),
      );
      final video = await recording.stop();
      for (final file in [...shots, video]) {
        expect(path.dirname(file.path), expectedDir);
        expect(file.existsSync(), isTrue);
      }
      expect(
        Directory(path.join(scriptDir.path, '.snaptest')).existsSync(),
        isFalse,
      );
    });
  }
}

void _smallView(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(96, 96)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _redPointer(Canvas canvas, Offset center, double scale) {
  canvas.drawCircle(
    center,
    6 * scale,
    Paint()..color = const Color(0xFFFF0000),
  );
}

List<int> _rgb(Uint8List pixels, int frame, int x, int y) {
  final offset = ((frame * 96 * 96) + y * 96 + x) * 4;
  // H.264's RGB/YUV conversion can shift even solid primaries slightly.
  return pixels
      .sublist(offset, offset + 3)
      .map(
        (v) => v < 5
            ? 0
            : v > 250
            ? 255
            : v,
      )
      .toList();
}

Future<Uint8List> _decode(WidgetTester tester, File file) async =>
    (await tester.runAsync(() async {
      final result = await Process.run('ffmpeg', [
        '-v',
        'error',
        '-i',
        file.path,
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgba',
        '-',
      ], stdoutEncoding: null);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return result.stdout as Uint8List;
    }))!;

class _ShadowScene extends StatelessWidget {
  const _ShadowScene();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.white,
    child: Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.red,
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: Offset(8, 8),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
