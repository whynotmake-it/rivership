/// @docImport 'package:coil/markdown.dart';
library;

import 'package:markdown/markdown.dart' as md;
import 'package:turns/markdown.dart' as turns;

export 'package:turns/markdown.dart' show completeMarkdown, markdownBoundary;

/// Parses markdown source into `package:markdown` nodes.
typedef CoilMarkdownParser = turns.MarkdownParser;

/// GitHub-flavored markdown, as [CoilMarkdown] parses it by default: text
/// is not HTML-escaped, since it is shown, not put in a page.
List<md.Node> coilParseMarkdown(
  String source, {
  Iterable<md.InlineSyntax> inlineSyntaxes = const [],
  Iterable<md.BlockSyntax> blockSyntaxes = const [],
}) => turns.parseMarkdown(
  source,
  inlineSyntaxes: inlineSyntaxes,
  blockSyntaxes: blockSyntaxes,
);

/// A run of source parsed on its own: one or more top-level blocks.
typedef CoilMarkdownSegment = turns.MarkdownSegment;

/// What [CoilMarkdownSession.update] found: blocks that can no longer
/// change, and the tail that can.
typedef CoilMarkdownDocument = turns.MarkdownDocument;

/// Parses a growing markdown string, such as a streaming reply, and reuses
/// what can no longer change.
typedef CoilMarkdownSession = turns.MarkdownSession;
