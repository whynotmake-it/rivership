import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turns/turns.dart';
import 'package:turns_example/src/concepts/concept_page.dart';
import 'package:turns_example/src/shell/turns_playground.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

/// Pins a prompt and lets you scrub its reply's length, with the whole
/// scroll extent drawn to scale beside the chat: the history, the prompt,
/// the reply, the space [SliverTurnStage] reserves, and the viewport.
class PinningConcept extends StatefulWidget {
  const PinningConcept({super.key});

  @override
  State<PinningConcept> createState() => _PinningConceptState();
}

const _history = [
  'Can you help me plan the launch?',
  'Of course. What is the date, and who is on the team?',
  'Thursday. Maya, Devon and Priya.',
  'Great, three owners for three milestones then.',
  'Exactly. What should I check first?',
  'Pricing copy, then QA, then the rollout itself.',
];

const _shortPrompt = 'What could still go wrong on launch day?';

final _tallPrompt = [
  'Here is the full checklist, tell me what is missing:',
  for (var i = 1; i <= 24; i++) '$i. ${_checklist[i % _checklist.length]}',
].join('\n');

const _checklist = [
  'Pricing page reviewed by legal',
  'Feature flags default to off',
  'Rollback script tested on staging',
  'Status page drafted',
  'Support macros updated',
  'Dashboards for error rate and latency',
];

const _reply =
    'Three things tend to bite on launch day. First, caches: a cold cache '
    'can triple load on the primary for the first hour, so warm it the '
    'night before. Second, rate limits: partners integrating on day one '
    'retry aggressively, so check the limits on the public API and make '
    'sure 429s carry a Retry-After header. Third, the rollback: run it once '
    'on staging with production-sized data, because a rollback that takes '
    'forty minutes is not a rollback. Beyond that, keep one person off the '
    'feature work entirely, watching dashboards, with the authority to flip '
    'the flag back without asking anyone. Write down who that is before '
    'Thursday, and tell the support team, so they know who to page. Finally, '
    'plan a short retro for Friday morning while it is all fresh.';

/// The extent, top to bottom, in the scroll view's own coordinates.
@immutable
class _Geometry {
  const _Geometry({
    required this.total,
    required this.promptTop,
    required this.promptBottom,
    required this.replyBottom,
    required this.reserved,
    required this.viewTop,
    required this.viewport,
  });

  final double total;
  final double promptTop;
  final double promptBottom;
  final double replyBottom;
  final double reserved;
  final double viewTop;
  final double viewport;

  double get maxScroll => total - viewport;

  @override
  bool operator ==(Object other) =>
      other is _Geometry &&
      (other.total - total).abs() < 0.5 &&
      (other.promptTop - promptTop).abs() < 0.5 &&
      (other.promptBottom - promptBottom).abs() < 0.5 &&
      (other.replyBottom - replyBottom).abs() < 0.5 &&
      (other.reserved - reserved).abs() < 0.5 &&
      (other.viewTop - viewTop).abs() < 0.5 &&
      (other.viewport - viewport).abs() < 0.5;

  @override
  int get hashCode => Object.hash(
    total.round(),
    promptTop.round(),
    replyBottom.round(),
    reserved.round(),
    viewTop.round(),
  );
}

class _PinningConceptState extends State<PinningConcept> {
  var _controller = TurnScrollController();
  final _scrollKey = GlobalKey();
  final _promptKey = GlobalKey();
  final _replyKey = GlobalKey();

  var _tall = false;
  var _pinning = true;
  var _replyLength = 0.25;
  var _turn = 0;
  _Geometry? _geometry;

  final _code = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _updateCode();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  void dispose() {
    _controller.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _promptId => 'prompt-$_turn';

  void _updateCode() {
    _code.value = _pinning
        ? 'TurnScrollView(\n'
              "  pinnedId: '$_promptId', // the prompt you just sent\n"
              '  anchorConfig: TurnAnchorConfig.standard,\n'
              '  // = TurnAnchorConfig(alignment: 0, minTrailingFraction: '
              '0.5)\n'
              '  ...\n'
              ')'
        : 'TurnScrollView(\n'
              '  pinnedId: null, // nothing reserved: the reply grows '
              'off screen\n'
              '  ...\n'
              ')';
  }

  /// Sends the prompt again, so the pin's flight plays again.
  void _resend() {
    final old = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    setState(() {
      _turn++;
      _controller = TurnScrollController();
      _geometry = null;
      _updateCode();
    });
  }

  RenderViewport? _findViewport(RenderObject node) {
    if (node is RenderViewport) return node;
    RenderViewport? found;
    node.visitChildren((child) => found ??= _findViewport(child));
    return found;
  }

  void _measure(Duration _) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    final root = _scrollKey.currentContext?.findRenderObject();
    final prompt = _promptKey.currentContext?.findRenderObject();
    final reply = _replyKey.currentContext?.findRenderObject();
    if (root is! RenderBox ||
        prompt is! RenderBox ||
        reply is! RenderBox ||
        !_controller.hasClients) {
      return;
    }
    final pos = _controller.position;
    if (!pos.hasContentDimensions || !pos.hasViewportDimension) return;
    final viewport = _findViewport(root);
    if (viewport == null) return;
    // Screen y in the viewport to content y, with 0 at the very top.
    double content(RenderBox box, double dy) =>
        viewport.globalToLocal(box.localToGlobal(Offset(0, dy))).dy +
        pos.pixels -
        pos.minScrollExtent;
    RenderSliverTurnStage? stage;
    viewport.visitChildren((child) {
      if (child is RenderSliverTurnStage) stage = child;
    });
    final next = _Geometry(
      total: pos.maxScrollExtent - pos.minScrollExtent + pos.viewportDimension,
      promptTop: content(prompt, 0),
      promptBottom: content(prompt, prompt.size.height),
      replyBottom: content(reply, reply.size.height),
      reserved: stage?.reservedTrailingSpace ?? 0,
      viewTop: pos.pixels - pos.minScrollExtent,
      viewport: pos.viewportDimension,
    );
    if (next != _geometry) setState(() => _geometry = next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final reply = _reply.substring(
      0,
      (_reply.length * _replyLength).round().clamp(0, _reply.length),
    );
    final items = <({String id, bool mine, String text, GlobalKey? key})>[
      for (final (i, line) in _history.indexed)
        (id: 'h$i', mine: i.isEven, text: line, key: null),
      (
        id: _promptId,
        mine: true,
        text: _tall ? _tallPrompt : _shortPrompt,
        key: _promptKey,
      ),
      (id: 'reply-$_turn', mine: false, text: reply, key: _replyKey),
    ];
    final geometry = _geometry;
    String px(double v) => '${v.round()} px';

    return ConceptPage(
      routeName: turnsPinningRouteName,
      lead:
          'When you send a prompt, its reply has not been written yet, so '
          'there is nothing below it to scroll to. SliverTurnStage reserves '
          'that room: the prompt can rest at the top while the reply is '
          'short, the reserved space shrinks as the reply grows, and the '
          'scroll extent stays put. Drag the reply length and watch the '
          'diagram. A prompt taller than the view scrolls up until half the '
          'view is free for the reply.',
      controls: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 200,
            child: PlaygroundChoice<bool>(
              label: 'Prompt',
              value: _tall,
              options: const {false: 'Short', true: 'Very long'},
              onChanged: (v) {
                _tall = v;
                _resend();
              },
            ),
          ),
          SizedBox(
            width: 200,
            child: PlaygroundToggle(
              key: const Key('concept.pinning.pin'),
              label: 'Pin the prompt',
              value: _pinning,
              onChanged: (v) {
                _pinning = v;
                _resend();
              },
            ),
          ),
          CoilButton(
            variant: CoilButtonVariant.secondary,
            size: CoilSize.compact,
            leading: const Icon(LucideIcons.send, size: 14),
            onPressed: _resend,
            child: const Text('Send again'),
          ),
          SizedBox(
            width: 320,
            child: CoilSlider(
              key: const Key('concept.pinning.reply'),
              value: _replyLength,
              size: CoilSize.compact,
              label: const Text('Reply written'),
              valueBuilder: (context, v) => Text('${(v * 100).round()} %'),
              semanticLabel: 'Reply written',
              onChanged: (v) => setState(() => _replyLength = v),
            ),
          ),
        ],
      ),
      stage: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: KeyedSubtree(
              key: _scrollKey,
              child: TurnScrollView<Object>(
                key: ValueKey(_turn),
                controller: _controller,
                itemCount: items.length,
                itemId: (i) => items[i].id,
                pinnedId: _pinning ? _promptId : null,
                itemSpacing: 12,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return KeyedSubtree(
                    key: item.key,
                    child: CoilChatMessage(
                      sender: item.mine
                          ? CoilChatSender.user
                          : CoilChatSender.assistant,
                      child: Text(item.text.isEmpty ? '…' : item.text),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 1, child: ColoredBox(color: colors.border)),
          SizedBox(width: 200, child: _ExtentDiagram(geometry: geometry)),
        ],
      ),
      stageHeight: 520,
      readout: ConceptStats(
        children: [
          ConceptStat(
            label: 'Reserved below the reply',
            value: geometry == null ? '–' : px(geometry.reserved),
            tone: ConceptTone.good,
          ),
          ConceptStat(
            label: 'maxScrollExtent',
            value: geometry == null ? '–' : px(geometry.maxScroll),
          ),
          ConceptStat(
            label: 'Reply height',
            value: geometry == null
                ? '–'
                : px(geometry.replyBottom - geometry.promptBottom),
          ),
        ],
      ),
      code: _code,
    );
  }
}

/// The whole scroll extent to scale: history, prompt, reply and reserved
/// space stacked, with the viewport outlined on top.
class _ExtentDiagram extends StatelessWidget {
  const _ExtentDiagram({required this.geometry});

  final _Geometry? geometry;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final geometry = this.geometry;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Scroll extent, to scale', style: text.muted.micro),
          const SizedBox(height: 8),
          Expanded(
            child: geometry == null
                ? const SizedBox.shrink()
                : CustomPaint(
                    size: Size.infinite,
                    painter: _DiagramPainter(
                      geometry: geometry,
                      history: colors.muted,
                      prompt: colors.brandFill,
                      reply: colors.brandWash,
                      reserved: colors.brandMark,
                      viewport: colors.foreground,
                      labelStyle: text.micro,
                      mutedStyle: text.muted.micro,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DiagramPainter extends CustomPainter {
  const _DiagramPainter({
    required this.geometry,
    required this.history,
    required this.prompt,
    required this.reply,
    required this.reserved,
    required this.viewport,
    required this.labelStyle,
    required this.mutedStyle,
  });

  final _Geometry geometry;
  final Color history;
  final Color prompt;
  final Color reply;
  final Color reserved;
  final Color viewport;
  final TextStyle labelStyle;
  final TextStyle mutedStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 44.0;
    final g = geometry;
    final scale = size.height / math.max(1, g.total);
    double y(double v) => v * scale;
    Rect band(double from, double to) => Rect.fromLTRB(
      0,
      y(from),
      barWidth,
      math.max(y(to), y(from) + 1),
    );

    final reservedTop = g.replyBottom;
    final reservedBottom = reservedTop + g.reserved;
    final segments = [
      (band(0, g.promptTop), history, 'History'),
      (band(g.promptTop, g.promptBottom), prompt, 'Prompt'),
      (band(g.promptBottom, g.replyBottom), reply, 'Reply'),
    ];
    for (final (rect, color, _) in segments) {
      canvas.drawRect(rect, Paint()..color = color);
    }
    if (g.reserved > 0.5) {
      final rect = band(reservedTop, reservedBottom);
      canvas
        ..save()
        ..clipRect(rect);
      final hatch = Paint()
        ..color = reserved.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      for (var v = rect.top - barWidth; v < rect.bottom; v += 5) {
        canvas.drawLine(Offset(0, v + barWidth), Offset(barWidth, v), hatch);
      }
      canvas
        ..restore()
        ..drawRect(
          rect,
          Paint()
            ..color = reserved
            ..style = PaintingStyle.stroke,
        );
    }

    // The viewport: what is on screen right now.
    final view = Rect.fromLTRB(
      -4,
      y(g.viewTop),
      barWidth + 4,
      y(g.viewTop + g.viewport),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(view, const Radius.circular(3)),
      Paint()
        ..color = viewport
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Labels, nudged apart so they don't overlap.
    var lastBottom = -100.0;
    void label(String text, double at, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - barWidth - 12);
      final top = math.max(at - painter.height / 2, lastBottom + 2);
      painter.paint(canvas, Offset(barWidth + 12, top));
      lastBottom = top + painter.height;
    }

    label('History', y(g.promptTop / 2), mutedStyle);
    label('Prompt', y((g.promptTop + g.promptBottom) / 2), labelStyle);
    label('Reply', y((g.promptBottom + g.replyBottom) / 2), labelStyle);
    if (g.reserved > 0.5) {
      label(
        'Reserved\n${g.reserved.round()} px',
        y((reservedTop + reservedBottom) / 2),
        labelStyle,
      );
    }
    label('Viewport', y(g.viewTop + g.viewport / 2), mutedStyle);
  }

  @override
  bool shouldRepaint(_DiagramPainter old) =>
      old.geometry != geometry ||
      old.history != history ||
      old.viewport != viewport;
}
