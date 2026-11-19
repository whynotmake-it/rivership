import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:snaptest/src/video/ffmpeg_encoder.dart';

void main() {
  test(
    'raw encoding repeats every frame without changing codec quality',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'raw_video_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/video.mp4');
      final encoder = await RawVideoEncoder.start(
        executable: 'ffmpeg',
        encoding: const VideoEncoding.h264(),
        frameRate: 30,
        width: 32,
        height: 24,
        outputFile: file,
        timeout: const Duration(seconds: 10),
      );
      addTearDown(encoder.abort);
      final frame = Uint8List(32 * 24 * 4);
      for (var i = 0; i < frame.length; i += 4) {
        frame[i] = 255;
        frame[i + 3] = 255;
      }
      await encoder.writeFrames(frame, 17);
      await encoder.finish();
      final decoded = await Process.run('ffmpeg', [
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
      expect(decoded.exitCode, 0);
      expect((decoded.stdout as List<int>).length, 17 * frame.length);
    },
  );

  for (final stage in ['write', 'finish']) {
    test(
      'times out and releases a stalled encoder during $stage',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'raw_video_hang_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final executable = File('${directory.path}/stalled-encoder');
        await executable.writeAsString('#!/bin/sh\nwhile :; do :; done\n');
        final chmod = await Process.run('chmod', ['+x', executable.path]);
        expect(chmod.exitCode, 0);
        final encoder = await RawVideoEncoder.start(
          executable: executable.path,
          encoding: const VideoEncoding.h264(),
          frameRate: 30,
          width: 1024,
          height: 1024,
          outputFile: File('${directory.path}/video.mp4'),
          timeout: const Duration(milliseconds: 100),
        );
        addTearDown(encoder.abort);
        final watch = Stopwatch()..start();
        final operation = stage == 'write'
            ? encoder.writeFrames(Uint8List(1024 * 1024 * 4), 2)
            : encoder.finish();
        await expectLater(operation, throwsA(isA<SnapVideoException>()));
        await encoder.abort();
        expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
      },
      skip: Platform.isWindows,
    );
  }
}
