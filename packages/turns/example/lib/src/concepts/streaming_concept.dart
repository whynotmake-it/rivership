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

enum _Speed {
  slow('Slow', 2),
  normal('Normal', 6),
  fast('Fast', 18);

  const _Speed(this.label, this.chars);

  final String label;
  final int chars;
}

class _StreamingConceptState extends State<StreamingConcept> {
  var _session = MarkdownSession();
  late MarkdownDocument _doc = _session.update('');
  var _cursor = 0;
  var _playing = true;
  var _speed = _Speed.normal;
  Timer? _timer;

  /// Rendered stable segments, by id: built once, reused on every token.
  final _cache = <int, Widget>{};
  var _cacheHits = 0;
  var _reparsedChars = 0;

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
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    _code.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) => _tick());
  }

  void _tick() {
    if (!mounted || !_playing) return;
    if (_cursor >= _reply.length) {
      _timer?.cancel();
      setState(() => _playing = false);
      return;
    }
    setState(() {
      _cursor = math.min(_reply.length, _cursor + _speed.chars);
      final streaming = _cursor < _reply.length;
      _doc = _session.update(
        _reply.substring(0, _cursor),
        streaming: streaming,
      );
      _reparsedChars = _doc.pending?.source.length ?? 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _restart() {
    setState(() {
      _session = MarkdownSession();
      _doc = _session.update('');
      _cursor = 0;
      _cache.clear();
      _cacheHits = 0;
      _reparsedChars = 0;
      _playing = true;
    });
    _start();
  }

  Widget _stable(MarkdownSegment segment) {
    if (_cache.containsKey(segment.id)) {
      _cacheHits++;
      return _cache[segment.id]!;
    }
    return _cache[segment.id] = _Segment(
      key: ValueKey(segment.id),
      id: segment.id,
      source: segment.source,
      pending: false,
    );
  }

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
          _Source(
            pending?.source ?? '·',
            color: colors.brandInk,
          ),
        ],
      ),
    );

    return ConceptPage(
      routeName: turnsStreamingRouteName,
      lead:
          'A reply streams in a few characters at a time. Blocks that later '
          'text can no longer change freeze: they are parsed once and their '
          'widgets reused. Only the tail is parsed again, after '
          'completeMarkdown closes what is half written so it never shows '
          'raw asterisks.',
      controls: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          if (_cursor >= _reply.length)
            CoilButton(
              key: const Key('concept.streaming.play'),
              variant: CoilButtonVariant.secondary,
              size: CoilSize.compact,
              leading: const Icon(LucideIcons.play, size: 14),
              onPressed: _restart,
              child: const Text('Replay'),
            )
          else
            CoilButton(
              key: const Key('concept.streaming.play'),
              variant: CoilButtonVariant.secondary,
              size: CoilSize.compact,
              leading: Icon(
                _playing ? LucideIcons.pause : LucideIcons.play,
                size: 14,
              ),
              onPressed: () => setState(() => _playing = !_playing),
              child: Text(_playing ? 'Pause' : 'Play'),
            ),
          CoilButton(
            variant: CoilButtonVariant.ghost,
            size: CoilSize.compact,
            leading: const Icon(LucideIcons.rotateCcw, size: 14),
            onPressed: _restart,
            child: const Text('Restart'),
          ),
          SizedBox(
            width: 220,
            child: PlaygroundChoice<_Speed>(
              label: 'Speed',
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
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: segments),
                    divider,
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(child: tail),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(flex: 3, child: segments),
                    divider,
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(child: tail),
                    ),
                  ],
                );
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
            label: 'Parsed this token',
            value: '$_reparsedChars chars',
            tone: ConceptTone.good,
          ),
          ConceptStat(
            label: 'Parsing it all would be',
            value: '${streamed.length} chars',
            tone: ConceptTone.bad,
          ),
          ConceptStat(label: 'Widgets reused', value: '$_cacheHits'),
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
