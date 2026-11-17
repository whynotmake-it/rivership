import 'dart:async';

import 'package:coil/src/foundation/haptics.dart';
import 'package:coil/src/foundation/motion.dart';
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

  /// Copies [text] and shows the result. Returns the result: any failure
  /// to set the clipboard (not only a `PlatformException`) shows and
  /// returns [CoilCopyStatus.failed].
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
    } catch (_) {
      // Any failure is a refused copy: a platform error, a missing plugin,
      // or what a browser throws when the page lacks permission.
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

/// The animated parts of a copy affordance. Use them as keys of
/// [CoilCopySwitcher.motions] and [CoilCopyGlyph.motions].
final class CoilCopyTrack<T extends Object> extends Track<T> {
  CoilCopyTrack._(super.converter, {required String super.debugLabel});

  /// The swap between the copy icon and the result. Default motion:
  /// `quick` in, `quickExit` out; an override applies to both.
  static final swap = CoilCopyTrack<double>._(
    .single,
    debugLabel: 'CoilCopy.swap',
  );

  /// The check or × drawing itself in. Default motion: `fade`.
  static final draw = CoilCopyTrack<double>._(
    .single,
    debugLabel: 'CoilCopy.draw',
  );
}

/// Cross-fades a copy affordance's content as its [status] changes: a
/// blur-fade at scale 0.8 on [CoilCopyTrack.swap].
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
    this.motions,
  });

  /// The status to show.
  final CoilCopyStatus status;

  /// Builds the content for one status.
  final Widget Function(BuildContext context, CoilCopyStatus status) builder;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilCopyTrack]s; this widget reads
  /// [CoilCopyTrack.swap]. They win over the tokens; reduced motion still
  /// makes them instant.
  final Map<CoilCopyTrack<Object>, Motion>? motions;

  @override
  Widget build(BuildContext context) {
    final tokens = CoilTheme.motionOf(context, override: motion);
    Motion swap(Motion token) => CoilTheme.trackMotionOf(
      context,
      CoilCopyTrack.swap,
      instance: motions,
      styled: null,
      token: token,
    );
    return MotionSwitcher(
      motion: swap(tokens.quick),
      exitMotion: swap(tokens.quickExit),
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
    required CoilCopyStatus this.status,
    super.key,
    this.icon,
    this.motion,
    this.motions,
  }) : controller = null;

  /// A copy icon that follows [controller], cross-fading between its
  /// statuses with a [CoilCopySwitcher]: for an icon button that copies,
  /// such as a chat message's Copy action.
  const CoilCopyGlyph.listening({
    required CoilCopyController this.controller,
    super.key,
    this.icon,
    this.motion,
    this.motions,
  }) : status = null;

  /// The status to show; null when it follows [controller].
  final CoilCopyStatus? status;

  /// The controller whose status it follows, for
  /// [CoilCopyGlyph.listening].
  final CoilCopyController? controller;

  /// The copy icon at rest. Null draws [CoilGlyph.copy].
  final Widget? icon;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilCopyTrack]s: [CoilCopyTrack.draw]
  /// for the check or ×, and [CoilCopyTrack.swap] for
  /// [CoilCopyGlyph.listening]'s cross-fade.
  final Map<CoilCopyTrack<Object>, Motion>? motions;

  @override
  Widget build(BuildContext context) {
    if (controller case final controller?) {
      return ValueListenableBuilder<CoilCopyStatus>(
        valueListenable: controller,
        builder: (context, status, _) => CoilCopySwitcher(
          status: status,
          motion: motion,
          motions: motions,
          builder: (context, status) => CoilCopyGlyph(
            status: status,
            icon: icon,
            motion: motion,
            motions: motions,
          ),
        ),
      );
    }
    Widget drawn(CoilGlyph glyph) => SingleMotionBuilder(
      value: 1,
      from: 0,
      motion: CoilTheme.trackMotionOf(
        context,
        CoilCopyTrack.draw,
        instance: motions,
        styled: null,
        token: CoilTheme.motionOf(context, override: motion).fade,
        // The check draws in on `fade`, which survives reduced motion.
        spatial: false,
      ),
      builder: (context, progress, _) =>
          CoilDrawnGlyph(glyph, progress: progress),
    );
    return switch (status!) {
      CoilCopyStatus.idle => icon ?? const CoilDrawnGlyph(CoilGlyph.copy),
      CoilCopyStatus.copied => drawn(CoilGlyph.check),
      CoilCopyStatus.failed => drawn(CoilGlyph.cross),
    };
  }
}
