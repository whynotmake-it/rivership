/// @docImport 'package:turns/markdown.dart';
library;

import 'package:markdown/markdown.dart' as md;
import 'package:meta/meta.dart';
import 'package:turns/src/markdown/markdown_complete.dart';

/// Parses markdown source into `package:markdown` nodes.
typedef MarkdownParser = List<md.Node> Function(String source);

/// Parses GitHub-flavored markdown into `package:markdown` AST nodes.
///
/// Text is not HTML-escaped (`encodeHtml: false`), since it is meant for
/// native rendering rather than HTML output.
List<md.Node> parseMarkdown(
  String source, {
  Iterable<md.InlineSyntax> inlineSyntaxes = const [],
  Iterable<md.BlockSyntax> blockSyntaxes = const [],
}) => md.Document(
  extensionSet: md.ExtensionSet.gitHubFlavored,
  inlineSyntaxes: inlineSyntaxes,
  blockSyntaxes: blockSyntaxes,
  encodeHtml: false,
).parse(source);

/// A run of source parsed on its own: one or more top-level blocks.
@immutable
final class MarkdownSegment {
  /// Creates a segment.
  const MarkdownSegment({
    required this.id,
    required this.source,
    required this.nodes,
  });

  /// Stable while the segment exists: the pending segment keeps its id when
  /// its first part becomes stable.
  final int id;

  /// Its markdown, exactly as it appears in the source text.
  ///
  /// For the pending tail of a streaming update this is the raw text, half
  /// written syntax and all; [nodes] were parsed from
  /// `completeMarkdown(source)` instead.
  final String source;

  /// Its top-level nodes. For the pending tail of a streaming update, these
  /// come from `completeMarkdown(source)`, so unfinished emphasis, code and
  /// links already render closed.
  final List<md.Node> nodes;
}

/// What [MarkdownSession.update] found: blocks that can no longer change, and
/// the tail that can.
@immutable
final class MarkdownDocument {
  /// Creates a document.
  const MarkdownDocument({
    required this.stable,
    required this.pending,
    required this.reset,
  });

  /// Segments that later text can't change, oldest first. The same instances
  /// come back from later updates, so their output can be cached by identity.
  final List<MarkdownSegment> stable;

  /// The tail, parsed again on every update; null when the source ends on a
  /// boundary.
  final MarkdownSegment? pending;

  /// Whether the stable segments were dropped and parsed again (an edit, or
  /// link definitions that can change earlier text).
  final bool reset;
}

/// Parses a growing markdown string, such as a streaming reply, and reuses
/// what can no longer change.
///
/// Only the tail is parsed again on each [update]. A blank line at the top
/// level, outside code fences and HTML blocks, and followed by a line that
/// starts a new block, ends everything before it: lists, quotes and tables
/// can still change until such a boundary closes them. This follows the
/// session model of Pierre's Words renderer.
///
/// Link reference and footnote definitions can change earlier text, so a
/// source with any is always parsed whole. Text that no longer extends the
/// last source (an edit, a new message) starts over.
///
/// While [update] is told the text is still streaming, the pending tail is
/// repaired first with [completeMarkdown], so half-written emphasis and
/// code show styled.
class MarkdownSession {
  /// Creates a session that parses with [parse].
  MarkdownSession({MarkdownParser? parse}) : _parse = parse ?? parseMarkdown;

  final MarkdownParser _parse;
  final _stable = <MarkdownSegment>[];
  var _stableLength = 0;

  /// The source text the stable segments were cut from, to tell an edit from
  /// an append without copying it again on every update.
  var _stableSource = '';
  var _nextId = 0;

  static final _definition = RegExp(r'^ {0,3}\[[^\]\n]+\]:');

  /// Whether [source] has a link reference or footnote definition at or after
  /// [from] (a line start outside any code fence).
  ///
  /// Starts at the end of the stable text: that was clean when it became
  /// stable, and it ends outside any fence, so only what is still pending is
  /// scanned, not the whole source again on every update.
  static bool _hasDefinition(String source, int from) {
    String? fence;
    var offset = from;
    while (offset < source.length) {
      final newline = source.indexOf('\n', offset);
      final end = newline < 0 ? source.length : newline;
      final line = source.substring(offset, end);
      offset = end + 1;
      if (fence != null) {
        if (_closesFence(line, fence)) fence = null;
        continue;
      }
      if (_fence.firstMatch(line) case final open?) {
        fence = open[1];
      } else if (_definition.hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  /// Parses [source], reusing the stable segments of the last update.
  MarkdownDocument update(String source, {bool streaming = false}) {
    var reset = false;
    // The stable text must still be the start of the source, otherwise it was
    // an edit (or a new message). A comparison, with no copy and no regex.
    if (_stableLength > 0 && !source.startsWith(_stableSource)) {
      reset = true;
      _stable.clear();
      _stableLength = 0;
      _stableSource = '';
    }
    final definitions = _hasDefinition(source, _stableLength);
    if (definitions && _stable.isNotEmpty) {
      reset = true;
      _stable.clear();
      _stableLength = 0;
      _stableSource = '';
    }
    if (!definitions) {
      var from = _stableLength;
      while (true) {
        final cut = markdownBoundary(source, from);
        if (cut == null) break;
        final chunk = source.substring(from, cut);
        _stable.add(
          MarkdownSegment(
            id: _nextId++,
            source: chunk,
            nodes: _parse(chunk),
          ),
        );
        from = cut;
      }
      if (from != _stableLength) {
        _stableLength = from;
        _stableSource = source.substring(0, from);
      }
    }
    final tail = source.substring(_stableLength);
    final pending = tail.trim().isEmpty
        ? null
        : MarkdownSegment(
            id: _nextId,
            source: tail,
            nodes: _parse(streaming ? completeMarkdown(tail) : tail),
          );
    return MarkdownDocument(
      stable: List.unmodifiable(_stable),
      pending: pending,
      reset: reset,
    );
  }
}

final _listMarker = RegExp(r'^(?:[-*+]|\d{1,9}[.)])(?:[ \t]|$)');
final _fence = RegExp('^ {0,3}(`{3,}|~{3,})');

/// HTML blocks that may hold blank lines, and what ends each.
final _htmlOpeners = <RegExp, String>{
  RegExp('^ {0,3}<!--'): '-->',
  RegExp(r'^ {0,3}<pre\b', caseSensitive: false): '</pre>',
  RegExp(r'^ {0,3}<script\b', caseSensitive: false): '</script>',
  RegExp(r'^ {0,3}<style\b', caseSensitive: false): '</style>',
  RegExp(r'^ {0,3}<textarea\b', caseSensitive: false): '</textarea>',
};

/// Whether [line] closes a code fence opened with [fence].
bool _closesFence(String line, String fence) {
  final close = _fence.firstMatch(line);
  return close != null &&
      close[1]![0] == fence[0] &&
      close[1]!.length >= fence.length &&
      line.trim() == close[1];
}

/// The offset after the first safe boundary in [source] at or after [from]:
/// the start of a top-level block that nothing before it can change. Null
/// when there is none yet.
///
/// A boundary is a run of blank lines outside a code fence or an HTML block
/// that may hold blank lines, followed by a complete line at column 0 that
/// can't continue the block before it: after a list, not another item.
int? markdownBoundary(String source, int from) {
  String? fence;
  String? htmlCloser;
  var blockStarted = false;
  var inList = false;
  var blankSeen = false;
  var offset = from;
  while (offset < source.length) {
    final newline = source.indexOf('\n', offset);
    if (newline < 0) {
      // The last line may still be growing. It can already start a new
      // block if its first character rules out continuing the one before:
      // anything at column 0 after a blank, except what could still turn
      // into the next item of a list.
      final line = source.substring(offset);
      if (fence == null &&
          htmlCloser == null &&
          blankSeen &&
          line.isNotEmpty &&
          !line.startsWith(' ') &&
          !line.startsWith('\t') &&
          !(inList && RegExp(r'^[-*+\d]').hasMatch(line))) {
        return offset;
      }
      return null;
    }
    final start = offset;
    final line = source.substring(start, newline);
    offset = newline + 1;
    if (fence != null) {
      if (_closesFence(line, fence)) fence = null;
      continue;
    }
    if (htmlCloser != null) {
      if (line.contains(htmlCloser)) htmlCloser = null;
      continue;
    }
    if (line.trim().isEmpty) {
      if (blockStarted) blankSeen = true;
      continue;
    }
    final column0 = !line.startsWith(' ') && !line.startsWith('\t');
    final listItem = column0 && _listMarker.hasMatch(line);
    if (blankSeen && column0 && !(inList && listItem)) {
      return start;
    }
    if (!blockStarted) inList = listItem;
    blankSeen = false;
    blockStarted = true;
    if (_fence.firstMatch(line) case final open?) {
      fence = open[1];
    } else {
      for (final MapEntry(key: opener, value: closer) in _htmlOpeners.entries) {
        if (opener.hasMatch(line)) {
          // Closed on its own line: nothing stays open.
          if (!line.contains(closer)) htmlCloser = closer;
          break;
        }
      }
    }
  }
  return null;
}
