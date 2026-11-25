/// @docImport 'package:coil/markdown.dart';
library;

import 'dart:async';

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/markdown/markdown_session.dart';
import 'package:coil/src/components/markdown/markdown_style.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;

/// Builds the span for an inline element [CoilMarkdown] doesn't know, such
/// as `math` from a math syntax. [style] is the surrounding text's.
typedef CoilMarkdownInlineBuilder =
    InlineSpan Function(
      BuildContext context,
      md.Element element,
      TextStyle style,
    );

/// Builds a block element in place of [CoilMarkdown]'s own, such as a
/// highlighted `pre` or a diagram. Return null to keep the default.
typedef CoilMarkdownBlockBuilder =
    Widget? Function(
      BuildContext context,
      md.Element element,
      CoilMarkdownBlockState state,
    );

/// What a [CoilMarkdownBlockBuilder] knows about its block.
@immutable
class CoilMarkdownBlockState {
  /// Creates the state.
  const CoilMarkdownBlockState({required this.settled, required this.style});

  /// Whether later text can no longer change the block. A streaming code
  /// block isn't settled until a boundary closes it, so offer Copy only
  /// once it is.
  final bool settled;

  /// The resolved style.
  final CoilMarkdownStyle style;
}

/// Markdown for reading in an app, such as an assistant's reply: GitHub
/// flavored (tables, task lists, strikethrough, autolinks), with a prose
/// type ramp and block rhythm from [CoilMarkdownStyle].
///
/// Built for text that streams in:
///
/// - Blocks that can no longer change are parsed and built once and reused
///   ([CoilMarkdownSession]); only the tail is parsed again per update.
/// - While [streaming], unfinished inline syntax in the last block is
///   completed for display ([completeMarkdown]).
/// - A block that arrives after the first build grows its height, then
///   fades in, so text below never jumps; blocks there at first show at
///   once (a reply loaded from history doesn't animate).
///
/// Extend it with `package:markdown` syntaxes and builders: math is an
/// [inlineSyntaxes] entry that writes `math` elements plus an
/// [inlineBuilders] entry that draws them; a code highlighter is a
/// [blockBuilders] entry for `pre`.
///
/// Headings are semantic headers, task boxes are checked or not, links are
/// tappable through [onTapLink], and code blocks have a Copy button.
class CoilMarkdown extends StatefulWidget {
  /// Renders [data].
  const CoilMarkdown(
    this.data, {
    super.key,
    this.streaming = false,
    this.style,
    this.inlineSyntaxes = const [],
    this.blockSyntaxes = const [],
    this.inlineBuilders = const {},
    this.blockBuilders = const {},
    this.onTapLink,
    this.trailing,
    this.copyCodeLabel = 'Copy code',
  });

  /// The markdown.
  final String data;

  /// Whether [data] is still arriving: unfinished syntax is completed and
  /// [trailing] shows.
  final bool streaming;

  /// Overrides for the look, on top of [CoilMarkdownStyle.fallback].
  final CoilMarkdownStyle? style;

  /// Extra inline syntaxes, tried before the built-in ones.
  final List<md.InlineSyntax> inlineSyntaxes;

  /// Extra block syntaxes, tried before the built-in ones.
  final List<md.BlockSyntax> blockSyntaxes;

  /// Builders for inline elements by tag, such as `math`.
  final Map<String, CoilMarkdownInlineBuilder> inlineBuilders;

  /// Builders for block elements by tag, such as `pre`.
  final Map<String, CoilMarkdownBlockBuilder> blockBuilders;

  /// Called with a link's destination when it is tapped. Null leaves links
  /// as styled text.
  final ValueChanged<String>? onTapLink;

  /// Ends the last line while [streaming], such as a caret.
  final Widget? trailing;

  /// The code block Copy button's name for screen readers.
  final String copyCodeLabel;

  @override
  State<CoilMarkdown> createState() => _CoilMarkdownState();
}

typedef _Block = ({String tag, Widget child});

class _Built {
  _Built(this.segment, this.blocks, this.recognizers);

  final CoilMarkdownSegment segment;
  final List<_Block> blocks;
  final List<GestureRecognizer> recognizers;

  void dispose() {
    for (final r in recognizers) {
      r.dispose();
    }
  }
}

class _CoilMarkdownState extends State<CoilMarkdown> {
  late CoilMarkdownSession _session = _newSession();
  final _cache = <int, _Built>{};
  _Built? _pending;

  /// Blocks below this index were there at the first build.
  int? _firstCount;

  CoilMarkdownSession _newSession() => CoilMarkdownSession(
    parse: (source) => coilParseMarkdown(
      source,
      inlineSyntaxes: widget.inlineSyntaxes,
      blockSyntaxes: widget.blockSyntaxes,
    ),
  );

  void _clear() {
    for (final built in _cache.values) {
      built.dispose();
    }
    _cache.clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The theme or text style changed: build every block again.
    _clear();
  }

  @override
  void didUpdateWidget(CoilMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.inlineSyntaxes, widget.inlineSyntaxes) ||
        !identical(oldWidget.blockSyntaxes, widget.blockSyntaxes)) {
      _session = _newSession();
      _clear();
    } else if (oldWidget.style != widget.style ||
        !identical(oldWidget.inlineBuilders, widget.inlineBuilders) ||
        !identical(oldWidget.blockBuilders, widget.blockBuilders) ||
        oldWidget.onTapLink != widget.onTapLink ||
        oldWidget.copyCodeLabel != widget.copyCodeLabel) {
      _clear();
    }
  }

  @override
  void dispose() {
    _clear();
    _pending?.dispose();
    super.dispose();
  }

  _Built _build(
    CoilMarkdownSegment segment,
    CoilMarkdownStyle style, {
    required bool settled,
    Widget? trailing,
  }) {
    final recognizers = <GestureRecognizer>[];
    final renderer = _Renderer(
      context,
      widget: widget,
      style: style,
      settled: settled,
      trailing: trailing,
      last: trailing == null ? null : _lastLeaf(segment.nodes),
      recognizers: recognizers,
    );
    return _Built(segment, renderer.blocks(segment.nodes), recognizers);
  }

  @override
  Widget build(BuildContext context) {
    final document = _session.update(
      widget.data,
      streaming: widget.streaming,
    );
    if (document.reset) _clear();
    final style = CoilMarkdownStyle.fallback(context).merge(widget.style);
    final trailing = widget.streaming ? widget.trailing : null;

    final blocks = <_Block>[];
    final kept = <int>{};
    for (final segment in document.stable) {
      kept.add(segment.id);
      var built = _cache[segment.id];
      if (built == null || !identical(built.segment, segment)) {
        built?.dispose();
        built = _cache[segment.id] = _build(segment, style, settled: true);
      }
      blocks.addAll(built.blocks);
    }
    for (final id in _cache.keys.toList()) {
      if (!kept.contains(id)) _cache.remove(id)!.dispose();
    }
    // The tail changes with every update: its recognizers go with it.
    final previous = _pending;
    _pending = null;
    if (document.pending case final pending?) {
      _pending = _build(pending, style, settled: false, trailing: trailing);
      blocks.addAll(_pending!.blocks);
    } else if (trailing != null) {
      blocks.add((tag: 'p', child: Text.rich(WidgetSpan(child: trailing))));
    }
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }

    final firstCount = _firstCount ??= blocks.length;
    final size = DefaultTextStyle.of(context).style.fontSize ?? 14;
    final motion = CoilTheme.motionOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, block) in blocks.indexed)
          KeyedSubtree(
            key: ValueKey(i),
            child: CoilCollapsible(
              expanded: true,
              appear: i >= firstCount,
              heightMotion: motion.gentle,
              opacityMotion: motion.fade,
              opacityDelay: const Duration(milliseconds: 80),
              debugLabel: 'CoilMarkdown.block',
              child: Padding(
                padding: EdgeInsets.only(
                  top: i == 0
                      ? 0
                      : _gap(style, size, blocks[i - 1].tag, block.tag),
                ),
                child: block.child,
              ),
            ),
          ),
      ],
    );
  }
}

const _headings = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};
const _blockTags = {
  ..._headings,
  'p',
  'ul',
  'ol',
  'li',
  'blockquote',
  'pre',
  'hr',
  'table',
  'section',
  'div',
};

bool _hasBlocks(md.Element e) =>
    e.children?.any((c) => c is md.Element && _blockTags.contains(c.tag)) ??
    false;

/// Room above [tag] after [previous], in pixels.
double _gap(CoilMarkdownStyle style, double size, String previous, String tag) {
  final factor = switch ((previous, tag)) {
    (_, 'h1' || 'h2') => style.headingGapAbove!,
    (_, final t) when _headings.contains(t) => style.blockGap! + 0.25,
    (final p, _) when _headings.contains(p) => style.headingGapBelow!,
    ('hr', _) || (_, 'hr') => style.ruleGap!,
    _ => style.blockGap!,
  };
  return factor * size;
}

/// The innermost last block, which ends with the trailing widget.
md.Node? _lastLeaf(List<md.Node> nodes) {
  var node = nodes.lastOrNull;
  while (node is md.Element &&
      (node.tag == 'ul' ||
          node.tag == 'ol' ||
          node.tag == 'blockquote' ||
          (node.tag == 'li' && _hasBlocks(node)))) {
    node = node.children?.lastOrNull;
  }
  return node;
}

class _Renderer {
  _Renderer(
    this.context, {
    required this.widget,
    required this.style,
    required this.settled,
    required this.trailing,
    required this.last,
    required this.recognizers,
  }) : base = DefaultTextStyle.of(context).style;

  final BuildContext context;
  final CoilMarkdown widget;
  final CoilMarkdownStyle style;
  final bool settled;
  final Widget? trailing;
  final md.Node? last;
  final List<GestureRecognizer> recognizers;
  final TextStyle base;

  double get size => base.fontSize ?? 14;

  late final TextStyle code = base
      .merge(style.codeStyle)
      .copyWith(fontSize: size * 0.9);

  TextStyle heading(int level) {
    final scale = style.headingScale![level - 1];
    return base.copyWith(
      fontSize: size * scale,
      height: scale > 1.1 ? 1.3 : base.height,
      fontWeight: style.headingWeight,
      letterSpacing: level == 1 ? -0.2 : base.letterSpacing,
    );
  }

  /// [nodes] as top-level blocks. Runs of inline nodes (a list item's text
  /// before its nested list) form one paragraph.
  List<_Block> blocks(List<md.Node> nodes) {
    final out = <_Block>[];
    final run = <md.Node>[];
    void flush() {
      if (run.every((n) => n is md.Text && n.text.trim().isEmpty)) {
        run.clear();
        return;
      }
      final end = run.any((n) => identical(n, last));
      out.add((
        tag: 'p',
        child: Text.rich(paragraph(List.of(run), base, end: end)),
      ));
      run.clear();
    }

    for (final node in nodes) {
      if (node is md.Element && _blockTags.contains(node.tag)) {
        flush();
        out.add((tag: node.tag, child: block(node)));
      } else {
        run.add(node);
      }
    }
    flush();
    return out;
  }

  /// [nodes] as a column, spaced like the top level.
  Widget column(List<md.Node> nodes) {
    final list = blocks(nodes);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, b) in list.indexed)
          Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : _gap(style, size, list[i - 1].tag, b.tag),
            ),
            child: b.child,
          ),
      ],
    );
  }

  Widget block(md.Element node) {
    if (widget.blockBuilders[node.tag] case final builder?) {
      final custom = builder(
        context,
        node,
        CoilMarkdownBlockState(settled: settled, style: style),
      );
      if (custom != null) return custom;
    }
    final end = identical(node, last);
    final kids = node.children ?? const <md.Node>[];
    switch (node.tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        return Semantics(
          container: true,
          header: true,
          child: Text.rich(
            paragraph(
              kids,
              heading(int.parse(node.tag.substring(1))),
              end: end,
            ),
          ),
        );
      case 'p':
        return Text.rich(paragraph(kids, base, end: end));
      case 'ul' || 'ol':
        return list(node);
      case 'blockquote':
        return DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: style.ruleColor!, width: 2),
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: size * 0.75),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: style.markerColor),
              child: Builder(
                builder: (context) => _Renderer(
                  context,
                  widget: widget,
                  style: style,
                  settled: settled,
                  trailing: trailing,
                  last: last,
                  recognizers: recognizers,
                ).column(kids),
              ),
            ),
          ),
        );
      case 'pre':
        return _CodeBlock(
          element: node,
          style: code,
          fill: style.codeFill!,
          settled: settled,
          trailing: end ? trailing : null,
          copyLabel: widget.copyCodeLabel,
        );
      case 'hr':
        return SizedBox(
          height: 1,
          child: ColoredBox(color: style.ruleColor!),
        );
      case 'table':
        return table(node);
      default:
        return _hasBlocks(node)
            ? column(kids)
            : Text.rich(paragraph(kids, base, end: end));
    }
  }

  Widget list(md.Element list) {
    final ordered = list.tag == 'ol';
    var number = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    final items = <Widget>[];
    for (final item in list.children ?? const <md.Node>[]) {
      if (item is! md.Element || item.tag != 'li') continue;
      var kids = item.children ?? const <md.Node>[];
      // A GFM task item starts with a checkbox.
      bool? checked;
      if (kids.firstOrNull case md.Element(tag: 'input', :final attributes)) {
        checked = attributes.containsKey('checked');
        kids = kids.skip(1).toList();
      }
      final Widget marker = checked != null
          ? _TaskBox(checked: checked, size: size, color: style.markerColor!)
          : Text(
              ordered ? '${number++}.' : '•',
              style: (ordered ? base.tabular : base).copyWith(
                color: style.markerColor,
              ),
            );
      final content = _hasBlocks(item)
          ? column(kids)
          : Text.rich(paragraph(kids, base, end: identical(item, last)));
      items.add(
        Padding(
          padding: EdgeInsets.only(
            top: items.isEmpty ? 0 : size * style.listItemGap!,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: size * 1.5, child: marker),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items,
    );
  }

  Widget table(md.Element table) {
    final rows = <(bool, List<md.Element>)>[];
    for (final section in table.children ?? const <md.Node>[]) {
      if (section is! md.Element) continue;
      for (final row in section.children ?? const <md.Node>[]) {
        if (row is! md.Element || row.tag != 'tr') continue;
        rows.add((
          section.tag == 'thead',
          [
            for (final cell in row.children ?? const <md.Node>[])
              if (cell is md.Element) cell,
          ],
        ));
      }
    }
    final columns = rows.fold(0, (n, r) => r.$2.length > n ? r.$2.length : n);
    if (columns == 0) return const SizedBox.shrink();
    final line = BorderSide(color: style.ruleColor!);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder(horizontalInside: line, bottom: line),
        children: [
          for (final (header, cells) in rows)
            TableRow(
              children: [
                for (var i = 0; i < columns; i++)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size * 0.6,
                      vertical: size * 0.4,
                    ),
                    child: i < cells.length
                        ? Text.rich(
                            paragraph(
                              cells[i].children ?? const [],
                              header
                                  ? base.copyWith(
                                      fontWeight: style.headingWeight,
                                    )
                                  : base,
                              end: false,
                            ),
                            textAlign: switch (cells[i].attributes['align']) {
                              'right' => TextAlign.end,
                              'center' => TextAlign.center,
                              _ => TextAlign.start,
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Inline [nodes] in [style], ending with the trailing widget when [end].
  TextSpan paragraph(
    List<md.Node> nodes,
    TextStyle textStyle, {
    required bool end,
  }) => TextSpan(
    style: textStyle,
    children: [
      for (final node in nodes) ...inline(node, textStyle),
      if (end && trailing != null)
        WidgetSpan(alignment: PlaceholderAlignment.middle, child: trailing!),
    ],
  );

  List<InlineSpan> inline(md.Node node, TextStyle textStyle) {
    if (node is md.Text) return [TextSpan(text: node.text)];
    if (node is! md.Element) return [TextSpan(text: node.textContent)];
    if (widget.inlineBuilders[node.tag] case final builder?) {
      return [builder(context, node, textStyle)];
    }
    List<InlineSpan> kids([TextStyle? inner]) => [
      for (final child in node.children ?? const <md.Node>[])
        ...inline(child, inner ?? textStyle),
    ];
    switch (node.tag) {
      case 'strong':
        final bold = TextStyle(fontWeight: style.headingWeight);
        return [
          TextSpan(style: bold, children: kids(textStyle.merge(bold))),
        ];
      case 'em':
        return [
          TextSpan(
            style: const TextStyle(fontStyle: FontStyle.italic),
            children: kids(),
          ),
        ];
      case 'del':
        return [
          TextSpan(
            style: const TextStyle(decoration: TextDecoration.lineThrough),
            children: kids(),
          ),
        ];
      case 'code':
        return [
          TextSpan(
            text: node.textContent,
            style: code.copyWith(
              background: Paint()..color = style.codeFill!,
              color: textStyle.color,
            ),
          ),
        ];
      case 'a':
        final href = node.attributes['href'];
        final onTap = widget.onTapLink;
        TapGestureRecognizer? recognizer;
        if (href != null && onTap != null) {
          recognizer = TapGestureRecognizer()..onTap = () => onTap(href);
          recognizers.add(recognizer);
        }
        // A tap goes to the span it lands on, so the recognizer sits on the
        // link's own text (nested formatting inside a link is dropped).
        return [
          TextSpan(
            text: node.textContent,
            style: style.linkStyle,
            recognizer: recognizer,
            mouseCursor: recognizer == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
          ),
        ];
      case 'br':
        return [const TextSpan(text: '\n')];
      case 'img':
        return [TextSpan(text: node.attributes['alt'] ?? '')];
      default:
        return kids();
    }
  }
}

/// A fenced code block: its language, a Copy button once it can no longer
/// change, and the code, scrolling sideways when wide.
class _CodeBlock extends StatefulWidget {
  const _CodeBlock({
    required this.element,
    required this.style,
    required this.fill,
    required this.settled,
    required this.trailing,
    required this.copyLabel,
  });

  final md.Element element;
  final TextStyle style;
  final Color fill;
  final bool settled;
  final Widget? trailing;
  final String copyLabel;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  final _copy = CoilCopyController();

  @override
  void dispose() {
    _copy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final metrics = CoilTheme.metricsOf(context);
    final codeNode = widget.element.children?.firstOrNull;
    final language = codeNode is md.Element
        ? codeNode.attributes['class']?.replaceFirst('language-', '')
        : null;
    // The parser keeps the fence's last newline.
    final source = widget.element.textContent.replaceFirst(
      RegExp(r'\n$'),
      '',
    );
    final pad = metrics.controlPaddingX;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: widget.fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(CoilTheme.radiiOf(context).item),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(start: pad, end: 2, top: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language ?? '',
                    style: text.muted.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CoilButton.icon(
                  size: CoilSize.compact,
                  variant: CoilButtonVariant.ghost,
                  semanticLabel: widget.copyLabel,
                  onPressed: widget.settled
                      ? () => unawaited(_copy.copy(source, context: context))
                      : null,
                  icon: CoilCopyGlyph.listening(controller: _copy),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(pad, 0, pad, metrics.gap + 4),
            child: Text.rich(
              TextSpan(
                text: source,
                style: widget.style,
                children: [
                  if (widget.trailing case final trailing?)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: trailing,
                    ),
                ],
              ),
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// A task item's box: an outline, filled with a check when done, centered
/// on the first line of the item's text.
class _TaskBox extends StatelessWidget {
  const _TaskBox({
    required this.checked,
    required this.size,
    required this.color,
  });

  final bool checked;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final style = DefaultTextStyle.of(context).style;
    final box = size * 0.875;
    return Semantics(
      checked: checked,
      child: SizedBox(
        height: size * (style.height ?? 1.4),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: checked ? color : null,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(box * 0.25),
                side: checked
                    ? BorderSide.none
                    : BorderSide(color: color, width: 1.5),
              ),
            ),
            child: SizedBox.square(
              dimension: box,
              child: checked
                  ? IconTheme.merge(
                      data: IconThemeData(
                        size: box * 0.8,
                        color: colors.background,
                      ),
                      child: const Center(
                        child: CoilIcon(CoilIconRole.check),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
