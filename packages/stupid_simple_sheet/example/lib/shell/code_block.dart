import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

/// The snippet that opened a sheet, on coil's muted fill, with a button
/// that copies it.
///
/// coil has no monospace role, so the caption role takes a monospace
/// family with the platforms' families behind it, and tabular figures so
/// numbers line up. Lines never wrap: a long line scrolls sideways.
/// Comments are muted, the code is in the foreground; nothing else is
/// colored, so the snippet reads the same in both themes.
class CodeBlock extends StatefulWidget {
  /// Creates a code block showing [code].
  const CodeBlock({required this.code, super.key});

  /// The snippet, as it is shown and as it is copied.
  final String code;

  /// The families tried for the snippet, in order, when the platform has
  /// no font under the generic `monospace` name.
  static const fontFamilyFallback = [
    'Menlo',
    'SF Mono',
    'Consolas',
    'DejaVu Sans Mono',
    'Roboto Mono',
  ];

  /// The snippet's style at [context].
  static TextStyle styleOf(BuildContext context) => CoilTheme.textOf(context)
      .caption
      .copyWith(
        fontFamily: 'monospace',
        fontFamilyFallback: fontFamilyFallback,
      )
      .tabular;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  final _copy = CoilCopyController();

  @override
  void dispose() {
    _copy.dispose();
    super.dispose();
  }

  /// Where a line's trailing comment starts, or null when it has none.
  static int? _commentStart(String line) {
    var quoted = false;
    for (var i = 0; i < line.length - 1; i++) {
      if (line[i] == "'") {
        quoted = !quoted;
      } else if (!quoted && line[i] == '/' && line[i + 1] == '/') {
        return i;
      }
    }
    return null;
  }

  /// The snippet with its comments in [mutedForeground].
  InlineSpan _spans(TextStyle style, Color mutedForeground) {
    final comment = style.copyWith(color: mutedForeground);
    final spans = <InlineSpan>[];
    for (final (index, line) in widget.code.split('\n').indexed) {
      if (index > 0) spans.add(const TextSpan(text: '\n'));
      final start = _commentStart(line);
      if (start == null) {
        spans.add(TextSpan(text: line));
        continue;
      }
      if (start > 0) spans.add(TextSpan(text: line.substring(0, start)));
      spans.add(TextSpan(text: line.substring(start), style: comment));
    }
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radii = CoilTheme.radiiOf(context);
    final style = CodeBlock.styleOf(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.muted,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radii.item),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text.rich(
                  _spans(style, colors.mutedForeground),
                  style: style,
                  softWrap: false,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CoilButton.icon(
              variant: CoilButtonVariant.ghost,
              size: CoilSize.compact,
              semanticLabel: 'Copy code',
              icon: CoilCopyGlyph.listening(controller: _copy),
              onPressed: () =>
                  _copy.copy(widget.code, context: context).ignore(),
            ),
          ],
        ),
      ),
    );
  }
}
