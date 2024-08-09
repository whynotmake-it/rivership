import 'package:flutter/material.dart';

/// {@template rivership.AnimatedSizeSwitcher}
/// A widget that switches it's child out with a nice animation and also
/// animates it's size with sensible default values.
///
/// If [child] is null, this widget takes up as little space as possible.
/// This widget picks up on changes to [child] the same way, [AnimatedSwitcher]
/// does.
/// {@endtemplate}
class AnimatedSizeSwitcher extends StatelessWidget {
  /// {@macro rivership.AnimatedSizeSwitcher}
  const AnimatedSizeSwitcher({
    required this.child,
    super.key,
    this.alignment = Alignment.center,
    this.curve = Easing.standard,
    this.duration = Durations.short4,
    this.clipBehavior = Clip.hardEdge,
    AnimatedSwitcherTransitionBuilder? transitionBuilder,
    this.immediateResize = false,
  }) : transitionBuilder =
            transitionBuilder ?? AnimatedSwitcher.defaultTransitionBuilder;

  /// The child to switch out.
  ///
  /// Will animate all changes based on `runtimeType`, and if that is the same,
  /// the widget's key will be used if the type is the same.
  ///
  /// If you pass null, this widget will take up as little space as possible.
  final Widget? child;

  /// The alignment of the child.
  ///
  /// Defaults to [Alignment.center].
  final Alignment alignment;

  /// The curve of the animation.
  ///
  /// Defaults to [Easing.standard].
  final Curve curve;

  /// The duration of the animation.
  ///
  /// Defaults to [Durations.short4].
  final Duration duration;

  /// The clip behavior of the animation.
  final Clip clipBehavior;

  /// The transition builder of the animation.
  final AnimatedSwitcherTransitionBuilder transitionBuilder;

  /// Whether to resize the child immediately, defaults to false.
  ///
  /// This will adjust the layout builder so that all children that are
  /// transitioning out won't have an influence on the resulting size.
  ///
  /// If this is false, this child will only animate its resize whenever all
  /// children have finished transitioning out.
  ///
  /// Setting this to true will not guarantee that children always have enough
  /// space to animate out, so overflow might occur.
  final bool immediateResize;

  @override
  Widget build(BuildContext context) {
    if (immediateResize == false) {
      return AnimatedSize(
        alignment: alignment,
        duration: duration,
        curve: curve,
        clipBehavior: clipBehavior,
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: curve,
          transitionBuilder: transitionBuilder,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            clipBehavior: clipBehavior,
            alignment: alignment,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          child: child ?? const _EmptyChild(),
        ),
      );
    } else {
      return AnimatedSwitcher(
        duration: duration,
        switchInCurve: curve,
        transitionBuilder: transitionBuilder,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          clipBehavior: clipBehavior,
          children: <Widget>[
            for (final child in previousChildren)
              Positioned.fill(
                child: Align(
                  alignment: alignment,
                  child: child,
                ),
              ),
            AnimatedSize(
              alignment: alignment,
              duration: duration,
              curve: curve,
              clipBehavior: clipBehavior,
              child: currentChild,
            ),
          ],
        ),
        child: child,
      );
    }
  }

  /// Animates it's child's transitions by using a combination of a
  /// [ScaleTransition] and a [FadeTransition].
  static AnimatedSwitcherTransitionBuilder sizeFadeTransitionBuilder =
      (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
}

/// Helper widget to use when the child is empty to make sure that the
/// `runtimeType` is always different from what the user passes.
class _EmptyChild extends StatelessWidget {
  const _EmptyChild();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
