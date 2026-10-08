/// A test binding that can observe pumps for [SnapRecording].
///
/// Everything in this file is package-internal except the binding itself,
/// which users install once in `flutter_test_config.dart`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/src/video/ffmpeg_encoder.dart';
import 'package:snaptest/src/video/snap_recording.dart';

/// A thin subclass of [AutomatedTestWidgetsFlutterBinding] that lets
/// [SnapRecording] observe — and optionally subdivide — the pumps a widget
/// test already performs.
///
/// Install it once, before anything else that might initialize the binding
/// (font loading, `testWidgets`, other test setup), in
/// `flutter_test_config.dart`:
///
/// ```dart
/// Future<void> testExecutable(FutureOr<void> Function() testMain) async {
///   SnaptestWidgetsFlutterBinding.ensureInitialized();
///   await loadFonts();
///   await testMain();
/// }
/// ```
///
/// The binding is **inert** unless a recording is active: with no active
/// session, [pump] delegates to the superclass unchanged, no capture
/// callback, timer, process, or file I/O runs, and frame scheduling is
/// untouched. Screenshots and ordinary tests do not acquire any FFmpeg or
/// recording dependency.
class SnaptestWidgetsFlutterBinding
    extends AutomatedTestWidgetsFlutterBinding {
  /// Initializes the test binding.
  ///
  /// Usually called via [ensureInitialized].
  SnaptestWidgetsFlutterBinding();

  /// The recording currently observing this binding, if any.
  ///
  /// Set by [SnapRecording.start] and cleared when the recording freezes.
  @internal
  SnapRecording? activeRecording;

  /// Number of frames drawn since the binding was created.
  ///
  /// [SnapRecording] compares this before and after a pump to know whether a
  /// paint actually occurred, without scheduling a new frame.
  @internal
  int drawnFrameCount = 0;

  @override
  void handleDrawFrame() {
    drawnFrameCount++;
    super.handleDrawFrame();
  }

  /// The unchanged [AutomatedTestWidgetsFlutterBinding.pump].
  ///
  /// [SnapRecording] drives this to run the real pump once per observed step
  /// without re-entering the recording wrapper.
  @internal
  Future<void> pumpOnce(Duration? duration, EnginePhase phase) =>
      super.pump(duration, phase);

  @override
  Future<void> pump([
    Duration? duration,
    EnginePhase newPhase = EnginePhase.sendSemanticsUpdate,
  ]) {
    final recording = activeRecording;
    if (recording == null || !recording.isCapturing) {
      return super.pump(duration, newPhase);
    }
    // Keep Flutter's async-guard semantics for the recording path too.
    return TestAsyncUtils.guard<void>(
      () => recording.pumpForRecording(this, duration, newPhase),
    );
  }

  @override
  Future<void> runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester, {
    String description = '',
  }) {
    return super.runTest(() async {
      try {
        await testBody();
      } finally {
        // Freeze capture before Flutter replaces the widget tree and pumps
        // its cleanup frame. Finalization is awaited separately through the
        // recording's own addTearDown callback.
        activeRecording?.freeze();
      }
    }, invariantTester, description: description);
  }

  @override
  void postTest() {
    // Defensive synchronous reset only: detach a session that leaked past a
    // timed-out or uncaught failure. Encoding is never triggered here.
    activeRecording?.freeze();
    activeRecording = null;
    super.postTest();
  }

  /// Returns the installed [SnaptestWidgetsFlutterBinding], creating it if
  /// no binding exists yet.
  ///
  /// Throws a [SnapVideoException] if a different binding is already
  /// installed — the default, live, integration-test, or another custom
  /// binding is never silently replaced.
  static SnaptestWidgetsFlutterBinding ensureInitialized() {
    WidgetsBinding? existing;
    if (kDebugMode) {
      // In debug builds the binding type is tracked, so an existing binding
      // can be detected without calling another class's ensureInitialized(),
      // which would eagerly construct the wrong binding.
      if (BindingBase.debugBindingType() != null) {
        existing = WidgetsBinding.instance;
      }
    } else {
      // Release builds do not track the type; probe the getter instead.
      // Recording is only meaningful in widget tests, which always run with
      // asserts enabled, so this path is best-effort.
      try {
        existing = WidgetsBinding.instance;
      } on Object {
        existing = null;
      }
    }
    if (existing == null) {
      return SnaptestWidgetsFlutterBinding();
    }
    if (existing is SnaptestWidgetsFlutterBinding) {
      return existing;
    }
    throw SnapVideoException(
      'Cannot install SnaptestWidgetsFlutterBinding: the test binding is '
      'already initialized as ${existing.runtimeType}.\n'
      'Call SnaptestWidgetsFlutterBinding.ensureInitialized() earlier — for '
      'example at the top of testExecutable in flutter_test_config.dart, '
      'before loadFonts(), testWidgets, or any other binding use.',
    );
  }
}
