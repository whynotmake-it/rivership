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
    this.overflow,
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

  /// How the text should be aligned horizontally.
  final TextAlign? textAlign;

  /// An optional maximum number of lines for the text to span, wrapping if
  /// necessary.
  /// If the text exceeds the given number of lines, it will be truncated
  /// according to [overflow].
  ///
  /// If this is 1, text will not wrap. Otherwise, text will be wrapped at the
  /// edge of the box.
  ///
  /// If this is null, but there is an ambient [DefaultTextStyle] that specifies
  /// an explicit number for its [DefaultTextStyle.maxLines], then the
  /// [DefaultTextStyle] value will take precedence. You can use a [RichText]
  /// widget directly to entirely override the [DefaultTextStyle].
  final int? maxLines;

  /// How visual overflow should be handled.
  ///
  /// If this is null [TextStyle.overflow] will be used, otherwise the value
  /// from the nearest [DefaultTextStyle] ancestor will be used.
  final bool? softWrap;

  /// How visual overflow should be handled.
  ///
  /// If this is null [TextStyle.overflow] will be used, otherwise the value
  /// from the nearest [DefaultTextStyle] ancestor will be used.
  final TextOverflow? overflow;

  /// How to transition changes to [text].
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: duration,
      style: style ?? DefaultTextStyle.of(context).style,
      textAlign: textAlign,
      maxLines: maxLines,
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
            softWrap: softWrap,
            overflow: overflow,
          ),
        ),
      ),
    );
  }
}
