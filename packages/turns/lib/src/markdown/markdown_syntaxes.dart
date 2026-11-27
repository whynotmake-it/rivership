import 'package:markdown/markdown.dart' as md;

/// Pure-Dart LaTeX math inline syntaxes (`$$...$$` display math and `$...$`
/// inline math) that produce `<math>` AST elements.
///
/// Pass these to `parseMarkdown(source, inlineSyntaxes: latexMathSyntaxes)` or
/// any `package:markdown`-based renderer. They run before emphasis, so
/// `$a_i b_i$` parses as math rather than italics, while currency amounts such
/// as `"$5 and $10"` stay plain text.
final List<md.InlineSyntax> latexMathSyntaxes = List.unmodifiable([
  DisplayMathSyntax(),
  InlineMathSyntax(),
]);

/// Matches `$$...$$` display math, possibly spanning multiple lines, and emits
/// a `<math display="1">` element.
class DisplayMathSyntax extends md.InlineSyntax {
  /// Creates a display math inline syntax.
  DisplayMathSyntax() : super(r'\$\$([\s\S]+?)\$\$', startCharacter: 0x24);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.text('math', match[1]!.trim())..attributes['display'] = '1',
    );
    return true;
  }
}

/// Matches single-line `$...$` inline math and emits a `<math>` element.
///
/// Currency expressions like `"$5 and $10"` or bare numbers like `"$5$"` are
/// left as plain text.
class InlineMathSyntax extends md.InlineSyntax {
  /// Creates an inline math syntax.
  InlineMathSyntax()
    : super(r'\$(?![\s$])([^$\n]*?[^\s\\])\$(?!\d)', startCharacter: 0x24);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final expr = match[1]!;
    parser.addNode(
      RegExp(r'^\d[\d,.]*$').hasMatch(expr)
          ? md.Text(match[0]!)
          : md.Element.text('math', expr),
    );
    return true;
  }
}
