import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turns/turns.dart';
import 'package:turns_example/src/concepts/concept_page.dart';
import 'package:turns_example/src/shell/turns_playground.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

/// Streams a reply through a [MarkdownSession] and draws each segment: the
/// stable ones, parsed once and reused by identity, and the pending tail,
/// parsed again on every token after [completeMarkdown] repairs it.
class StreamingConcept extends StatefulWidget {
  const StreamingConcept({super.key});

  @override
  State<StreamingConcept> createState() => _StreamingConceptState();
}

const _reply = '''
## Release plan

We ship the **pagination rework** on Thursday. Three things changed since the last review:

- Older pages prepend with no visible shift.
- Jumps lay out about one screen, however far they go.
- The composer keeps the last message in view as it grows.

```dart
final doc = session.update(text, streaming: true);
for (final block in doc.stable) cache[block.id] ??= render(block);
```

| Step | Owner | When |
| :--- | :--- | :--- |
| QA pass | Devon | Wed |
| Rollout | Priya | Thu |

> Rollback is one flag flip. Ping `#release` if the error rate moves.

Questions go in the thread, and _thanks_ for the reviews!
''';

/// Characters per second while playing.
enum _Speed {
  crawl('Crawl', 6),
  slow('Slow', 20),
  normal('Normal', 60);

  const _Speed(this.label, this.charsPerSecond);

  final String label;
  final int charsPerSecond;
}

class _StreamingConceptState extends State<StreamingConcept> {
  var _session = MarkdownSession();
  late MarkdownDocument _doc = _session.update('');
  var _cursor = 0;
  var _playing = false;
  var _speed = _Speed.slow;
  Timer? _timer;
  var _carry = 0.0;

  /// Rendered frozen segments by id: each is built once and reused.
  final _cache = <int, Widget>{};

  final _scroll = ScrollController();
  final _code = ValueNotifier(
    '// On every token:\n'
    'final doc = session.update(reply, streaming: true);\n'
    '\n'
    '// doc.stable: parsed once, same instances every update.\n'
    'for (final block in doc.stable) cache[block.id] ??= render(block);\n'
    '\n'
    '// doc.pending: the only part parsed again, after completeMarkdown\n'
    '// closes half-written **bold**, `code` and [links](.',
  );

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Shows the reply as it was after `to` characters had streamed in.
  ///
  /// Forward, the session continues where it was, as it would in an app.
  /// Backward, the text no longer extends what it saw, so it starts over:
  /// that is the session's reset, and the result is the same either way.
  void _seek(int to) {
    final cursor = to.clamp(0, _reply.length);
    if (cursor < _cursor) {
      _session = MarkdownSession();
      _cache.clear();
    }
    _cursor = cursor;
    _doc = _session.update(
      _reply.substring(0, cursor),
      streaming: cursor < _reply.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _togglePlay() {
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
      return;
    }
    if (_cursor >= _reply.length) setState(() => _seek(0));
    setState(() => _playing = true);
    _carry = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted) return timer.cancel();
      _carry += _speed.charsPerSecond * 0.033;
      final step = _carry.floor();
      if (step == 0) return;
      _carry -= step;
      setState(() {
        _seek(_cursor + step);
        if (_cursor >= _reply.length) {
          _playing = false;
          timer.cancel();
        }
      });
    });
  }

  Widget _stable(MarkdownSegment segment) => _cache[segment.id] ??= _Segment(
    key: ValueKey(segment.id),
    id: segment.id,
    source: segment.source,
    pending: false,
  );

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final colors = CoilTheme.of(context).colors;
    final streamed = _reply.substring(0, _cursor);
    final stableLength = _doc.stable.fold<int>(
      0,
      (sum, s) => sum + s.source.length,
    );
    final rawTail = streamed.substring(math.min(stableLength, streamed.length));
    final pending = _doc.pending;

    final segments = ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      children: [
        if (_cursor == 0)
          Text(
            'Drag the scrubber or press play.',
            style: text.muted.caption,
          ),
        for (final segment in _doc.stable) _stable(segment),
        if (pending != null)
          _Segment(
            key: ValueKey(pending.id),
            id: pending.id,
            source: pending.source,
            pending: true,
          ),
      ],
    );

    final tail = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text('The pending tail, as streamed', style: text.muted.micro),
          _Source(rawTail.isEmpty ? '·' : rawTail, color: colors.destructive),
          Text('After completeMarkdown', style: text.muted.micro),
          _Source(pending?.source ?? '·', color: colors.brandInk),
        ],
      ),
    );

    return ConceptPage(
      routeName: turnsStreamingRouteName,
      lead:
          'Drag through a reply as it streams in. A block freezes once the '
          'text after it can no longer change it: it is parsed once and its '
          'widget reused. Only the tail is parsed again on every token, '
          'after completeMarkdown closes what is half written, so watch the '
          'two boxes on the right around ** and backticks.',
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              CoilButton.icon(
                key: const Key('concept.streaming.play'),
                variant: CoilButtonVariant.secondary,
                size: CoilSize.compact,
                semanticLabel: _playing ? 'Pause' : 'Play',
                icon: Icon(
                  _playing ? LucideIcons.pause : LucideIcons.play,
                  size: 14,
                ),
                onPressed: _togglePlay,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CoilSlider(
                  key: const Key('concept.streaming.scrubber'),
                  value: _cursor.toDouble(),
                  max: _reply.length.toDouble(),
                  divisions: _reply.length,
                  size: CoilSize.compact,
                  label: const Text('Streamed'),
                  valueBuilder: (context, v) =>
                      Text('${v.round()} / ${_reply.length}'),
                  semanticLabel: 'Characters streamed',
                  onChanged: (v) => setState(() => _seek(v.round())),
                ),
              ),
            ],
          ),
          SizedBox(
            width: 260,
            child: PlaygroundChoice<_Speed>(
              label: 'Play speed',
              value: _speed,
              options: {for (final s in _Speed.values) s: s.label},
              onChanged: (v) => setState(() => _speed = v),
            ),
          ),
        ],
      ),
      stage: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 640;
          final divider = ColoredBox(
            color: colors.border,
            child: wide
                ? const SizedBox(width: 1, height: double.infinity)
                : const SizedBox(height: 1, width: double.infinity),
          );
          final children = [
            Expanded(flex: 3, child: segments),
            divider,
            Expanded(flex: 2, child: SingleChildScrollView(child: tail)),
          ];
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                )
              : Column(children: children);
        },
      ),
      stageHeight: 500,
      readout: ConceptStats(
        children: [
          ConceptStat(
            label: 'Frozen blocks',
            value: '${_doc.stable.length}',
            tone: ConceptTone.good,
          ),
          ConceptStat(
            label: 'Parsed on this token',
            value: '${pending?.source.length ?? 0} chars',
            tone: ConceptTone.good,
          ),
          ConceptStat(
            label: 'Parsing it all would be',
            value: '${streamed.length} chars',
            tone: ConceptTone.bad,
          ),
        ],
      ),
      code: _code,
    );
  }
}

/// One segment of the reply with a rule and a tag saying whether it is
/// frozen or still parsed on every token.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.id,
    required this.source,
    required this.pending,
    super.key,
  });

  final int id;
  final String source;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final rule = pending ? colors.brandMark : colors.border;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pending ? colors.brandWash.withValues(alpha: 0.35) : null,
          border: BorderDirectional(start: BorderSide(color: rule, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                pending ? 'pending · parsed every token' : 'block $id · frozen',
                style: text.micro.copyWith(
                  color: pending ? colors.brandInk : colors.mutedForeground,
                  fontWeight: text.emphasis,
                ),
              ),
              const SizedBox(height: 4),
              CoilMarkdown(source, streaming: pending),
            ],
          ),
        ),
      ),
    );
  }
}

class _Source extends StatelessWidget {
  const _Source(this.source, {required this.color});

  final String source;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.background,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          source.length > 220
              ? '…${source.substring(source.length - 220)}'
              : source,
          style: text.micro.copyWith(
            fontFamily: 'JetBrains Mono',
            fontFamilyFallback: const ['monospace'],
            color: color,
          ),
        ),
      ),
    );
  }
}
