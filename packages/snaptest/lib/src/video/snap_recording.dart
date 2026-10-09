/// A test-scoped video recording session started by [Snap.recordVideo].
///
/// The session passively observes the frames a widget test paints: it never
/// pumps, loads fonts, precaches images, or repaints layers of its own. Each
/// painted frame is rasterized to a PNG spool with its simulated timestamp;
/// when the recording stops, the spooled timeline is resampled onto the
/// configured constant-frame-rate grid and encoded by FFmpeg.
/// @docImport 'package:snaptest/src/snap.dart';
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:snaptest/src/capture.dart';
import 'package:snaptest/src/test_devices_variant.dart';
import 'package:snaptest/src/util.dart';
import 'package:snaptest/src/video/ffmpeg_encoder.dart';
import 'package:snaptest/src/video/snaptest_binding.dart';
import 'package:snaptest/src/video/video_settings.dart';
// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart';

/// Tracks the number of recordings per test name for file naming.
final Map<String, int> _videoCallCounts = {};

enum _RecordingState { capturing, frozen, finalized }

class _SpooledFrame {
  const _SpooledFrame(this.timeUs, this.index);

  /// Absolute fake-clock timestamp in microseconds.
  final int timeUs;

  /// Sequence number; the PNG is `frames/<index padded to 6>.png`.
  final int index;
}

/// A video recording in progress, created by [Snap.recordVideo].
///
/// ```dart
/// final recording = await snap.recordVideo();
/// await tester.pumpWidget(const MyApp());
/// await tester.pumpAndSettle();
/// final file = await recording.stop();
/// ```
///
/// Recording stops automatically at the end of the test body even if [stop]
/// is never called. See [SnapVideoSettings] for frame rate, timing mode and
/// encoding options.
class SnapRecording {
  SnapRecording._({
    required SnaptestWidgetsFlutterBinding binding,
    required this.settings,
    required this.from,
    required this.crop,
    required String outputPath,
    required Directory spoolDir,
    required String ffmpegExecutable,
  }) : _binding = binding,
       _outputPath = outputPath,
       _spoolDir = spoolDir,
       _ffmpegExecutable = ffmpegExecutable {
    _anchorUs = _clockNowUs;
  }

  /// Starts a new recording for the currently running test.
  ///
  /// Validates the binding, output path, and encoder availability before
  /// returning. Throws a [SnapVideoException] when the environment does not
  /// support recording.
  @internal
  static Future<SnapRecording> start({
    required SnapVideoSettings settings,
    String? name,
    Finder? from,
    Rect? crop,
  }) async {
    final binding = WidgetsBinding.instance;
    if (binding is! SnaptestWidgetsFlutterBinding) {
      throw const SnapVideoException(
        'Video recording requires SnaptestWidgetsFlutterBinding, but the '
        'test binding is not installed or is a different type.\n'
        'Install it in flutter_test_config.dart before any other binding '
        'use:\n\n'
        'Future<void> testExecutable(FutureOr<void> Function() testMain) '
        'async {\n'
        '  SnaptestWidgetsFlutterBinding.ensureInitialized();\n'
        '  await loadFonts();\n'
        '  await testMain();\n'
        '}',
      );
    }
    if (!binding.inTest) {
      throw const SnapVideoException(
        'snap.recordVideo() must be called inside a running testWidgets '
        'body.',
      );
    }
    final existing = binding.activeRecording;
    if (existing != null) {
      throw SnapVideoException(
        'A recording is already active in this test '
        '(capturing: ${existing.isCapturing}).\n'
        'Only one recording per test is supported; call stop() on the '
        'previous SnapRecording before starting another.',
      );
    }

    final testName = name ?? Invoker.current?.liveTest.test.name;
    if (testName == null) {
      throw const SnapVideoException(
        'Could not determine a name for the recording.',
      );
    }
    final callCount = _videoCallCounts[testName] =
        (_videoCallCounts[testName] ?? 0) + 1;
    final counterSuffix = callCount > 1 ? '_$callCount' : '';
    final fileBase = '${testName.toValidSnaptestFilename()}$counterSuffix';

    final String outputPath;
    if (goldenFileComparator case LocalFileComparator(:final basedir)) {
      outputPath = goldenFileComparator
          .getTestUri(
            basedir.resolve(
              join(
                settings.pathPrefix,
                '$fileBase${settings.encoding.fileExtension}',
              ),
            ),
            null,
          )
          .toFilePath();
    } else {
      throw const SnapVideoException(
        'Could not determine an output path for the recording: '
        'goldenFileComparator is not a LocalFileComparator.',
      );
    }

    final ffmpegExecutable = await maybeRunAsync(
      () => resolveFfmpeg(
        executablePath: settings.ffmpegPath,
        encoding: settings.encoding,
      ),
    );
    if (ffmpegExecutable == null) {
      throw const SnapVideoException(
        'Could not resolve an FFmpeg executable.',
      );
    }

    final recording = SnapRecording._(
      binding: binding,
      settings: settings,
      from: from,
      crop: crop,
      outputPath: outputPath,
      // The spool lives in the system temp dir, not under .snaptest/:
      // cleanSnaps() wipes .snaptest/ at every test file's startup and
      // would race with a recording in flight in a parallel test file.
      spoolDir: Directory(
        join(
          Directory.systemTemp.path,
          'snaptest_video_spool_${fileBase}_pid${pid}_'
          '${DateTime.now().microsecondsSinceEpoch}',
        ),
      ),
      ffmpegExecutable: ffmpegExecutable,
    );

    binding.activeRecording = recording;
    addTearDown(recording._finalizeFromTearDown);

    // If a real scene is already painted (e.g. recordVideo called after
    // pumpWidget), capture it as the first frame without requiring another
    // pump. Otherwise the session stays armed until the first painted frame.
    if (!recording._isPlaceholderScene()) {
      await recording._captureNow();
    }

    return recording;
  }

  final SnaptestWidgetsFlutterBinding _binding;
  final String _outputPath;
  final Directory _spoolDir;
  final String _ffmpegExecutable;

  /// The settings this recording was started with.
  final SnapVideoSettings settings;

  /// The finder whose closest [RepaintBoundary] is captured each frame, or
  /// `null` to capture the whole view.
  final Finder? from;

  /// An optional rect in logical coordinates to trim every frame to.
  final Rect? crop;

  _RecordingState _state = _RecordingState.capturing;
  final List<_SpooledFrame> _frames = [];
  final List<Future<dynamic>> _pendingWrites = [];
  // ignore: use_late_for_private_fields_and_variables
  Future<Object?>? _finalizeFuture;
  late final int _anchorUs;
  int _frameSeq = 0;
  int _spooledBytes = 0;
  int? _stopUs;
  Size? _outputSize;
  bool _sourceSeen = false;
  String? _truncationReason;
  Object? _captureError;
  // ignore: use_late_for_private_fields_and_variables
  Future<File>? _stopFuture;

  /// Whether this recording is still observing frames.
  bool get isCapturing => _state == _RecordingState.capturing;

  /// The number of distinct painted frames captured so far.
  int get capturedFrameCount => _frames.length;

  /// The captured timeline length in simulated time.
  Duration get capturedDuration => _frames.isEmpty
      ? Duration.zero
      : Duration(microseconds: _frames.last.timeUs - _frames.first.timeUs);

  /// Whether a resource limit truncated this recording early.
  bool get wasTruncated => _truncationReason != null;

  /// The resource limit that truncated this recording, if any.
  String? get truncationReason => _truncationReason;

  int get _clockNowUs =>
      _binding.clock.now().microsecondsSinceEpoch;

  /// Drives one observed or subdivided pump for this recording.
  ///
  /// Called by [SnaptestWidgetsFlutterBinding.pump] while capturing.
  @internal
  Future<void> pumpForRecording(
    SnaptestWidgetsFlutterBinding binding,
    Duration? duration,
    EnginePhase phase,
  ) async {
    if (!isCapturing ||
        settings.timing != VideoTiming.smooth ||
        duration == null ||
        duration <= Duration.zero) {
      // Observed mode (and smooth mode's zero/null-duration pumps): run the
      // pump exactly once, then capture if it painted.
      final framesBefore = binding.drawnFrameCount;
      await binding.pumpOnce(duration, phase);
      if (_paintedSince(framesBefore, phase)) {
        await _captureAt(_clockNowUs);
      }
      return;
    }

    // Smooth mode: subdivide the positive-duration pump into frame-sized
    // steps at absolute grid boundaries, anchored to the recording start.
    // Total fake-clock advancement stays identical to `duration`.
    final deadlineUs = _clockNowUs + duration.inMicroseconds;
    while (_clockNowUs < deadlineUs && isCapturing) {
      final nowUs = _clockNowUs;
      var stepUs = _nextGridBoundaryUs(nowUs) - nowUs;
      if (stepUs <= 0) stepUs = 1;
      final remaining = deadlineUs - nowUs;
      if (stepUs > remaining) stepUs = remaining;

      final framesBefore = binding.drawnFrameCount;
      await binding.pumpOnce(Duration(microseconds: stepUs), phase);
      if (_paintedSince(framesBefore, phase)) {
        await _captureAt(_clockNowUs);
      }

      if (_frames.isNotEmpty &&
          _clockNowUs - _frames.first.timeUs >
              settings.maxSimulatedDuration.inMicroseconds) {
        _truncate(
          'Simulated duration exceeded '
          'SnapVideoSettings.maxSimulatedDuration '
          '(${settings.maxSimulatedDuration}).',
        );
      }
    }

    // If capture froze mid-pump (limit or capture error), still elapse the
    // rest of the requested duration so the test itself is unaffected.
    final leftoverUs = deadlineUs - _clockNowUs;
    if (leftoverUs > 0) {
      await binding.pumpOnce(Duration(microseconds: leftoverUs), phase);
    }
  }

  bool _paintedSince(int framesBefore, EnginePhase phase) =>
      phase.index >= EnginePhase.paint.index &&
      _binding.drawnFrameCount > framesBefore;

  /// The next frame-grid boundary strictly after [nowUs].
  ///
  /// Boundaries are rational multiples of `1/frameRate` seconds anchored to
  /// the recording start, computed with integer math so rounding does not
  /// accumulate.
  int _nextGridBoundaryUs(int nowUs) {
    final fps = settings.frameRate;
    var n = ((nowUs - _anchorUs) * fps) ~/ 1000000 + 1;
    var boundary = _anchorUs + (n * 1000000) ~/ fps;
    while (boundary <= nowUs) {
      n++;
      boundary = _anchorUs + (n * 1000000) ~/ fps;
    }
    return boundary;
  }

  /// Whether the current view still shows a flutter_test placeholder screen.
  ///
  /// These are never recorded: the time origin is the first real painted
  /// scene.
  bool _isPlaceholderScene() {
    if (from != null) {
      return false;
    }
    return find.text('Test starting...').evaluate().isNotEmpty ||
        find.text('Test finished.').evaluate().isNotEmpty;
  }

  /// Captures the current painted state at the current clock time.
  Future<void> _captureNow() => _captureAt(_clockNowUs);

  Future<void> _captureAt(int timeUs) async {
    if (!isCapturing || _isPlaceholderScene()) return;
    // Coalesce states at the same timestamp: keep the last painted state.
    if (_frames.isNotEmpty && _frames.last.timeUs == timeUs) {
      _frames.removeLast();
      _frameSeq--; // reuse the sequence number; the orphan file is temp data
    }
    // binding.runAsync (not maybeRunAsync): the returned future is created
    // in the real zone, so code outside the test's fake zone — like the
    // addTearDown finalizer — can await it without stalling on the fake
    // microtask queue.
    final task = _binding.runAsync(() async {
      try {
        await _captureFrame(timeUs);
      } catch (e) {
        _captureError = e;
        _truncate('Capture failed: $e');
      }
    });
    _pendingWrites.add(task);
    await task;
  }

  Future<void> _captureFrame(int timeUs) async {
    final element = _resolveSourceElement();
    if (element == null) {
      return;
    }

    final device = activeDeviceVariant?.$1;
    final orientation = activeDeviceVariant?.$2 ?? Orientation.portrait;

    final captured = await captureElementImage(
      element,
      device: device,
      orientation: orientation,
      includeDeviceFrame: settings.includeDeviceFrame,
    );

    var image = captured.image;
    if (settings.showPointers &&
        _binding.activePointerPositions.isNotEmpty) {
      image = await drawPointerIndicators(
        image,
        captured,
        _binding.activePointerPositions.values,
      );
    }
    if (crop != null) {
      image = await cropCapturedImage(image, crop!, captured);
    }
    image = await _compositeOnBackground(image);

    final size = Size(image.width.toDouble(), image.height.toDouble());
    if (_outputSize == null) {
      _outputSize = size;
    } else if (_outputSize != size) {
      image.dispose();
      throw SnapVideoException(
        'The captured frame size changed mid-recording from '
        '${_outputSize!.width}x${_outputSize!.height} to '
        '${size.width}x${size.height}.\n'
        'Keep the viewport, orientation, and `from` source fixed while '
        'recording — mid-recording resizes are not supported.',
      );
    }

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw const SnapVideoException(
        'Could not encode a captured frame as PNG.',
      );
    }
    final bytes = byteData.buffer.asUint8List();

    _spooledBytes += bytes.length;
    _frames.add(_SpooledFrame(timeUs, _frameSeq));

    final file = File(
      join(
        _spoolDir.path,
        'frames',
        '${_frameSeq.toString().padLeft(6, '0')}.png',
      ),
    );
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    _frameSeq++;

    if (_frames.length > settings.maxCapturedFrames) {
      _truncate(
        'Captured frame count exceeded '
        'SnapVideoSettings.maxCapturedFrames '
        '(${settings.maxCapturedFrames}).',
      );
    } else if (_spooledBytes > settings.maxSpoolBytes) {
      _truncate(
        'Spool size exceeded SnapVideoSettings.maxSpoolBytes '
        '(${settings.maxSpoolBytes} bytes).',
      );
    }
  }

  Element? _resolveSourceElement() {
    final elements = (from ?? find.byType(View)).evaluate();
    if (elements.isEmpty) {
      if (from != null && _sourceSeen) {
        throw SnapVideoException(
          'The `from` finder ($from) stopped matching during recording.\n'
          'A video source cannot disappear mid-recording; remove the widget '
          'before stopping the recording.',
        );
      }
      // Whole-view capture with nothing mounted, or a `from` source that
      // has not appeared yet: stay armed.
      return null;
    }
    if (elements.length > 1) {
      throw SnapVideoException(
        'The `from` finder ($from) must match exactly one element while '
        'recording, but it matched ${elements.length}.',
      );
    }
    _sourceSeen = true;
    return elements.single;
  }

  /// Flattens [image] onto [SnapVideoSettings.backgroundColor] and pads odd
  /// dimensions up to even, as required by `yuv420p` encoders.
  Future<ui.Image> _compositeOnBackground(ui.Image image) async {
    final width = image.width + (image.width & 1);
    final height = image.height + (image.height & 1);
    if (width == image.width &&
        height == image.height &&
        settings.backgroundColor.a == 0.0) {
      // Nothing to flatten or pad.
      return image;
    }
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawRect(
        Offset.zero & Size(width.toDouble(), height.toDouble()),
        Paint()..color = settings.backgroundColor,
      )
      ..drawImage(image, Offset.zero, Paint());
    final picture = recorder.endRecording();
    final composite = await picture.toImage(width, height);
    picture.dispose();
    image.dispose();
    return composite;
  }

  /// Stops capturing frames immediately and finishes encoding.
  ///
  /// Idempotent — safe to call multiple times, including concurrently; all
  /// calls return the same result.
  Future<File> stop() => _stopFuture ??= _stop();

  Future<File> _stop() async {
    freeze();
    final result = await _finalizeAndPublish();
    if (result is File) {
      return result;
    }
    if (result is Error) {
      throw result;
    }
    throw result as Exception? ?? _finalizeReturnedNull();
  }

  /// Freezes capture: stops observing pumps and records the stop time.
  ///
  /// Synchronous and side-effect-light so it can run in the test body's
  /// `finally` and in [SnaptestWidgetsFlutterBinding.postTest], where async
  /// encoding work is not allowed.
  @internal
  void freeze() {
    if (_state != _RecordingState.capturing) return;
    _state = _RecordingState.frozen;
    _stopUs = _binding.inTest ? _clockNowUs : null;
    if (_binding.activeRecording == this) {
      _binding.activeRecording = null;
    }
  }

  void _truncate(String reason) {
    _truncationReason ??= reason;
    freeze();
  }

  /// Registered with `addTearDown` at [start]: awaits the encoder after the
  /// test body, using only pixels and settings frozen at start.
  ///
  /// TearDown callbacks run outside the test's FakeAsync zone, so this must
  /// only ever await real-zone futures — `_finalizeFuture` is produced by
  /// [TestWidgetsFlutterBinding.runAsync] for exactly that reason.
  Future<void> _finalizeFromTearDown() async {
    final result = await _finalizeAndPublish();
    if (result is! File) {
      if (_stopFuture != null) {
        // [stop] was already called: the error was delivered to that
        // caller, so do not fail the test again from teardown.
        return;
      }
      final e = result as Exception? ?? _finalizeReturnedNull();
      if (settings.onFailure == VideoFailurePolicy.warn) {
        // ignore: avoid_print
        print(
          'Warning: snaptest video recording failed to finalize: $e\n'
          'Retained artifacts are in ${_spoolDir.path}.',
        );
        return;
      }
      throw e;
    }
  }

  /// The exception used when `runAsync` completes with no result.
  static SnapVideoException _finalizeReturnedNull() =>
      const SnapVideoException(
        'Video finalization returned no result.',
      );

  /// Ensures the recording is finalized: waits for pending spool writes,
  /// then resamples and encodes on the real event loop.
  ///
  /// The whole finalize runs inside one [TestWidgetsFlutterBinding.runAsync]
  /// section so the returned future is a real-zone future — safe to await
  /// from test teardown, which runs outside the fake zone. Errors are
  /// carried as values because `runAsync` reports exceptions instead of
  /// propagating them; callers unwrap and rethrow.
  Future<Object?> _finalizeAndPublish() =>
      _finalizeFuture ??=
          (_binding.inTest
              ? _binding.runAsync(() async {
                  try {
                    return await _doFinalize();
                  } on Object catch (e) {
                    return e;
                  }
                })
              : _doFinalize());

  Future<File> _doFinalize() async {
    freeze();
    // Wait for any outstanding spool writes; they never throw.
    await Future.wait<dynamic>(_pendingWrites);
    _pendingWrites.clear();

    try {
      if (_frames.isEmpty) {
        throw const SnapVideoException(
          'The recording captured no frames — no painted scene was observed '
          'before the recording stopped.\n'
          'If you started before pumpWidget, make sure the test pumps at '
          'least once while recording.',
        );
      }

      final output = await _encodeAndPublish();
      if (_captureError != null) {
        throw SnapVideoException(
          'The recording stopped with a capture error: $_captureError\n'
          'The truncated video was published to ${output.path}.',
        );
      }
      return output;
    } finally {
      // The manifest always reflects the final state, including truncation
      // and capture errors, and survives next to the spool on failure.
      try {
        await _writeManifestNow();
      } catch (_) {
        // Best-effort diagnostics; never mask the real result.
      }
      _state = _RecordingState.finalized;
    }
  }

  /// Resamples the recorded timeline onto the output frame grid and encodes
  /// it. Runs inside a real-async section.
  Future<File> _encodeAndPublish() async {
    final frameFiles = _resampledFrameFiles();
    // Encode next to the final output so the publish rename stays on one
    // filesystem (the spool lives in the system temp dir, which may be
    // mounted separately).
    final outputFile = File(_outputPath);
    await outputFile.parent.create(recursive: true);
    final tempOutput = File(
      '$_outputPath.tmp${settings.encoding.fileExtension}',
    );
    final diagnostics = StringBuffer();

    try {
      await encodeImagePipe(
        executable: _ffmpegExecutable,
        encoding: settings.encoding,
        frameRate: settings.frameRate,
        frameFiles: frameFiles,
        outputFile: tempOutput,
        timeout: settings.encoderTimeout,
        diagnostics: diagnostics,
      );
    } on SnapVideoException catch (e) {
      throw SnapVideoException(
        '${e.message}\n'
        'Retained frame spool and manifest: ${_spoolDir.path}',
      );
    }

    final fileName = _truncationReason == null
        ? outputFile.path
        : '${withoutExtension(outputFile.path)}.truncated'
              '${settings.encoding.fileExtension}';
    await tempOutput.rename(fileName);
    // Success: remove the temporary spool. This stays inside the real-async
    // section — dart:io futures never complete in the fake test zone.
    try {
      await _spoolDir.delete(recursive: true);
    } catch (_) {
      // Cleanup is best-effort.
    }
    return File(fileName);
  }

  /// Maps each output frame index to the newest captured frame at or before
  /// its sample time.
  ///
  /// With time measured from the first captured frame, emits
  /// `N = max(ceil(stopTime * fps), ceil(lastFrameTime * fps) + 1)` frames —
  /// so the final state appears for at least one frame, and
  /// [SnapVideoSettings.finalHold] adds
  /// playback time on top.
  List<File> _resampledFrameFiles() {
    final fps = settings.frameRate;
    final originUs = _frames.first.timeUs;
    final lastRelUs = _frames.last.timeUs - originUs;
    final stopRelUs =
        (_stopUs ?? _frames.last.timeUs) -
        originUs +
        settings.finalHold.inMicroseconds;

    final frameCount = math.max(
      (stopRelUs * fps + 999999) ~/ 1000000,
      (lastRelUs * fps + 999999) ~/ 1000000 + 1,
    );

    final files = <File>[];
    var cursor = 0;
    for (var i = 0; i < frameCount; i++) {
      final sampleUs = (i * 1000000) ~/ fps;
      while (cursor + 1 < _frames.length &&
          _frames[cursor + 1].timeUs - originUs <= sampleUs) {
        cursor++;
      }
      final index = _frames[cursor].index;
      files.add(
        File(
          join(
            _spoolDir.path,
            'frames',
            '${index.toString().padLeft(6, '0')}.png',
          ),
        ),
      );
    }
    return files;
  }

  /// Writes the spool manifest next to the frame PNGs.
  ///
  /// Called once during [_doFinalize], inside the same real-async section —
  /// dart:io futures can never complete in the fake test zone.
  Future<void> _writeManifestNow() async {
    await _spoolDir.create(recursive: true);
    final manifest = <String, Object?>{
      'version': 1,
      'frameRate': settings.frameRate,
      'timing': settings.timing.name,
      'originUs': _frames.isEmpty ? null : _frames.first.timeUs,
      'stopUs': _stopUs,
      'truncated': _truncationReason != null,
      'limit': _truncationReason,
      'captureError': _captureError?.toString(),
      'output': _outputPath,
      'frames': [
        for (final frame in _frames)
          <String, Object?>{
            't': frame.timeUs,
            'file': 'frames/${frame.index.toString().padLeft(6, '0')}.png',
          },
      ],
    };
    await File(
      join(_spoolDir.path, 'manifest.json'),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
  }
}
