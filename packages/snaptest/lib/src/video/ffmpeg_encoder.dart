/// FFmpeg discovery, validation, and streaming raw-video encoding for
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

final Map<String?, String> _resolvedFfmpegPaths = {};
final Map<String, Set<String>> _availableEncoders = {};

/// Locates the FFmpeg executable and verifies the [encoding]'s encoder is
/// available in that build.
///
/// Results are cached per requested override: `ffmpeg -encoders` is only
/// listed once per executable.
@internal
Future<String> resolveFfmpeg({
  required String? executablePath,
  required VideoEncoding encoding,
}) async {
  final executable = _resolvedFfmpegPaths[executablePath] ??=
      await _findExecutable(executablePath);
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

/// A bounded raw RGBA pipe to FFmpeg. Calls must be serialized by the caller.
///
/// The pipe is drained after each frame, so a slow encoder applies
/// backpressure instead of buffering an entire recording in memory.
@internal
class RawVideoEncoder {
  RawVideoEncoder._(this._process, this._timeout) {
    _stderrDone = _process.stderr.transform(utf8.decoder).forEach((chunk) {
      _diagnostics.write(chunk);
      const maxDiagnostics = 16 * 1024;
      if (_diagnostics.length > maxDiagnostics) {
        final tail = _diagnostics.toString();
        _diagnostics
          ..clear()
          ..write(tail.substring(tail.length - maxDiagnostics));
      }
    });
    _stdoutDone = _process.stdout.drain<void>();
    // IOSink.done can fail before the next write observes a broken pipe.
    _process.stdin.done.then<void>(
      (_) {},
      onError: (Object error) {
        _writeError ??= error;
      },
    );
  }

  /// Starts encoding straight-alpha RGBA at the declared dimensions and FPS.
  static Future<RawVideoEncoder> start({
    required String executable,
    required VideoEncoding encoding,
    required int frameRate,
    required int width,
    required int height,
    required File outputFile,
    required Duration timeout,
  }) async {
    final process = await Process.start(executable, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-f',
      'rawvideo',
      '-pixel_format',
      'rgba',
      '-video_size',
      '${width}x$height',
      '-framerate',
      '$frameRate',
      '-i',
      'pipe:0',
      ...encoding.ffmpegCodecArguments,
      outputFile.path,
    ]);
    return RawVideoEncoder._(process, timeout);
  }

  final Process _process;
  final Duration _timeout;
  final StringBuffer _diagnostics = StringBuffer();
  late final Future<void> _stderrDone;
  late final Future<void> _stdoutDone;
  Object? _writeError;
  Future<void>? _abortFuture;

  /// The bounded tail of FFmpeg's stderr, including failures during capture.
  String get diagnostics => _diagnostics.toString();

  /// Writes [count] copies of an immutable frame, without dropping samples.
  Future<void> writeFrames(List<int> rgba, int count) async {
    try {
      await (() async {
        for (var i = 0; i < count; i++) {
          _process.stdin.add(rgba);
          await _process.stdin.flush();
        }
      })().timeout(_timeout);
    } on Object catch (error) {
      _writeError ??= error;
      _process.kill();
      throw SnapVideoException('Failed streaming frames to FFmpeg: $error');
    }
  }

  /// Closes the stream and waits for the encoder to finish its output.
  Future<void> finish() async {
    try {
      await _process.stdin.close().timeout(_timeout);
    } on Object catch (error) {
      _writeError ??= error;
      _process.kill();
    }
    final int exitCode;
    try {
      exitCode = await _process.exitCode.timeout(_timeout);
    } on TimeoutException {
      await abort();
      throw SnapVideoException(
        'FFmpeg did not finish within ${_timeout.inSeconds}s and was killed.\n'
        'Diagnostics:\n$_diagnostics',
      );
    }
    await Future.wait([_stderrDone, _stdoutDone]);
    if (exitCode != 0 || _writeError != null) {
      throw SnapVideoException(
        'FFmpeg exited with code $exitCode. '
        '${_writeError == null ? '' : 'Stream error: $_writeError'}\n'
        'Diagnostics:\n$_diagnostics',
      );
    }
  }

  /// Releases the child process when recording cannot be finalized.
  Future<void> abort() => _abortFuture ??= _abort();

  Future<void> _abort() async {
    _process.kill();
    try {
      await _process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _process.kill(ProcessSignal.sigkill);
      await _process.exitCode;
    }
    try {
      await _process.stdin.close();
    } on Object {
      // A timed-out flush may still own the sink until its error is delivered.
    }
    await Future.wait([_stderrDone, _stdoutDone]);
  }
}
