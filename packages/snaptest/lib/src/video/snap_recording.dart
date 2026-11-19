/// A test-scoped video recording session started by [Snap.recordVideo].
///
/// The session passively observes the frames a widget test paints: it never
/// pumps, loads fonts, or precaches images. Opting into real shadows repaints
/// the current scene without advancing the clock. Each
/// painted frame is resampled onto the configured frame grid and streamed
/// as raw pixels to FFmpeg, with bounded buffering and no PNG spool.
/// @docImport 'package:snaptest/src/snap.dart';
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:snaptest/src/capture.dart';
import 'package:snaptest/src/test_devices_variant.dart';
import 'package:snaptest/src/util.dart';
import 'package:snaptest/src/video/ffmpeg_encoder.dart';
import 'package:snaptest/src/video/pointer_indicators.dart';
import 'package:snaptest/src/video/snaptest_binding.dart';
import 'package:snaptest/src/video/video_settings.dart';
// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart';

/// Tracks the number of recordings per test name for file naming.
final Map<String, int> _videoCallCounts = {};

enum _RecordingState { capturing, frozen, finalized }

class _CapturedFrame {
  const _CapturedFrame(this.timeUs);

  /// Absolute fake-clock timestamp in microseconds.
  final int timeUs;
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
    if (settings.minimumPointerDuration.isNegative) {
      throw ArgumentError.value(
        settings.minimumPointerDuration,
        'minimumPointerDuration',
        'Must not be negative',
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
            basedir.resolveUri(
              Uri.file(
                join(
                  settings.pathPrefix,
                  '$fileBase${settings.encoding.fileExtension}',
                ),
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

    // Run in a real-async section: awaiting a synchronously-completed
    // future inside the test's FakeAsync zone deadlocks, because the
    // continuation is queued on a microtask queue nothing flushes.
    await maybeRunAsync(_sweepStaleSpools);

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
    if (settings.renderShadows) {
      debugDisableShadows = false;
      recording._repaintScene();
    }

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
  final List<_CapturedFrame> _frames = [];
  Future<void>? _pendingWrite;
  RawVideoEncoder? _encoder;
  Uint8List? _pendingPixels;
  int? _pendingTimeUs;
  late int _originUs;
  late int _nextOutputFrame = 0;
  late final _frameCapture = VideoFrameCapture(settings, crop);
  late final _pointerIndicators =
      settings.minimumPointerDuration > Duration.zero &&
          (settings.showPointers || settings.pointerIndicator != null)
      ? PointerIndicators(settings.minimumPointerDuration)
      : null;
  final bool _previousDisableShadows = debugDisableShadows;
  Object? _streamError;
  // ignore: use_late_for_private_fields_and_variables
  Future<Object?>? _finalizeFuture;
  late final int _anchorUs;
  int? _stopUs;
  Size? _outputSize;
  bool _sourceSeen = false;
  String? _truncationReason;
  Object? _captureError;
  int? _pointerRecaptureUs;
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

  int get _clockNowUs => _binding.clock.now().microsecondsSinceEpoch;

  void _repaintScene() {
    void mark(RenderObject object) {
      object
        ..markNeedsPaint()
        ..visitChildren(mark);
    }

    for (final view in _binding.renderViews) {
      if (view.debugNeedsPaint || view.debugNeedsLayout) continue;
      mark(view);
      view.owner!.flushPaint();
    }
  }

  /// Records overlay events without starting async work in a pointer callback.
  @internal
  void trackPointerEvent(PointerEvent event) =>
      _pointerIndicators?.handle(event, _clockNowUs);

  /// Flags the current clock time for a re-capture because a pointer
  /// indicator changed (e.g. a pointer was released without any repaint).
  ///
  /// Called by [SnaptestWidgetsFlutterBinding.handlePointerEvent]. It only
  /// marks a timestamp instead of starting a second real-async section — a
  /// concurrent `runAsync` asserts on reentrancy, and its inline fallback
  /// would run `dart:io` in the FakeAsync zone and hang. The flag is drained
  /// by the next [_captureAt] or by [_doFinalize], both already inside a
  /// real-async section.
  @internal
  void markPointerStateChanged() {
    if (!isCapturing || _isPlaceholderScene()) return;
    _pointerRecaptureUs ??= _clockNowUs;
  }

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
      if (_paintedSince(framesBefore, phase) ||
          (_pointerIndicators != null &&
              phase.index >= EnginePhase.paint.index)) {
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
      if (_paintedSince(framesBefore, phase) ||
          (_pointerIndicators != null &&
              phase.index >= EnginePhase.paint.index)) {
        await _captureAt(_clockNowUs);
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
    }
    // A pending pointer-state recapture is drained inside this same
    // real-async section — a second runAsync would trip the reentrancy
    // assert. If the flag's instant matches the new capture's, the
    // post-release state is already what gets captured below.
    final pendingUs = _pointerRecaptureUs;
    if (pendingUs != null && pendingUs < timeUs) {
      _pointerRecaptureUs = null;
      // A frame captured at the release instant already observed the
      // release; only strictly-earlier states kept the indicator.
      if (_frames.isNotEmpty && _frames.last.timeUs >= pendingUs) {
        _frames.removeLast();
      }
    } else if (pendingUs == timeUs) {
      _pointerRecaptureUs = null;
    }
    // binding.runAsync (not maybeRunAsync): the returned future is created
    // in the real zone, so code outside the test's fake zone — like the
    // addTearDown finalizer — can await it without stalling on the fake
    // microtask queue.
    final task = _binding.runAsync(() async {
      try {
        final indicators = _pointerIndicators;
        if (indicators != null) {
          for (final change in indicators.takeChangesThrough(timeUs)) {
            if (!isCapturing) break;
            if (_frames.isNotEmpty && change.timeUs < timeUs) {
              await _captureFrame(
                change.timeUs,
                pointers: change.positions,
                overlayOnly: true,
              );
            }
          }
        }
        if (pendingUs != null && pendingUs < timeUs) {
          await _captureFrame(pendingUs);
        }
        if (isCapturing) {
          await _captureFrame(timeUs, pointers: indicators?.positions);
        }
      } catch (e) {
        _captureError = e;
        _truncate('Capture failed: $e');
      }
    });
    await task;
  }

  Future<void> _captureFrame(
    int timeUs, {
    List<Offset>? pointers,
    bool overlayOnly = false,
  }) async {
    final element = overlayOnly ? null : _resolveSourceElement();
    if (!overlayOnly && element == null) {
      return;
    }

    final device = activeDeviceVariant?.$1;
    final orientation = activeDeviceVariant?.$2 ?? Orientation.portrait;

    final image = overlayOnly
        ? await _frameCapture.captureOverlay(pointers!)
        : await _frameCapture.capture(
            element!,
            device: device,
            orientation: orientation,
            pointers:
                pointers ??
                (settings.showPointers || settings.pointerIndicator != null
                    ? _binding.activePointerPositions.values
                    : const <Offset>[]),
          );
    final Uint8List bytes;
    if (image == null) {
      bytes = _pendingPixels!;
    } else {
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

      final ByteData? byteData;
      try {
        byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
      } finally {
        image.dispose();
      }
      if (byteData == null) {
        throw const SnapVideoException(
          'Could not read the captured frame pixels.',
        );
      }
      bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    }
    await _queueFrame(bytes, timeUs);
    if (_frames.isNotEmpty && _frames.last.timeUs == timeUs) {
      _frames.removeLast();
    }
    _frames.add(_CapturedFrame(timeUs));

    if (isCapturing &&
        timeUs - _frames.first.timeUs >
            settings.maxSimulatedDuration.inMicroseconds) {
      _truncate(
        'Simulated duration exceeded '
        'SnapVideoSettings.maxSimulatedDuration '
        '(${settings.maxSimulatedDuration}).',
      );
    }

    if (_frames.length > settings.maxCapturedFrames) {
      _truncate(
        'Captured frame count exceeded '
        'SnapVideoSettings.maxCapturedFrames '
        '(${settings.maxCapturedFrames}).',
      );
    } else if (_temporaryOutput.existsSync() &&
        _temporaryOutput.lengthSync() > settings.maxSpoolBytes) {
      _truncate(
        'Temporary video size exceeded SnapVideoSettings.maxSpoolBytes '
        '(${settings.maxSpoolBytes} bytes).',
      );
    }
  }

  File get _temporaryOutput => File(
    join(_spoolDir.path, 'output${settings.encoding.fileExtension}'),
  );

  Future<void> _queueFrame(Uint8List pixels, int timeUs) async {
    await _pendingWrite;
    if (_streamError != null) {
      throw SnapVideoException('FFmpeg stream failed: $_streamError');
    }
    if (_encoder == null) {
      await _spoolDir.create(recursive: true);
      _encoder = await RawVideoEncoder.start(
        executable: _ffmpegExecutable,
        encoding: settings.encoding,
        frameRate: settings.frameRate,
        width: _outputSize!.width.toInt(),
        height: _outputSize!.height.toInt(),
        outputFile: _temporaryOutput,
        timeout: settings.encoderTimeout,
      );
    }
    if (_pendingTimeUs == null) _originUs = timeUs;
    if (_pendingPixels != null && timeUs > _pendingTimeUs!) {
      // Keep one timestamp uncommitted: another paint at that instant may
      // replace it. Only samples strictly before the new instant are final.
      final end =
          ((timeUs - _originUs) * settings.frameRate + 999999) ~/ 1000000;
      final count = end - _nextOutputFrame;
      if (count > 0) {
        _pendingWrite = _encoder!
            .writeFrames(_pendingPixels!, count)
            .catchError(
              (Object error) {
                _streamError = error;
              },
            );
        _nextOutputFrame = end;
      }
    }
    _pendingPixels = pixels;
    _pendingTimeUs = timeUs;
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

  /// Stops capturing frames immediately and finishes encoding.
  ///
  /// Idempotent — safe to call multiple times, including concurrently; all
  /// calls return the same result. Under [VideoFailurePolicy.warn] a failed
  /// finalization prints diagnostics and returns the retained partial
  /// artifact (or the intended output path when nothing was produced)
  /// instead of throwing.
  Future<File> stop() => _stopFuture ??= _stop();

  Future<File> _stop() async {
    freeze();
    final result = await _finalizeAndPublish();
    if (result is File) {
      return result;
    }
    if (settings.onFailure == VideoFailurePolicy.warn) {
      // ignore: avoid_print
      print(
        'Warning: snaptest video recording failed to finalize: $result\n'
        'Retained artifacts are in ${_spoolDir.path}.',
      );
      final partial = File(
        join(_spoolDir.path, 'output${settings.encoding.fileExtension}'),
      );
      if (partial.existsSync()) {
        return partial;
      }
      return File(_outputPath);
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
    if (settings.renderShadows) {
      debugDisableShadows = _previousDisableShadows;
      _repaintScene();
    }
    // A recording stopped mid-drag must not leak held pointers into the
    // next recording's indicators.
    _binding.activePointerPositions.clear();
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
  static SnapVideoException _finalizeReturnedNull() => const SnapVideoException(
    'Video finalization returned no result.',
  );

  /// Drains pending frames and finishes encoding on the real event loop.
  ///
  /// The whole finalize runs inside one [TestWidgetsFlutterBinding.runAsync]
  /// section so the returned future is a real-zone future — safe to await
  /// from test teardown, which runs outside the fake zone. Errors are
  /// carried as values because `runAsync` reports exceptions instead of
  /// propagating them; callers unwrap and rethrow.
  Future<Object?> _finalizeAndPublish() => _finalizeFuture ??= (_binding.inTest
      ? _binding.runAsync(_finalizeResult)
      : _finalizeResult());

  Future<Object> _finalizeResult() async {
    try {
      return await _doFinalize();
    } on Object catch (error) {
      return error;
    }
  }

  Future<File> _doFinalize() async {
    freeze();
    await _pendingWrite;

    try {
      if (_pointerIndicators case final indicators?) {
        if (_frames.isNotEmpty) {
          final endUs =
              (_stopUs ?? _frames.last.timeUs) +
              settings.finalHold.inMicroseconds;
          for (final change in indicators.takeChangesThrough(endUs)) {
            if (_truncationReason != null) break;
            if (change.timeUs <= (_stopUs ?? _frames.last.timeUs) ||
                change.timeUs < endUs) {
              await _captureFrame(
                change.timeUs,
                pointers: change.positions,
                overlayOnly: true,
              );
            }
          }
        }
      }

      // A pointer-release recapture flagged near the end drains here, inside
      // this same real-async section.
      final pendingUs = _pointerRecaptureUs;
      if (pendingUs != null) {
        _pointerRecaptureUs = null;
        if (_frames.isNotEmpty && _frames.last.timeUs >= pendingUs) {
          _frames.removeLast();
        }
        try {
          await _captureFrame(
            pendingUs,
            pointers: _binding.activePointerPositions.values.toList(),
            overlayOnly: _frames.isNotEmpty,
          );
        } catch (e) {
          _captureError = e;
          _truncate('Capture failed: $e');
        }
      }

      if (_frames.isEmpty) {
        throw SnapVideoException(
          'The recording captured no frames — no painted scene was observed '
          'before the recording stopped.\n'
          'If you started before pumpWidget, make sure the test pumps at '
          'least once while recording.\n'
          '${_captureError == null ? '' : 'Capture error: $_captureError'}',
        );
      }

      if (_outputFrameCount == 1) {
        // ignore: avoid_print
        print(
          'Warning: snaptest video contains only one frame. '
          'Pump a longer duration while recording, or set finalHold '
          'for a still image.',
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
      await _encoder?.abort();
      _frameCapture.dispose();
      _pendingPixels = null;
      // The manifest always reflects the final state, including truncation
      // and capture errors, and survives next to the spool on failure.
      // On success the spool is already deleted; only leave a manifest
      // when artifacts were actually retained (failures, truncation).
      try {
        if (_spoolDir.existsSync()) {
          await _writeManifestNow();
        }
      } catch (_) {
        // Best-effort diagnostics; never mask the real result.
      }
      _state = _RecordingState.finalized;
    }
  }

  /// Resamples the recorded timeline onto the output frame grid and encodes
  /// it. Runs inside a real-async section.
  Future<File> _encodeAndPublish() async {
    final outputFile = File(_outputPath);
    // Encode inside the unique spool dir: a temporary output next to
    // .snaptest/ would be wiped by a parallel test file's cleanSnaps() and
    // would collide between same-named tests running concurrently.
    final tempOutput = _temporaryOutput;

    try {
      await _pendingWrite;
      if (_streamError != null) {
        throw SnapVideoException('FFmpeg stream failed: $_streamError');
      }
      final remaining = _outputFrameCount - _nextOutputFrame;
      await _encoder!.writeFrames(_pendingPixels!, remaining);
      _nextOutputFrame += remaining;
      await _encoder!.finish();
      _encoder = null;
    } on SnapVideoException catch (e) {
      await _encoder?.abort();
      throw SnapVideoException(
        '${e.message}\n'
        '${_encoder?.diagnostics ?? ''}\n'
        'Retained partial video and manifest: ${_spoolDir.path}',
      );
    }
    if (!tempOutput.existsSync() || tempOutput.lengthSync() == 0) {
      throw const SnapVideoException('FFmpeg produced no output.');
    }
    if (tempOutput.lengthSync() > settings.maxSpoolBytes) {
      _truncate(
        'Temporary video size exceeded SnapVideoSettings.maxSpoolBytes '
        '(${settings.maxSpoolBytes} bytes).',
      );
    }

    final fileName = _truncationReason == null
        ? outputFile.path
        : '${withoutExtension(outputFile.path)}.truncated'
              '${settings.encoding.fileExtension}';
    // Recreate the output dir right before copying: a parallel test
    // file's cleanSnaps() can delete test/.snaptest/ while the encode is
    // still running.
    await File(fileName).parent.create(recursive: true);
    // Copy (not rename): the spool lives in the system temp dir, which may
    // be mounted on a different filesystem than the output.
    await tempOutput.copy(fileName);
    if (_truncationReason == null && _captureError == null) {
      try {
        await _spoolDir.delete(recursive: true);
      } catch (_) {
        // Cleanup is best-effort.
      }
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
  int get _outputFrameCount {
    final fps = settings.frameRate;
    final originUs = _frames.first.timeUs;
    final lastRelUs = _frames.last.timeUs - originUs;
    final stopRelUs =
        (_stopUs ?? _frames.last.timeUs) -
        originUs +
        settings.finalHold.inMicroseconds;

    return math.max(
      (stopRelUs * fps + 999999) ~/ 1000000,
      (lastRelUs * fps + 999999) ~/ 1000000 + 1,
    );
  }

  /// Writes timing and failure diagnostics next to the temporary video.
  ///
  /// Called once during [_doFinalize], inside the same real-async section —
  /// dart:io futures can never complete in the fake test zone.
  Future<void> _writeManifestNow() async {
    await _spoolDir.create(recursive: true);
    final manifest = <String, Object?>{
      'version': 2,
      'frameRate': settings.frameRate,
      'timing': settings.timing.name,
      'originUs': _frames.isEmpty ? null : _frames.first.timeUs,
      'stopUs': _stopUs,
      'truncated': _truncationReason != null,
      'limit': _truncationReason,
      'captureError': _captureError?.toString(),
      'streamError': _streamError?.toString(),
      'submittedFrameCount': _nextOutputFrame,
      'width': _outputSize?.width,
      'height': _outputSize?.height,
      'output': _outputPath,
      'frames': [
        for (final frame in _frames) <String, Object?>{'t': frame.timeUs},
      ],
    };
    await File(
      join(_spoolDir.path, 'manifest.json'),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
  }
}

/// Deletes frame spools left behind by crashed or killed test processes.
///
/// Only spools older than 30 minutes are removed: a live recording in a
/// parallel test process could share the system temp dir, so in-flight
/// spools must never be swept.
Future<void> _sweepStaleSpools() async {
  final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
  try {
    await for (final entity in Directory.systemTemp.list(
      followLinks: false,
    )) {
      if (entity is! Directory ||
          !basename(entity.path).startsWith('snaptest_video_spool_')) {
        continue;
      }
      try {
        if (entity.statSync().modified.isBefore(cutoff)) {
          entity.deleteSync(recursive: true);
        }
      } catch (_) {
        // Best-effort cleanup; a busy or foreign spool is left alone.
      }
    }
  } catch (_) {
    // Listing the temp dir is best-effort too.
  }
}
