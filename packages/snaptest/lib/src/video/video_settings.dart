/// @docImport 'package:snaptest/src/snap.dart';
/// @docImport 'package:snaptest/src/test_devices_variant.dart';
/// @docImport 'package:snaptest/src/video/ffmpeg_encoder.dart';
/// @docImport 'package:snaptest/src/video/snap_recording.dart';
library;

import 'dart:ui';

import 'package:meta/meta.dart';
import 'package:snaptest/src/constants.dart';

/// How a [SnapRecording] advances the test clock while observing pumps.
enum VideoTiming {
  /// Every pump runs exactly once, unchanged. Painted states are shown at
  /// their test-clock timestamps, and the previous state is held across gaps
  /// where the test advanced time without painting.
  ///
  /// This is the default and does not alter test execution at all.
  observed,

  /// Positive-duration pumps are subdivided into frame-sized steps at the
  /// recording's frame grid, so animations appear smooth at the simulated
  /// speed.
  ///
  /// This runs more frames than the test would otherwise produce, which can
  /// change execution: animation listeners, timers started by frames,
  /// post-frame callbacks, physics, and `pumpAndSettle` iteration counts may
  /// all behave differently. The total fake-clock advancement per pump stays
  /// identical to the requested duration.
  ///
  /// Intended for documentation and demo recordings, not for debugging.
  smooth,
}

/// A typed video encoding profile.
///
/// Profiles map to a concrete codec/container combination and are validated
/// against the locally installed FFmpeg build before recording starts.
sealed class VideoEncoding {
  const VideoEncoding._();

  /// H.264 in an MP4 container (`libx264`, `yuv420p`, `+faststart`).
  ///
  /// [crf] controls quality (lower is better; sane range 0-51, default 20).
  /// [preset] trades encoding speed for compression efficiency; defaults to
  /// `'medium'`.
  const factory VideoEncoding.h264({int crf, String preset}) = _H264Encoding;

  /// The file extension for the encoded container, including the dot.
  String get fileExtension;

  /// FFmpeg arguments selecting the codec, quality and container.
  List<String> get ffmpegCodecArguments;

  /// The FFmpeg encoder name to validate, e.g. `libx264`.
  String get ffmpegEncoderName;
}

class _H264Encoding extends VideoEncoding {
  const _H264Encoding({this.crf = 20, this.preset = 'medium'}) : super._();

  /// Constant-rate-factor quality for libx264 (0-51, lower is better).
  final int crf;

  /// The libx264 preset, e.g. `medium`, `slow`, `veryfast`.
  final String preset;

  @override
  String get fileExtension => '.mp4';

  @override
  String get ffmpegEncoderName => 'libx264';

  @override
  List<String> get ffmpegCodecArguments => [
    '-c:v',
    'libx264',
    '-crf',
    '$crf',
    '-preset',
    preset,
    '-pix_fmt',
    'yuv420p',
    '-movflags',
    '+faststart',
    '-f',
    'mp4',
  ];
}

/// What to do when a recording or its encoder fails.
enum VideoFailurePolicy {
  /// Throw a [SnapVideoException]. This is the default.
  fail,

  /// Print diagnostics, retain whatever artifacts exist, and continue.
  ///
  /// Useful for best-effort debugging recordings that should never break a
  /// build.
  warn,
}

/// Controls how a [SnapRecording] captures and encodes video.
///
/// The defaults produce a 30 fps, observed-timing, H.264 MP4 with an opaque
/// white background:
/// ```dart
/// final recording = await snap.recordVideo(
///   settings: const SnapVideoSettings(
///     frameRate: 60,
///     timing: VideoTiming.smooth,
///     includeDeviceFrame: true,
///   ),
/// );
/// ```
@immutable
class SnapVideoSettings {
  /// Creates video recording settings.
  const SnapVideoSettings({
    this.frameRate = 30,
    this.timing = VideoTiming.observed,
    this.encoding = const VideoEncoding.h264(),
    this.includeDeviceFrame = false,
    this.showPointers = false,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.pathPrefix = kDefaultPathPrefix,
    this.finalHold = Duration.zero,
    this.ffmpegPath,
    this.maxSimulatedDuration = const Duration(minutes: 5),
    this.maxCapturedFrames = 20000,
    this.maxSpoolBytes = 1 << 30,
    this.encoderTimeout = const Duration(minutes: 2),
    this.onFailure = VideoFailurePolicy.fail,
  }) : assert(frameRate > 0, 'frameRate must be positive'),
       assert(maxCapturedFrames > 0, 'maxCapturedFrames must be positive'),
       assert(maxSpoolBytes > 0, 'maxSpoolBytes must be positive');

  /// Output frames per second, sampled onto a constant-frame-rate grid.
  ///
  /// Defaults to 30. The grid is anchored to the first captured frame, so
  /// recordings do not invent time before the first painted scene.
  final int frameRate;

  /// How pumps advance the test clock. See [VideoTiming].
  final VideoTiming timing;

  /// The encoding profile for the final video file.
  final VideoEncoding encoding;

  /// Whether to composite each frame inside the device frame of the active
  /// [TestDevicesVariant] device.
  ///
  /// Only applies when the test runs with [TestDevicesVariant]; recordings
  /// of tests without a device variant capture the current view as-is.
  final bool includeDeviceFrame;

  /// Whether to paint a touch indicator over each active pointer.
  ///
  /// The observing binding tracks down/move/up pointer events and
  /// composites a ring-and-dot indicator at each current position, like a
  /// screen-recording "show touches" overlay. Useful for demos that should
  /// visualize gestures. Indicators appear only while a pointer is held
  /// across a captured frame — a quick tap between pumps shows no dot.
  ///
  /// Defaults to `false`.
  final bool showPointers;

  /// The opaque background composited behind every frame.
  ///
  /// H.264 video (`yuv420p`) has no alpha channel, so transparency would
  /// otherwise render as black artifacts. Alpha compositing happens at
  /// capture time; the setting defaults to opaque white.
  final Color backgroundColor;

  /// Directory path prefix where the video is saved.
  ///
  /// Defaults to `.snaptest/` (the same directory screenshots go to) and
  /// should end with a forward slash.
  final String pathPrefix;

  /// Extra simulated duration appended after the recording stops.
  ///
  /// The last painted state is held on screen for this long. Defaults to
  /// zero so the timeline never invents time; opt in for demos that should
  /// linger on the final state.
  final Duration finalHold;

  /// Explicit path to an `ffmpeg` executable.
  ///
  /// When `null` (the default), `ffmpeg` is discovered on `PATH`. Set this
  /// on CI systems where FFmpeg lives at a known location.
  final String? ffmpegPath;

  /// Maximum simulated duration the recorder will capture.
  ///
  /// Once the recording's captured timeline exceeds this, capture freezes
  /// and the artifact is marked truncated. Guards against runaway
  /// `pumpAndSettle` loops filling the disk. Defaults to 5 minutes.
  final Duration maxSimulatedDuration;

  /// Maximum number of captured frames kept in the spool.
  ///
  /// Exceeding this freezes capture and marks the artifact truncated.
  final int maxCapturedFrames;

  /// Maximum total bytes of the temporary PNG spool.
  ///
  /// Exceeding this freezes capture and marks the artifact truncated.
  /// Defaults to 1 GiB.
  final int maxSpoolBytes;

  /// Wall-clock timeout for the FFmpeg encoder process.
  ///
  /// Encoding happens after the test body completes and is not simulated
  /// time. Defaults to 2 minutes.
  final Duration encoderTimeout;

  /// Whether capture or encoding failures throw or only warn.
  final VideoFailurePolicy onFailure;
}
