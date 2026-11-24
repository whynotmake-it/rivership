import 'dart:async';

import 'package:coil/src/foundation/haptics.dart';
import 'package:coil/src/foundation/icons.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/drawn_glyph.dart';
import 'package:coil/src/primitives/icon_presence.dart';
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
/// machine behind every copy affordance in Coil.
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

  /// Copies [text] and shows the result.
  ///
  /// Returns the result: any failure to set the clipboard (not only a
  /// [PlatformException]) shows and returns [CoilCopyStatus.failed].
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

  /// Shows [status] and, unless it's idle, restarts the timer back to idle.
  ///
  /// Showing the status already shown only restarts the timer.
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

/// The animated parts of a copy affordance.
///
/// Use them as keys of [CoilCopySwitcher.motions] and
/// [CoilCopyGlyph.motions].
final class CoilCopyTrack<T extends Object> extends Track<T> {
  CoilCopyTrack._(super.converter, {required String super.debugLabel});

  /// The swap between the copy icon and the result: the two icons'
  /// presences crossing ([CoilIconPresence]).
  ///
  /// Default motion: `quick` in, `quickExit` out; an override applies to
  /// both. Under reduced motion the icons swap at once.
  static final swap = CoilCopyTrack<double>._(
    .single,
    debugLabel: 'CoilCopy.swap',
  );

  /// Coil's drawn check or × drawing itself in.
  ///
  /// Default motion: `fade`, which reduced motion keeps (the swap around it
  /// is instant).
  static final draw = CoilCopyTrack<double>._(
    .single,
    debugLabel: 'CoilCopy.draw',
  );
}

/// Cross-fades a copy affordance's content as its [status] changes: a
/// blur-fade at scale 0.8 on [CoilCopyTrack.swap], the contents lined up at
/// the start.
///
/// For the label of a copy button; the icon beside it is a [CoilCopyGlyph],
/// which swaps itself.
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
  /// [CoilCopyTrack.swap].
  ///
  /// They win over the tokens; reduced motion still makes them instant.
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
      // Start-aligned: "Copy" and "Copied" share their first letter, and
      // nothing jumps when the longer one is gone.
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      debugLabel: 'CoilCopySwitcher',
      child: KeyedSubtree(
        key: ValueKey(status),
        child: builder(context, status),
      ),
    );
  }
}

/// The icon of a copy affordance: the copy icon at rest, a check after a
/// copy, an × after a refused one, swapped as [status] changes.
///
/// The icons are the theme's [CoilIcons.copy], [CoilIcons.check] and
/// [CoilIcons.failed] ([icon] wins for the copy icon), else Coil's drawn
/// glyphs, so there is always a visible button. A swap is two
/// [CoilIconPresence]s crossing on [CoilCopyTrack.swap]: Coil's glyphs
/// blur-fade with it, and its check and × also draw themselves in
/// ([CoilCopyTrack.draw]); an icon that reads its presence animates
/// itself, and any other fades and scales.
///
/// Use [CoilCopyGlyph.listening] for an icon that follows a controller.
class CoilCopyGlyph extends StatelessWidget {
  /// Creates the icon for [status], swapping when it changes.
  const CoilCopyGlyph({
    required CoilCopyStatus this.status,
    super.key,
    this.icon,
    this.motion,
    this.motions,
  }) : controller = null;

  /// A copy icon that follows [controller]'s status: for an icon button
  /// that copies, such as a chat message's Copy action.
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

  /// The copy icon at rest.
  ///
  /// Null shows the theme's [CoilIcons.copy], else Coil's drawn
  /// [CoilGlyph.copy].
  final Widget? icon;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilCopyTrack]s: [CoilCopyTrack.swap]
  /// for the swap, [CoilCopyTrack.draw] for Coil's check or ×.
  final Map<CoilCopyTrack<Object>, Motion>? motions;

  @override
  Widget build(BuildContext context) {
    if (controller case final controller?) {
      return ValueListenableBuilder<CoilCopyStatus>(
        valueListenable: controller,
        builder: (context, status, _) => CoilCopyGlyph(
          status: status,
          icon: icon,
          motion: motion,
          motions: motions,
        ),
      );
    }
    final tokens = CoilTheme.motionOf(context, override: motion);
    Motion track(CoilCopyTrack<Object> track, Motion token) =>
        CoilTheme.trackMotionOf(
          context,
          track,
          instance: motions,
          styled: null,
          token: token,
        );
    // coil's check draws itself in on `fade`, which survives reduced
    // motion; only its presence (the swap) lands at once.
    final draw = CoilTheme.trackMotionOf(
      context,
      CoilCopyTrack.draw,
      instance: motions,
      styled: null,
      token: tokens.fade,
      spatial: false,
    );
    final icons = CoilTheme.of(context).icons;
    final status = this.status!;
    return CoilIconSwitcher(
      motion: track(CoilCopyTrack.swap, tokens.quick),
      exitMotion: track(CoilCopyTrack.swap, tokens.quickExit),
      // Keyed by status alone: a repeated copy changes nothing, and a
      // result that comes back while leaving turns around.
      child: KeyedSubtree(
        key: ValueKey(status),
        child: switch (status) {
          CoilCopyStatus.idle =>
            icon ?? icons.copy ?? const _SwapGlyph(CoilGlyph.copy),
          CoilCopyStatus.copied =>
            icons.check ?? _SwapGlyph(CoilGlyph.check, draw: draw),
          CoilCopyStatus.failed =>
            icons.failed ?? _SwapGlyph(CoilGlyph.cross, draw: draw),
        },
      ),
    );
  }
}

/// Coil's drawn copy, check and ×: they blur-fade at scale 0.8 with their
/// icon presence, and with [draw], draw themselves in from nothing.
class _SwapGlyph extends StatelessWidget {
  const _SwapGlyph(this.glyph, {this.draw});

  final CoilGlyph glyph;
  final Motion? draw;

  @override
  Widget build(BuildContext context) {
    final presence = CoilIconPresence.maybeOf(context);
    final draw = this.draw;
    Widget drawn = CoilDrawnGlyph(glyph);
    if (draw != null) {
      drawn = SingleMotionBuilder(
        value: 1,
        from: 0,
        motion: draw,
        builder: (context, progress, _) =>
            CoilDrawnGlyph(glyph, progress: progress),
      );
    }
    if (presence == null) return drawn;
    return CoilBlurFade(presence: presence, scale: 0.8, child: drawn);
  }
}
