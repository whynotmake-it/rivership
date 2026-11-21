import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/presence.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// A box that cross-fades its content and springs to its size: coil's
/// [MotionSizeSwitcher] with `immediateResize` and coil's tokens.
///
/// [child] is swapped when its key (or type) changes, the old content
/// blur-fades out where it is while the new one fades in, and the box springs
/// from the old content's size to the new one's.
///
/// The size follows the *new* content at once, so a shorter label starts to
/// shrink as it arrives instead of waiting for the old one to leave. The
/// leaving content keeps the constraints it had, is unreachable for focus,
/// taps and screen readers while it leaves, and is clipped by the box.
///
/// The box springs when its content changes and snaps when its room does
/// (the window resizes and rewraps the content, the text scale changes). New
/// content that makes the box wider stays nearly transparent until the width
/// has arrived, so no half-drawn glyph shows; see [MotionSizeSwitcher].
///
/// A [child] that changes without a new key (a `Text` whose string changed)
/// is the same content: the box springs to its size, with no cross-fade.
/// Key it by what it shows to cross-fade.
class CoilSizeSwitcher extends StatefulWidget {
  /// Creates a size switcher.
  const CoilSizeSwitcher({
    required this.child,
    super.key,
    this.alignment = AlignmentDirectional.topStart,
    this.clipBehavior = Clip.hardEdge,
    this.sizeMotion,
    this.fadeMotion,
    this.fadeExitMotion,
    this.motion,
    this.blur = CoilBlurFade.defaultBlur / 2,
    this.contentKey,
    this.debugLabel,
  });

  /// What [child] shows, when it can't carry a key of its own: a `Text`
  /// (see [contentKeyOf]) or a widget whose key you don't control, such as
  /// one a caller passed in.
  static Object? contentKeyOf(Widget? child) => switch (child) {
    Text(key: null, :final data?) => data,
    Text(key: null, :final textSpan?) => textSpan.toPlainText(),
    _ => null,
  };

  /// The content. Give it a key that names what it shows.
  final Widget? child;

  /// Names what [child] shows: content with another name cross-fades. Null
  /// uses [contentKeyOf] of the child, so a `Text` cross-fades when its
  /// string changes and any other widget by its own key.
  final Object? contentKey;

  /// Where the content sits while the box is another size.
  final AlignmentGeometry alignment;

  /// How the content is clipped while it overflows the box.
  final Clip clipBehavior;

  /// The size's motion. Defaults to `standard`; the same motion shrinking
  /// and growing, since the box keeps its velocity either way.
  final Motion? sizeMotion;

  /// The entering content's motion. Defaults to `fade`.
  final Motion? fadeMotion;

  /// The leaving content's motion. Defaults to `fadeExit`.
  final Motion? fadeExitMotion;

  /// Overrides the theme's motion tokens for the defaults.
  final CoilMotion? motion;

  /// The blur at presence 0.
  final double blur;

  /// A name for motor_devtools.
  final String? debugLabel;

  @override
  State<CoilSizeSwitcher> createState() => _CoilSizeSwitcherState();
}

class _CoilSizeSwitcherState extends State<CoilSizeSwitcher> {
  /// Replaced only when the blur changes, so the switcher doesn't rebuild
  /// its transitions on every build.
  late AnimatedSwitcherTransitionBuilder _transition = _buildTransition;

  Widget _buildTransition(Widget child, Animation<double> presence) =>
      CoilBlurFade(
        presence: presence,
        scale: 1,
        blur: widget.blur,
        child: child,
      );

  @override
  void didUpdateWidget(CoilSizeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blur != oldWidget.blur) {
      _transition = _buildTransition;
    }
  }

  @override
  Widget build(BuildContext context) {
    final CoilSizeSwitcher(
      :child,
      :contentKey,
      :alignment,
      :clipBehavior,
      :debugLabel,
    ) = widget;
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    return MotionSizeSwitcher(
      motion: widget.fadeMotion ?? tokens.fade,
      exitMotion: widget.fadeExitMotion ?? tokens.fadeExit,
      sizeMotion: widget.sizeMotion ?? tokens.standard,
      alignment: alignment,
      clipBehavior: clipBehavior,
      immediateResize: true,
      transitionBuilder: _transition,
      debugLabel: debugLabel ?? 'CoilSizeSwitcher',
      child: switch ((
        child,
        contentKey ?? CoilSizeSwitcher.contentKeyOf(child),
      )) {
        (final child?, final name?) => KeyedSubtree(
          key: ValueKey<Object>(name),
          child: child,
        ),
        (final child, _) => child,
      },
    );
  }
}
