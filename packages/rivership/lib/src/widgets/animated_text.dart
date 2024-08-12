import 'package:flutter/material.dart';

/// {@template rivership.AnimatedText}
/// A widget that animates the transition between different texts.
///
/// This widget is used to create a smooth transition effect when switching
/// between different texts.
/// It can be used to display dynamic text content in a visually appealing way.
/// {@endtemplate}
class AnimatedText extends StatelessWidget {
  /// {@macro rivership.AnimatedText}
  const AnimatedText(
    this.text, {
    super.key,
    this.duration = Durations.short4,
    this.curve = Easing.standard,
    this.transitionBuilder,
    this.style,
    this.textAlign,
    this.maxLines,
    this.softWrap,
    this.textOverflow,
  });

  /// The text to display.
  final String text;

  /// The duration whith which to transition.
  ///
  /// Defaults to [Durations.short4].
  final Duration duration;

  /// The curve of the animation.
  ///
  /// Defaults to [Easing.standard].
  final Curve curve;

  /// The style of the text.
  ///
  /// Defaults to `DefaultTextStyle.of(context)`
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? textOverflow;

  final AnimatedSwitcherTransitionBuilder? transitionBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: duration,
      style: style ?? DefaultTextStyle.of(context).style,
      child: AnimatedSize(
        duration: duration,
        curve: curve,
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: curve,
          switchOutCurve: curve,
          layoutBuilder: (newChild, oldChildren) => Stack(
            children: [
              ...oldChildren.map((c) => Positioned.fill(child: c)),
              if (newChild != null) newChild,
            ],
          ),
          transitionBuilder: transitionBuilder ??
              (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
          child: Text(
            text,
            key: ValueKey(text),
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            softWrap: softWrap,
            overflow: textOverflow,
          ),
        ),
      ),
    );
  }
}
