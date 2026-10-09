/// FFmpeg discovery, validation, and `image2pipe` encoding for
/// [SnapRecording].
///
/// Everything here is package-internal. Snaptest deliberately requires an
/// external FFmpeg executable for video instead of bundling a binary or
/// calling platform video APIs, neither of which works uniformly in headless
/// `flutter test`.
/// @docImport 'package:snaptest/src/video/snap_recording.dart';
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:snaptest/src/video/video_settings.dart';

/// Thrown when FFmpeg cannot be found, lacks the required encoder, or fails
/// to produce output.
class SnapVideoException implements Exception {
  /// Creates a video exception with a [message].
  const SnapVideoException(this.message);

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => 'SnapVideoException: $message';
}

String? _resolvedFfmpegPath;
final Map<String, Set<String>> _availableEncoders = {};

/// Locates the FFmpeg executable and verifies the [encoding]'s encoder is
/// available in that build.
///
/// Results are cached: the executable is only resolved once per test process
/// and `ffmpeg -encoders` is only listed once per executable.
@internal
Future<String> resolveFfmpeg({
  required String? executablePath,
  required VideoEncoding encoding,
}) async {
  final executable = _resolvedFfmpegPath ??= await _findExecutable(
    executablePath,
  );
  final available = _availableEncoders[executable] ??= await _listEncoders(
    executable,
  );
  final encoderName = encoding.ffmpegEncoderName;
  if (!available.contains(encoderName)) {
    throw SnapVideoException(
      'FFmpeg at "$executable" does not provide the "$encoderName" encoder '
      'required by $encoding. Install an FFmpeg build with $encoderName or '
      'choose a different VideoEncoding profile.',
    );
  }
  return executable;
}

Future<String> _findExecutable(String? override) async {
  if (override != null) {
    if (!File(override).existsSync()) {
      throw SnapVideoException(
        'The configured ffmpegPath "$override" does not exist. Point '
        'SnapVideoSettings.ffmpegPath at a valid FFmpeg executable.',
      );
    }
    return override;
  }

  for (final name in ['ffmpeg', 'ffmpeg.exe']) {
    try {
      final result = await Process.run(name, ['-hide_banner', '-version']);
      if (result.exitCode == 0) {
        return name;
      }
    } on ProcessException {
      // Not found on PATH under this name; keep looking.
    }
  }
  throw const SnapVideoException(
    'Could not find an "ffmpeg" executable on PATH. Video recording requires '
    'FFmpeg; install it or set SnapVideoSettings.ffmpegPath.',
  );
}

Future<Set<String>> _listEncoders(String executable) async {
  final ProcessResult result;
  try {
    result = await Process.run(executable, [
      '-hide_banner',
      '-encoders',
    ]);
  } on ProcessException catch (e) {
    throw SnapVideoException(
      'Failed to run "$executable -encoders": ${e.message}',
    );
  }
  if (result.exitCode != 0) {
    throw SnapVideoException(
      '"$executable -encoders" exited with ${result.exitCode}:\n'
      '${result.stderr}',
    );
  }
  // Encoder lines look like: " V..... libx264    libx264 H.264 / AVC ..."
  return {
    for (final line in const LineSplitter().convert(result.stdout as String))
      if (RegExp(r'^\s*[VASD]\.').hasMatch(line)) line.trim().split(' ')[1],
  };
}

/// Encodes [frameFiles] — one file per output frame on the constant frame
/// grid — into [outputFile] via FFmpeg's `image2pipe` demuxer.
///
/// The caller is responsible for resampling the recorded timeline; files may
/// repeat consecutively (a held frame is fed repeatedly). Writes the
/// encoder's stderr diagnostics (bounded) into [diagnostics].
///
/// Throws [SnapVideoException] when the process fails, times out, or leaves
/// no output. [outputFile] is expected to be a temporary path the caller
/// publishes atomically after this returns.
@internal
Future<void> encodeImagePipe({
  required String executable,
  required VideoEncoding encoding,
  required int frameRate,
  required List<File> frameFiles,
  required File outputFile,
  required Duration timeout,
  required StringBuffer diagnostics,
}) async {
  final process = await Process.start(executable, [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-f',
    'image2pipe',
    '-framerate',
    '$frameRate',
    '-i',
    'pipe:0',
    ...encoding.ffmpegCodecArguments,
    outputFile.path,
  ]);

  // Drain stderr continuously into a bounded tail buffer so verbose
  // diagnostics can't exhaust memory.
  const maxDiagnostics = 16 * 1024;
  final stderrDone = process.stderr.transform(utf8.decoder).forEach((chunk) {
    diagnostics.write(chunk);
    if (diagnostics.length > maxDiagnostics) {
      final tail = diagnostics.toString();
      diagnostics
        ..clear()
        ..write(tail.substring(tail.length - maxDiagnostics));
    }
  });

  var killedByTimeout = false;
  final exitFuture = process.exitCode.timeout(
    timeout,
    onTimeout: () {
      killedByTimeout = true;
      process.kill();
      return -1;
    },
  );

  try {
    List<int>? lastBytes;
    File? lastFile;
    for (final frameFile in frameFiles) {
      // Consecutive output frames usually reuse the same source PNG during
      // holds; skip re-reading the file in that case.
      if (frameFile.path != lastFile?.path) {
        lastFile = frameFile;
        lastBytes = await frameFile.readAsBytes();
      }
      process.stdin.add(lastBytes!);
      await process.stdin.flush();
    }
  } finally {
    await process.stdin.close();
  }

  final exitCode = await exitFuture;
  await stderrDone;

  if (killedByTimeout) {
    throw SnapVideoException(
      'FFmpeg did not finish within ${timeout.inSeconds}s and was killed.\n'
      'Diagnostics:\n$diagnostics',
    );
  }
  if (exitCode != 0) {
    throw SnapVideoException(
      'FFmpeg exited with code $exitCode.\nDiagnostics:\n$diagnostics',
    );
  }
  if (!outputFile.existsSync() || outputFile.lengthSync() == 0) {
    throw SnapVideoException(
      'FFmpeg reported success but produced no output at '
      '${outputFile.path}.\nDiagnostics:\n$diagnostics',
    );
  }
}
