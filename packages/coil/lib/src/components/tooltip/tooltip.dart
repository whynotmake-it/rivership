import 'package:coil/foundation.dart';
import 'package:coil/kbd.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// A short label that appears next to [child]: an inverted bubble that
/// names an icon-only control.
///
/// A mouse opens it after a short hover, keyboard focus at once, and an
/// Android long-press while the finger stays down; iOS shows none. See
/// [CoilTooltipAnchor] for the timing. Don't put required information in a
/// tooltip, and don't tooltip a labelled button.
///
/// ```dart
/// CoilTooltip(
///   message: const Text('Bold'),
///   child: CoilButton.icon(onPressed: bold, icon: boldIcon),
/// )
/// ```
class CoilTooltip extends StatelessWidget {
  /// Creates a tooltip for [child].
  ///
  /// [semanticLabel] is required unless [message] is a [Text] or
  /// [RichText], whose text screen readers then announce.
  const CoilTooltip({
    required this.message,
    required this.child,
    super.key,
    this.semanticLabel,
    this.shortcut,
    this.motion,
  }) : assert(
         semanticLabel != null || message is Text || message is RichText,
         'Give a semanticLabel for a message that is not a Text.',
       );

  /// What the bubble shows, usually a [Text]. It's styled as the bubble's
  /// caption through [DefaultTextStyle] and [IconTheme], and may span
  /// several lines.
  ///
  /// The bubble crossfades to a new message when its key or type changes,
  /// and in a [CoilTooltipGroup] when it moves to another tooltip. Otherwise
  /// it updates in place.
  final Widget message;

  /// What screen readers announce as the tooltip. Defaults to the text of
  /// [message] when that is a [Text] or [RichText].
  final String? semanticLabel;

  /// A keyboard shortcut drawn after [message], usually a key cap. It
  /// gets the bubble's inverted colors through [DefaultTextStyle] and
  /// [IconTheme], 8 px from the message and centered on it.
  ///
  /// Screen readers don't hear it unless [semanticLabel] says it.
  final Widget? shortcut;

  /// What the tooltip is for.
  final Widget child;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  String get _semanticLabel =>
      semanticLabel ??
      switch (message) {
        Text(:final data?) => data,
        Text(:final textSpan?) => textSpan.toPlainText(),
        RichText(:final text) => text.toPlainText(),
        _ => '',
      };

  /// The message with the shortcut after it. Keyed by the message's key,
  /// so the bubble crossfades when that changes, as for a bare message.
  Widget get _content => switch (shortcut) {
    null => message,
    final shortcut => Row(
      key: ValueKey(message.key),
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Flexible(child: message),
        // A 16 cap fits the caption line, so the bubble stays 24 tall.
        CoilTheme.override(
          transform: (theme) =>
              theme.withComponentStyle(const CoilKbdStyle(size: 16)),
          child: shortcut,
        ),
      ],
    ),
  };

  @override
  Widget build(BuildContext context) => CoilTooltipAnchor(
    content: _content,
    semanticLabel: _semanticLabel,
    motion: motion,
    bubble: (context, presence, content) =>
        _Bubble(presence: presence, content: content, motion: motion),
    child: child,
  );
}

/// Gives the [CoilTooltip]s in [child] one shared bubble, for a toolbar
/// of icon buttons: moving along it, the bubble glides to the next button
/// on the theme's `quick` spring, its size follows, and its content
/// crossfades.
class CoilTooltipGroup extends StatelessWidget {
  /// Creates a tooltip group around [child].
  const CoilTooltipGroup({required this.child, super.key, this.motion});

  /// The area holding the tooltips.
  final Widget child;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  Widget build(BuildContext context) => CoilTooltipAnchorGroup(
    motion: motion,
    bubble: (context, presence, content) =>
        _Bubble(presence: presence, content: content, motion: motion),
    child: child,
  );
}

/// The inverted bubble: foreground fill, caption text in the background
/// color.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.presence,
    required this.content,
    required this.motion,
  });

  final Animation<double> presence;
  final Widget content;
  final CoilMotion? motion;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, tier: CoilTier.pointer);
    final motion = CoilTheme.motionOf(context, override: this.motion);
    return CoilBlurFade(
      presence: presence,
      scale: 1,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: theme.colors.foreground,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(
              CoilTheme.radiiOf(context).item,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: DefaultTextStyle(
            style: theme.typography.style(
              metrics.caption,
              color: theme.colors.background,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: theme.colors.background),
              // When the content changes, the size follows the new content
              // on `quick` at once while the two crossfade on `fade`. The
              // old content keeps its layout as it fades.
              child: MotionSizeSwitcher(
                motion: motion.fade,
                exitMotion: motion.fadeExit,
                sizeMotion: motion.quick,
                immediateResize: true,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
