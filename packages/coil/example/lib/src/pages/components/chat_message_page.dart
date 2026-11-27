import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/chat_widgets.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';
import 'package:turns/turns.dart';

const chatMessageEntry = CatalogEntry(
  slug: 'chat-message',
  title: 'ChatMessage',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'A bubble for the person, plain text for the assistant.',
  page: ChatMessagePage.new,
);

const _question = 'Can you summarize the design review?';

const _reviewReplies = <String>[
  '''
Three changes came out of the review:

- **Tighter exits.** Dismiss springs settle sooner than entrances.
- **One row height.** Menus and selects now share a single row.
- **Sheets on phones.** Forms open in a sheet instead of a popover.''',
  '''
The review settled on three things:

- **Exits.** They run on shorter springs than entrances do.
- **Rows.** Every menu and select uses the same row height.
- **Phones.** Forms move into sheets, popovers stay on desktop.''',
];

const _motionWalkthroughReply = '''
Coil separates **spatial** springs from **fade** timings so transcripts feel calm even while tokens arrive:

1. **Entrances (`CoilChatMessageEntrance.animated`)** rise 8 px and scale from `96%` out of the sender's corner for newly arriving messages.
2. **History (`CoilChatMessageEntrance.none`)** skips the spring on preloaded turns so scrolling back never replays animations.
3. **Turn pinning (`TurnScrollView`)** anchors your prompt to top clearance with `CoilTheme.motionOf(context).standard` and releases immediately if you scroll away.''';

class ChatMessagePage extends StatefulWidget {
  const ChatMessagePage({super.key});

  @override
  State<ChatMessagePage> createState() => _ChatMessagePageState();
}

enum _Sender {
  user('User', CoilChatSender.user),
  assistant('Assistant', CoilChatSender.assistant);

  const _Sender(this.label, this.sender);

  final String label;
  final CoilChatSender sender;
}

class _ChatMessagePageState extends State<ChatMessagePage> {
  var _sender = _Sender.assistant;
  var _time = true;
  var _actions = true;
  var _attachment = false;
  var _run = 0;
  final _copy = CoilCopyController();

  @override
  void dispose() {
    _copy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _sender == _Sender.user;
    final text = user ? _question : _reviewReplies.first;
    return CatalogPage(
      title: 'ChatMessage',
      summary:
          'Messages in a transcript, as a bubble for the person and plain '
          'text for the assistant. Their actions appear on hover, or after a '
          'long press on touch.',
      hero: const _Conversation(),
      usage: '''
CoilChatMessage(
  sender: CoilChatSender.assistant,
  time: Text('10:42'),
  timeLabel: '10:42',
  actions: [
    CoilChatMessageAction(
      label: Text('Copy'),
      // The icon names the button, as in an IconButton.
      icon: Semantics(
        label: 'Copy',
        child: CoilCopyGlyph.listening(controller: copy),
      ),
      onPressed: () => copy.copy(reply, context: context),
    ),
  ],
  child: CoilMarkdown(reply, streaming: isStreaming),
)''',
      notes: const [
        CatalogNote(
          'Pointer',
          'The meta row appears on hover, and stays while one of its actions '
              'has keyboard focus.',
        ),
        CatalogNote(
          'Touch',
          'The meta row is always visible, and a long press opens the same '
              'actions as a menu.',
        ),
        CatalogNote(
          'Motion',
          'A new message fades in, rising 8 px and scaling up from 96% out '
              'of its sender corner on a spring, while the ones above it slide '
              'to make room. Use an entrance of none for messages that were '
              'already in the transcript.',
        ),
        CatalogNote(
          'Scrolling',
          'Pair CoilChatMessage with TurnScrollView from package:turns to pin '
              'each new user turn at top clearance while replies stream in, '
              'without ever fighting a reader who scrolls up.',
        ),
        CatalogNote(
          'Accessibility',
          'Each message is a single container labeled with its sender and '
              'time, and Copy uses the shared copy feedback, so its icon '
              'turns into a check.',
        ),
      ],
      children: [
        DemoSection(
          title: 'Playground',
          controls: DemoControls(
            children: [
              DemoControl.choice(
                label: 'Sender',
                value: _sender,
                values: _Sender.values,
                labelOf: (v) => v.label,
                onChanged: (v) => setState(() {
                  _sender = v;
                  _run++;
                }),
              ),
              DemoControl.toggle(
                label: 'Time',
                value: _time,
                onChanged: (v) => setState(() => _time = v),
              ),
              DemoControl.toggle(
                label: 'Actions',
                value: _actions,
                onChanged: (v) => setState(() => _actions = v),
              ),
              DemoControl.toggle(
                label: 'Attachment',
                value: _attachment,
                onChanged: (v) => setState(() => _attachment = v),
              ),
              DemoControl(
                label: 'Entrance',
                child: CoilButton(
                  variant: CoilButtonVariant.secondary,
                  size: CoilSize.compact,
                  onPressed: () => setState(() => _run++),
                  child: const Text('Replay'),
                ),
              ),
            ],
          ),
          child: CoilChatMessage(
            key: ValueKey((_run, _sender)),
            sender: _sender.sender,
            time: _time ? const Text('10:42') : null,
            timeLabel: _time ? '10:42' : null,
            attachments: [
              if (_attachment)
                const CoilFileThumbnail(
                  name: 'dunes.jpg',
                  dimension: 80,
                  image: AssetImage('assets/images/dunes.jpg'),
                ),
            ],
            actions: [
              if (_actions)
                CoilChatMessageAction(
                  label: const Text('Copy'),
                  icon: Semantics(
                    label: 'Copy',
                    child: CoilCopyGlyph.listening(controller: _copy),
                  ),
                  onPressed: () =>
                      unawaited(_copy.copy(text, context: context)),
                ),
            ],
            child: user
                ? const Text(_question)
                : CoilMarkdown(_reviewReplies.first),
          ),
        ),
      ],
    );
  }
}

class _StepItem {
  const _StepItem({
    required this.id,
    required this.title,
    required this.status,
    this.detail,
    this.sources = const [],
  });

  final String id;
  final String title;
  final String? detail;
  final List<String> sources;
  final CoilThinkingStepStatus status;

  _StepItem copyWith({CoilThinkingStepStatus? status}) => _StepItem(
    id: id,
    title: title,
    detail: detail,
    sources: sources,
    status: status ?? this.status,
  );
}

class _ChatItem {
  const _ChatItem({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.promptId,
    this.thinkingLabel,
    this.thinkingSteps = const [],
    this.streaming = false,
  });

  final String id;
  final CoilChatSender sender;
  final String text;
  final String time;
  final String? promptId;
  final String? thinkingLabel;
  final List<_StepItem> thinkingSteps;
  final bool streaming;

  _ChatItem copyWith({
    String? text,
    String? thinkingLabel,
    List<_StepItem>? thinkingSteps,
    bool? streaming,
  }) => _ChatItem(
    id: id,
    sender: sender,
    text: text ?? this.text,
    time: time,
    promptId: promptId,
    thinkingLabel: thinkingLabel ?? this.thinkingLabel,
    thinkingSteps: thinkingSteps ?? this.thinkingSteps,
    streaming: streaming ?? this.streaming,
  );
}

/// A live [TurnScrollView] transcript: copy or retry any assistant answer, or
/// type a follow-up that pins at top clearance while the reply streams in.
class _Conversation extends StatefulWidget {
  const _Conversation();

  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  final _controller = TurnScrollController();
  final _copyControllers = <String, CoilCopyController>{};
  final _freshIds = <String>{};
  final _expandedThinking = <String, bool>{};
  final _timers = <Timer>[];

  late List<_ChatItem> _messages;
  var _retryVariant = 0;
  var _nextTurn = 3;

  String? _pinnedId;
  String? _streamingId;
  Timer? _thinkingTimer;
  Timer? _streamTimer;

  bool get _isStreaming => _streamingId != null;

  @override
  void initState() {
    super.initState();
    _messages = [
      const _ChatItem(
        id: 'chat-u-1',
        sender: CoilChatSender.user,
        time: '10:38',
        text: 'How do Coil message entrances behave inside a long thread?',
      ),
      const _ChatItem(
        id: 'chat-a-1',
        sender: CoilChatSender.assistant,
        time: '10:38',
        promptId: 'chat-u-1',
        text:
            'Preloaded history mounts with `CoilChatMessageEntrance.none` so '
            'scrolling never replays old springs. Only newly sent prompts and '
            'incoming replies use `.animated`.',
      ),
      const _ChatItem(
        id: 'chat-u-2',
        sender: CoilChatSender.user,
        time: '10:41',
        text: _question,
      ),
      _ChatItem(
        id: 'chat-a-2',
        sender: CoilChatSender.assistant,
        time: '10:42',
        promptId: 'chat-u-2',
        thinkingLabel: 'Thought for 1.2s',
        thinkingSteps: const [
          _StepItem(
            id: 'notes',
            title: 'Read design review notes',
            sources: ['review-notes.md'],
            status: CoilThinkingStepStatus.done,
          ),
          _StepItem(
            id: 'group',
            title: 'Grouped decisions into three changes',
            status: CoilThinkingStepStatus.done,
          ),
        ],
        text: _reviewReplies.first,
      ),
    ];
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _streamTimer?.cancel();
    for (final timer in _timers) {
      timer.cancel();
    }
    for (final copy in _copyControllers.values) {
      copy.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  CoilCopyController _copyFor(String id) =>
      _copyControllers.putIfAbsent(id, CoilCopyController.new);

  void _markFresh(String id) {
    _freshIds.add(id);
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 900), () {
      _timers.remove(timer);
      if (!mounted) return;
      _freshIds.remove(id);
    });
    _timers.add(timer);
  }

  void _updateMessage(
    String id,
    _ChatItem Function(_ChatItem current) transform,
  ) {
    _messages = [
      for (final message in _messages)
        if (message.id == id) transform(message) else message,
    ];
  }

  void _stopStreaming() {
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
    _streamTimer?.cancel();
    _streamTimer = null;
    final activeId = _streamingId;
    if (activeId == null) return;
    setState(() {
      _streamingId = null;
      _expandedThinking[activeId] = false;
      _updateMessage(
        activeId,
        (m) => m.copyWith(
          streaming: false,
          text: m.text.isEmpty ? '_Stopped._' : m.text,
          thinkingLabel: m.thinkingSteps.isEmpty ? null : 'Stopped',
          thinkingSteps: [
            for (final step in m.thinkingSteps)
              step.copyWith(status: CoilThinkingStepStatus.done),
          ],
        ),
      );
    });
  }

  void _retry(_ChatItem target) {
    if (_isStreaming) _stopStreaming();
    _retryVariant = (_retryVariant + 1) % _reviewReplies.length;
    final nextReply = target.id == 'chat-a-2'
        ? _reviewReplies[_retryVariant]
        : 'Re-phrased take:\n\n'
              '- **Preloaded history** stays still (`Entrance.none`).\n'
              '- **New turns** spring in cleanly while `TurnScrollView` '
              'anchors the prompt.\n'
              '- **Streaming tokens** never yank the viewport back down if you '
              'scroll up.';

    const steps = <_StepItem>[
      _StepItem(
        id: 're-read',
        title: 'Re-reading review notes',
        sources: ['review-notes.md'],
        status: CoilThinkingStepStatus.running,
      ),
      _StepItem(
        id: 'rewrite',
        title: 'Tightening summary phrasing',
        status: CoilThinkingStepStatus.running,
      ),
    ];

    _expandedThinking[target.id] = true;
    setState(() {
      _pinnedId = target.promptId;
      _streamingId = target.id;
      _updateMessage(
        target.id,
        (m) => m.copyWith(
          text: '',
          thinkingLabel: 'Retrying…',
          thinkingSteps: [steps.first],
          streaming: true,
        ),
      );
    });

    _runThinkingAndStream(
      assistantId: target.id,
      steps: steps,
      reply: nextReply,
    );
  }

  /// A reply that fits what was typed, so the demo answers like a chat
  /// instead of from buttons.
  static String _replyFor(String prompt) {
    final words = [
      for (final m in RegExp('[a-z;]+').allMatches(prompt.toLowerCase())) m[0]!,
    ];
    // Stems match word starts, so "pin" finds "pinning" but not "spin".
    bool mentions(List<String> stems) =>
        stems.any((stem) => words.any((w) => w.startsWith(stem)));
    if (mentions(['motion', 'spring', 'animat', 'entrance', 'pin', 'scroll'])) {
      return _motionWalkthroughReply;
    }
    if (mentions([
      'recap',
      'summar',
      'tl;dr',
      'tldr',
      'short',
      'paragraph',
      'brief',
    ])) {
      return 'The review converged on **tighter exit springs**, a **single '
          'shared row height** for menus and selects, and **bottom sheets on '
          'phones** so touch forms stay easy to reach.';
    }
    if (mentions(['review', 'decision', 'change', 'design'])) {
      return _reviewReplies[1];
    }
    if (words.length <= 3 && mentions(['hi', 'hello', 'hey', 'thank'])) {
      return 'Happy to help. Ask me to **recap the review**, or how '
          '**message motion** and **turn pinning** work together.';
    }
    final quoted = prompt.replaceAll('"', "'");
    return 'Here is a quick take on **"$quoted"**:\n\n'
        '- Your message is pinned near the top while this reply streams '
        'in below it.\n'
        '- Scroll up mid-reply and the view stays where you put it; '
        '**Jump to latest** brings you back.\n'
        '- Hover or long-press a finished reply to copy or retry it.';
  }

  void _sendPrompt(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;
    if (_isStreaming) _stopStreaming();

    final turn = _nextTurn++;
    final userId = 'chat-u-$turn';
    final assistantId = 'chat-a-$turn';
    final time = '10:${(41 + turn).toString().padLeft(2, '0')}';

    const steps = <_StepItem>[
      _StepItem(
        id: 'context',
        title: 'Reading thread context',
        detail: 'Pins your prompt at top clearance via TurnScrollView.',
        sources: ['ChatMessage', 'turns'],
        status: CoilThinkingStepStatus.running,
      ),
      _StepItem(
        id: 'compose',
        title: 'Streaming markdown reply',
        status: CoilThinkingStepStatus.running,
      ),
    ];

    final reply = _replyFor(trimmed);

    _markFresh(userId);
    _markFresh(assistantId);
    _expandedThinking[assistantId] = true;

    setState(() {
      _messages = [
        ..._messages,
        _ChatItem(
          id: userId,
          sender: CoilChatSender.user,
          text: trimmed,
          time: time,
        ),
        _ChatItem(
          id: assistantId,
          sender: CoilChatSender.assistant,
          text: '',
          time: time,
          promptId: userId,
          thinkingLabel: 'Thinking…',
          thinkingSteps: [steps.first],
          streaming: true,
        ),
      ];
      _pinnedId = userId;
      _streamingId = assistantId;
    });

    _runThinkingAndStream(
      assistantId: assistantId,
      steps: steps,
      reply: reply,
    );
  }

  void _runThinkingAndStream({
    required String assistantId,
    required List<_StepItem> steps,
    required String reply,
  }) {
    var revealed = 1;
    _thinkingTimer?.cancel();
    _thinkingTimer = Timer.periodic(const Duration(milliseconds: 340), (timer) {
      if (!mounted || _streamingId != assistantId) {
        timer.cancel();
        return;
      }
      if (revealed < steps.length) {
        revealed++;
        final nextSteps = <_StepItem>[
          for (var i = 0; i < revealed; i++)
            if (i < revealed - 1)
              steps[i].copyWith(status: CoilThinkingStepStatus.done)
            else
              steps[i],
        ];
        setState(() {
          _updateMessage(
            assistantId,
            (m) => m.copyWith(thinkingSteps: nextSteps),
          );
        });
        return;
      }
      timer.cancel();
      _thinkingTimer = null;
      final completed = [
        for (final step in steps)
          step.copyWith(status: CoilThinkingStepStatus.done),
      ];
      setState(() {
        _expandedThinking[assistantId] = false;
        _updateMessage(
          assistantId,
          (m) => m.copyWith(
            thinkingLabel: 'Thought for 1.1s',
            thinkingSteps: completed,
          ),
        );
      });

      var cursor = 0;
      _streamTimer?.cancel();
      _streamTimer = Timer.periodic(const Duration(milliseconds: 24), (t) {
        if (!mounted || _streamingId != assistantId) {
          t.cancel();
          return;
        }
        cursor = math.min(reply.length, cursor + 8);
        final done = cursor >= reply.length;
        final slice = reply.substring(0, cursor);
        setState(() {
          _updateMessage(
            assistantId,
            (m) => m.copyWith(text: slice, streaming: !done),
          );
          if (done) {
            _streamingId = null;
          }
        });
        if (done) {
          t.cancel();
          _streamTimer = null;
        }
      });
    });
  }

  Widget _buildMessage(BuildContext context, _ChatItem item) {
    final entrance = _freshIds.contains(item.id)
        ? CoilChatMessageEntrance.animated
        : CoilChatMessageEntrance.none;
    final copy = _copyFor(item.id);

    if (item.sender == CoilChatSender.user) {
      return CoilChatMessage(
        sender: CoilChatSender.user,
        entrance: entrance,
        time: Text(item.time),
        timeLabel: item.time,
        actions: [
          CoilChatMessageAction(
            label: const Text('Copy'),
            icon: Semantics(
              label: 'Copy',
              child: CoilCopyGlyph.listening(controller: copy),
            ),
            onPressed: () => unawaited(copy.copy(item.text, context: context)),
          ),
        ],
        child: Text(item.text),
      );
    }

    final expanded = _expandedThinking[item.id] ?? false;
    return CoilChatMessage(
      sender: CoilChatSender.assistant,
      entrance: entrance,
      time: item.streaming ? const Text('Streaming…') : Text(item.time),
      timeLabel: item.streaming ? 'Streaming' : item.time,
      actions: [
        if (!item.streaming && item.text.isNotEmpty) ...[
          CoilChatMessageAction(
            label: const Text('Copy'),
            icon: Semantics(
              label: 'Copy',
              child: CoilCopyGlyph.listening(controller: copy),
            ),
            onPressed: () => unawaited(copy.copy(item.text, context: context)),
          ),
          CoilChatMessageAction(
            label: const Text('Retry'),
            icon: const CatalogIcon(Glyph.refresh, semanticLabel: 'Retry'),
            onPressed: () => _retry(item),
          ),
        ],
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.thinkingSteps.isNotEmpty) ...[
            CoilThinkingSteps(
              label: Text(item.thinkingLabel ?? 'Thinking…'),
              expanded: expanded,
              onChanged: (v) => setState(() => _expandedThinking[item.id] = v),
              steps: [
                for (final step in item.thinkingSteps)
                  CoilThinkingStep(
                    key: ValueKey('${item.id}.${step.id}'),
                    title: Text(step.title),
                    detail: step.detail == null ? null : Text(step.detail!),
                    sources: [for (final s in step.sources) Text(s)],
                    status: step.status,
                  ),
              ],
            ),
            if (item.text.isNotEmpty) const SizedBox(height: 8),
          ],
          if (item.text.isNotEmpty)
            CoilMarkdown(
              item.text,
              streaming: item.streaming,
              trailing: item.streaming ? const ChatStreamingCaret() : null,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    final motion = CoilTheme.motionOf(context);
    return SizedBox(
      height: touch ? 480 : 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Expanded(
            child: Stack(
              children: [
                CoilScrollArea(
                  controller: _controller,
                  edgeFades: CoilEdgeFades.none,
                  keyboard: false,
                  child: TurnScrollView<Object>(
                    controller: _controller,
                    itemCount: _messages.length,
                    itemId: (i) => _messages[i].id,
                    pinnedId: _pinnedId,
                    autoScrollMotion: motion.standard,
                    applyTopPadding: false,
                    applyBottomPadding: false,
                    itemSpacing: 16,
                    jumpThreshold: 80,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemBuilder: (context, index) =>
                        _buildMessage(context, _messages[index]),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(
                    child: ChatJumpToBottomButton(controller: _controller),
                  ),
                ),
              ],
            ),
          ),
          CoilInputMessage(
            status: _isStreaming
                ? CoilMessageStatus.streaming
                : CoilMessageStatus.idle,
            placeholder: const Text('Ask about the review, motion or pinning…'),
            onSend: _sendPrompt,
            onStop: _stopStreaming,
          ),
          const ChatTurnsCredit(),
        ],
      ),
    );
  }
}
