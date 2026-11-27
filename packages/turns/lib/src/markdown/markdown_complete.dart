/// @docImport 'package:turns/markdown.dart';
library;

/// [source] with its unfinished inline syntax completed, for text that is
/// still streaming, so "the **key ide" shows as **key ide** rather than
/// raw asterisks that turn bold a moment later.
///
/// It repairs a copy to display and never changes the source. Like Pierre's
/// Words renderer, it looks only at the last block, and it writes no closer
/// that might not pair:
///
/// - `**`, `~~` and `*` (when it opens emphasis, not a list item or a
///   spaced-out star) are closed in the order they opened, before any
///   trailing spaces, so the closer can pair;
/// - an inline code span is closed with `` ` ``;
/// - a link whose URL is still arriving, `[text](http`, is closed with `)`;
/// - a marker with nothing after it yet is dropped instead, so "the **"
///   shows as "the".
///
/// An open code fence is left alone: it already runs to the end.
String completeMarkdown(String source) {
  if (_fenceCount(source).isOdd) return source;
  final blockStart = _lastBlockStart(source);
  final head = source.substring(0, blockStart);
  var block = source.substring(blockStart);

  final open = <({String marker, int at})>[];
  final drop = <int>[];
  var codeOpen = -1;
  var i = 0;
  while (i < block.length) {
    final c = block[i];
    if (c == r'\') {
      i += 2;
      continue;
    }
    if (c == '`') {
      var run = 1;
      while (i + run < block.length && block[i + run] == '`') {
        run++;
      }
      if (codeOpen < 0) {
        final close = block.indexOf('`' * run, i + run);
        if (close < 0) {
          codeOpen = i;
          break;
        }
        i = close + run;
        continue;
      }
      i += run;
      continue;
    }
    final String? marker;
    if (block.startsWith('**', i)) {
      marker = '**';
    } else if (block.startsWith('~~', i)) {
      marker = '~~';
    } else if (c == '*' && !_isListStar(block, i)) {
      marker = '*';
    } else {
      marker = null;
    }
    if (marker == null) {
      i++;
      continue;
    }
    final at = open.lastIndexWhere((o) => o.marker == marker);
    if (at >= 0) {
      open.removeAt(at);
    } else {
      final next = i + marker.length < block.length
          ? block[i + marker.length]
          : '';
      // Only a marker followed by text opens; "a * b" is a star.
      if (next.isEmpty || next.trim().isNotEmpty) {
        open.add((marker: marker, at: i));
      }
    }
    i += marker.length;
  }

  if (codeOpen >= 0) {
    final rest = block.substring(codeOpen).replaceFirst(RegExp('^`+'), '');
    if (rest.trim().isEmpty) {
      drop.add(codeOpen);
    } else {
      final ticks = RegExp('^`+').firstMatch(block.substring(codeOpen))![0]!;
      block = '$block$ticks';
    }
  }

  // Markers with nothing after them yet go; the rest close, innermost
  // first, before trailing spaces so they can pair.
  final closers = StringBuffer();
  for (final o in open.reversed) {
    if (o.at + o.marker.length >= block.trimRight().length) {
      drop.add(o.at);
    } else {
      closers.write(o.marker);
    }
  }
  for (final at in drop.toList()..sort((a, b) => b.compareTo(a))) {
    final run = RegExp(r'^(\*\*|~~|\*|`+)').firstMatch(block.substring(at));
    block = block.replaceRange(at, at + (run?[0]?.length ?? 1), '');
  }

  final trimmed = block.trimRight();
  final trailing = block.substring(trimmed.length);
  var body = trimmed;
  if (RegExp(r'\[[^\]\n]*\]\([^)\s]*$').hasMatch(body)) body = '$body)';
  return '$head$body$closers$trailing';
}

int _fenceCount(String source) => RegExp(
  '^ {0,3}(`{3,}|~{3,})',
  multiLine: true,
).allMatches(source).length;

/// Where the last block starts: after the last blank line.
int _lastBlockStart(String source) {
  final blank = RegExp(r'\n[ \t]*\n').allMatches(source).lastOrNull;
  return blank?.end ?? 0;
}

/// A `*` that marks a list item: first on its line, then a space.
bool _isListStar(String block, int i) {
  final lineStart = block.lastIndexOf('\n', i - 1) + 1;
  return block.substring(lineStart, i).trim().isEmpty &&
      i + 1 < block.length &&
      block[i + 1] == ' ';
}
