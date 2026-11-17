import 'dart:async';

import 'package:coil/src/foundation/haptics.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/drawn_glyph.dart';
import 'package:coil/src/primitives/presence.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// What a copy affordance shows.
enum CoilCopyStatus {
  /// At rest: the copy icon.
  idle,

  /// The last copy landed: a check.
  copied,

  /// The clipboard refused the last copy: an ×.
  failed,
}

/// Copies text and holds the result for [resetDelay], the one state
/// machine behind every copy affordance in coil.
///
/// - [copy] from idle shows [CoilCopyStatus.copied] and starts the timer.
/// - [copy] while the result shows keeps it (nothing animates again) and
///   only restarts the timer, however fast the taps come.
/// - When the timer ends, the status falls back to idle.
/// - [copy] while the result is still leaving brings it back; a
///   [CoilCopySwitcher] turns the leaving result around from where it is.
///
/// Pass `context` to [copy] for the feedback: screen readers hear
/// "Copied" (or "Copy failed") when the result appears, and a successful
/// copy plays [CoilHapticEvent.copy].
class CoilCopyController extends ValueNotifier<CoilCopyStatus> {
  /// Creates a controller at rest.
  CoilCopyController({this.resetDelay = defaultResetDelay})
    : super(CoilCopyStatus.idle);

  /// How long a result shows by default, as DESIGN.md names it.
  static const defaultResetDelay = Duration(seconds: 2);

  /// How long a result shows after the last copy.
  final Duration resetDelay;

  Timer? _reset;
  var _disposed = false;

  /// Copies [text] and shows the result. Returns the result.
  ///
  /// With [context], announces [copiedLabel] or [failedLabel] when the
  /// shown result changes, and plays the copy haptic on every success.
  Future<CoilCopyStatus> copy(
    String text, {
    BuildContext? context,
    String copiedLabel = 'Copied',
    String failedLabel = 'Copy failed',
  }) async {
    var status = CoilCopyStatus.copied;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on PlatformException {
      status = CoilCopyStatus.failed;
    }
    if (_disposed) return status;
    final changed = value != status;
    show(status);
    if (context != null && context.mounted) {
      if (changed) {
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            status == CoilCopyStatus.copied ? copiedLabel : failedLabel,
            Directionality.of(context),
          ),
        );
      }
      if (status == CoilCopyStatus.copied) {
        unawaited(CoilHaptics.play(context, CoilHapticEvent.copy));
      }
    }
    return status;
  }

  /// Shows [status] and, unless it's idle, restarts the timer back to
  /// idle. Showing the status already shown only restarts the timer.
  void show(CoilCopyStatus status) {
    _reset?.cancel();
    value = status;
    if (status == CoilCopyStatus.idle) return;
    _reset = Timer(resetDelay, () {
      if (!_disposed) value = CoilCopyStatus.idle;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _reset?.cancel();
    super.dispose();
  }
}

/// Cross-fades a copy affordance's content as its [status] changes: a
/// blur-fade at scale 0.8, in on `quick` and out on `quickExit`.
///
/// Each status is one child, keyed by the status alone, so a repeated
/// copy (same status) never replays the swap, and a result that comes back
/// while it is still leaving turns around from its current presence,
/// keeping its state (a check stays drawn).
class CoilCopySwitcher extends StatelessWidget {
  /// Creates a copy switcher.
  const CoilCopySwitcher({
    required this.status,
    required this.builder,
    super.key,
    this.motion,
    this.exitMotion,
  });

  /// The status to show.
  final CoilCopyStatus status;

  /// Builds the content for one status.
  final Widget Function(BuildContext context, CoilCopyStatus status) builder;

  /// The entering content's spring. Defaults to the theme's `quick`.
  final Motion? motion;

  /// The leaving content's spring. Defaults to the theme's `quickExit`.
  final Motion? exitMotion;

  @override
  Widget build(BuildContext context) {
    final tokens = CoilTheme.motionOf(context);
    return MotionSwitcher(
      motion: motion ?? tokens.quick,
      exitMotion: exitMotion ?? tokens.quickExit,
      transitionBuilder: CoilBlurFade.transition(scale: 0.8),
      debugLabel: 'CoilCopySwitcher',
      child: KeyedSubtree(
        key: ValueKey(status),
        child: builder(context, status),
      ),
    );
  }
}

/// The glyph of a copy affordance for one [status]: the copy [icon] at
/// rest (a drawn [CoilGlyph.copy] by default, so there is always a visible
/// button), a check that draws itself in after a copy, an × after a
/// refused one. Use it as a [CoilCopySwitcher]'s content, or use
/// [CoilCopyGlyph.listening] for an icon that follows a controller.
class CoilCopyGlyph extends StatelessWidget {
  /// Creates the glyph for [status].
  const CoilCopyGlyph({
    required this.status,
    super.key,
    this.icon,
    this.drawMotion,
  });

  /// The status to show.
  final CoilCopyStatus status;

  /// The copy icon at rest. Null draws [CoilGlyph.copy].
  final Widget? icon;

  /// How the check or × draws in. Defaults to the theme's `fade`.
  final Motion? drawMotion;

  /// A copy icon that follows [controller], cross-fading between its
  /// statuses with a [CoilCopySwitcher]: for an icon button that copies,
  /// such as a chat message's Copy action.
  static Widget listening({
    required CoilCopyController controller,
    Key? key,
    Widget? icon,
    Motion? motion,
    Motion? exitMotion,
    Motion? drawMotion,
  }) => ValueListenableBuilder<CoilCopyStatus>(
    key: key,
    valueListenable: controller,
    builder: (context, status, _) => CoilCopySwitcher(
      status: status,
      motion: motion,
      exitMotion: exitMotion,
      builder: (context, status) =>
          CoilCopyGlyph(status: status, icon: icon, drawMotion: drawMotion),
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget drawn(CoilGlyph glyph) => SingleMotionBuilder(
      value: 1,
      from: 0,
      motion: drawMotion ?? CoilTheme.motionOf(context).fade,
      builder: (context, progress, _) =>
          CoilDrawnGlyph(glyph, progress: progress),
    );
    return switch (status) {
      CoilCopyStatus.idle => icon ?? const CoilDrawnGlyph(CoilGlyph.copy),
      CoilCopyStatus.copied => drawn(CoilGlyph.check),
      CoilCopyStatus.failed => drawn(CoilGlyph.cross),
    };
  }
}
