/// @docImport 'package:flutter/rendering.dart';
/// @docImport 'package:flutter_test/flutter_test.dart';
/// @docImport 'package:snaptest/src/snap.dart';
/// @docImport 'package:snaptest/src/test_devices_variant.dart';
/// @docImport 'package:snaptest/src/video/ffmpeg_encoder.dart';
/// @docImport 'package:snaptest/src/video/pointer_overlay.dart';
/// @docImport 'package:snaptest/src/video/snap_recording.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:snaptest/src/constants.dart';
import 'package:snaptest/src/video/video_frame.dart';

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
  /// post-frame callbacks, physics, and [WidgetTester.pumpAndSettle] iteration
  /// counts may all behave differently. The total fake-clock advancement per
  /// pump stays identical to the requested duration.
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

  /// VP9 in a WebM container (`libvpx-vp9`, `yuva420p`).
  ///
  /// Unlike H.264 this keeps the alpha channel, so recordings can be
  /// transparent — combine with a transparent
  /// [SnapVideoSettings.backgroundColor]. [crf] controls quality (lower is
  /// better; sane range 0-63, default 32).
  const factory VideoEncoding.vp9({int crf}) = _Vp9Encoding;

  /// The file extension for the encoded container, including the dot.
  String get fileExtension;

  /// FFmpeg arguments selecting the codec, quality and container.
  List<String> get ffmpegCodecArguments;

  /// The FFmpeg encoder name to validate, e.g. `libx264`.
  String get ffmpegEncoderName;

  /// Whether this profile preserves the alpha channel.
  ///
  /// When `true`, a transparent background stays transparent in the output;
  /// when `false`, transparency renders as black unless a
  /// [SnapVideoSettings.backgroundColor] is composited first.
  bool get supportsAlpha;
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
  bool get supportsAlpha => false;

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

class _Vp9Encoding extends VideoEncoding {
  const _Vp9Encoding({this.crf = 32}) : super._();

  /// Constant-rate-factor quality for libvpx-vp9 (0-63, lower is better).
  final int crf;

  @override
  String get fileExtension => '.webm';

  @override
  String get ffmpegEncoderName => 'libvpx-vp9';

  @override
  bool get supportsAlpha => true;

  @override
  List<String> get ffmpegCodecArguments => [
    '-c:v',
    'libvpx-vp9',
    '-crf',
    '$crf',
    '-b:v',
    '0',
    '-pix_fmt',
    'yuva420p',
    // Alpha output requires alternate reference frames off.
    '-auto-alt-ref',
    '0',
    '-f',
    'webm',
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
/// The defaults produce a 60 fps, observed-timing, H.264 MP4 with an opaque
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
    this.frameRate = 60,
    this.timing = VideoTiming.observed,
    this.encoding = const VideoEncoding.h264(),
    this.includeDeviceFrame = false,
    this.renderShadows = false,
    this.minimumPointerDuration = Duration.zero,
    this.overlay,
    this.backgroundColor,
    this.pathPrefix = kDefaultPathPrefix,
    this.finalHold = Duration.zero,
    this.ffmpegPath,
    this.maxSimulatedDuration = const Duration(minutes: 1),
    this.maxCapturedFrames = 20000,
    this.maxSpoolBytes = 1 << 30,
    this.encoderTimeout = const Duration(minutes: 2),
    this.onFailure = VideoFailurePolicy.fail,
  }) : assert(frameRate > 0, 'frameRate must be positive'),
       assert(maxCapturedFrames > 0, 'maxCapturedFrames must be positive'),
       assert(maxSpoolBytes > 0, 'maxSpoolBytes must be positive');

  /// Output frames per second, sampled onto a constant-frame-rate grid.
  ///
  /// Defaults to 60. The grid is anchored to the first captured frame, so
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

  /// Paint real shadows and Material elevation instead of flat test shadows.
  ///
  /// Defaults to false, preserving Flutter's test rendering. The observing
  /// binding enables shadows for the recording and restores its previous
  /// state on stop, truncation, or teardown. An already-painted scene is
  /// repainted without pumping or advancing the test clock.
  final bool renderShadows;

  /// Minimum simulated time to show a pointer, measured from pointer-down.
  ///
  /// After pointer-up a pointer stays in [SnapVideoFrame.pointers] as
  /// [SnapPointerPhase.released] until this much time has passed since its
  /// pointer-down. Defaults to zero, which drops it on release. For demos,
  /// e.g. `Duration(milliseconds: 100)` also shows taps between pumps and
  /// gives overlays a released phase to animate. Cancellation removes a
  /// pointer immediately.
  ///
  /// This changes only the overlay: it never pumps, advances the test clock,
  /// or extends the recording. A tap near the end may be cut short; use
  /// [finalHold] explicitly if it should remain visible after stopping.
  final Duration minimumPointerDuration;

  /// A widget drawn over every captured frame, or `null` for none.
  ///
  /// Called with a [SnapVideoFrame] each time the recording captures a
  /// frame. The overlay is one widget tree that lives for the whole
  /// recording, so it can hold state: key per-pointer widgets by
  /// [SnapPointer.id] to animate presses, follow positions and fade out
  /// released pointers. Pointers are only tracked while an overlay is set.
  ///
  /// To show where pointers are, like a screen recorder's "show touches",
  /// pass the built-in [SnapPointerOverlay.builder]:
  ///
  /// ```dart
  /// SnapVideoSettings(overlay: SnapPointerOverlay.builder)
  /// ```
  ///
  /// The overlay never joins your app's widget tree. It is built, laid out
  /// and painted in a separate tree with its own [BuildOwner] and
  /// [PipelineOwner], sized to the recorded view at the same device pixel
  /// ratio, and its image is composited over each captured frame. Your
  /// app's layout, hit testing, semantics and painted frames stay exactly
  /// as without an overlay. The overlay covers the whole view in view
  /// coordinates, so with a `from` finder or a `crop` you see the part over
  /// the captured region. With [includeDeviceFrame] it is drawn over the app
  /// and clipped to the device's screen, under the bezel; [backgroundColor]
  /// stays behind everything.
  ///
  /// **Keep overlay animations finite.** The overlay's animations run on the
  /// test's clock: they advance only when the test pumps, and an active
  /// animation schedules frames just like one in your app. A repeating or
  /// never-ending animation in the overlay keeps [WidgetTester.pumpAndSettle]
  /// from ever settling while the recording runs. The overlay is disposed when
  /// the recording stops, which stops its animations.
  ///
  /// Combine it with your own widgets in a custom overlay:
  ///
  /// ```dart
  /// SnapVideoSettings(
  ///   minimumPointerDuration: const Duration(milliseconds: 300),
  ///   overlay: (context, frame) => Stack(
  ///     children: [
  ///       SnapPointerOverlay(pointers: frame.pointers),
  ///       Positioned(
  ///         right: 8,
  ///         bottom: 8,
  ///         child: Text('${frame.elapsed.inMilliseconds} ms'),
  ///       ),
  ///     ],
  ///   ),
  /// )
  /// ```
  final SnapVideoOverlayBuilder? overlay;

  /// The background composited behind every frame.
  ///
  /// `null` (the default) resolves automatically: transparent for encodings
  /// where [VideoEncoding.supportsAlpha] is true (e.g. [VideoEncoding.vp9]),
  /// opaque white otherwise — H.264's `yuv420p` has no alpha channel, so
  /// transparency would otherwise render as black artifacts. Alpha
  /// compositing happens at capture time.
  final Color? backgroundColor;

  /// Directory path prefix where the video is saved.
  ///
  /// Defaults to `.snaptest/`, relative to the test file's directory (as
  /// resolved by [LocalFileComparator]). Use `''` to save beside the test,
  /// e.g. when the script already lives inside `.snaptest/`. Relative paths
  /// such as `../recordings` and absolute filesystem paths are also supported.
  /// No trailing slash is required.
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
  /// [WidgetTester.pumpAndSettle] loops filling the disk. Defaults to 1 minute.
  final Duration maxSimulatedDuration;

  /// Maximum number of captured timestamps kept in the recording.
  ///
  /// Exceeding this freezes capture and marks the artifact truncated.
  final int maxCapturedFrames;

  /// Maximum observed size of the temporary encoded video, in bytes.
  ///
  /// Frames are streamed directly to FFmpeg; there is no PNG spool. The
  /// legacy name is retained for compatibility. Exceeding this freezes
  /// capture and marks the artifact truncated. Checked after captures and
  /// finalization; encoder buffering may delay detection. Defaults to 1 GiB.
  final int maxSpoolBytes;

  /// Wall-clock timeout for a frame batch or encoder finalization.
  ///
  /// Encoding overlaps capture. This bounds stalled writes and finalization,
  /// not the total recording or simulated duration. Defaults to 2 minutes.
  final Duration encoderTimeout;

  /// Whether capture or encoding failures throw or only warn.
  final VideoFailurePolicy onFailure;
}
