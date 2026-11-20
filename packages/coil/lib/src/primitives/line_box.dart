import 'package:flutter/widgets.dart';

/// A box exactly one line of [style] tall, with [child] centered in it.
///
/// Use it to put an icon on the first line of text that may wrap: a
/// textarea's slots, a field error's alert glyph. The text engine lays out an
/// empty line with the ambient text scaler and a forced strut, so the box
/// matches the text's real line height without any arithmetic.
class CoilLineBox extends StatelessWidget {
  /// Creates a line box.
  const CoilLineBox({required this.style, required this.child, super.key});

  /// The text style whose line the box matches.
  final TextStyle style;

  /// What to center in the line.
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      ExcludeSemantics(
        child: Text(
          '',
          style: style,
          strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
        ),
      ),
      child,
    ],
  );
}
