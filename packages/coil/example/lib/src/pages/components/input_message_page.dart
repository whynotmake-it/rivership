import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/composer_demo.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/chat_widgets.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';
import 'package:turns/turns.dart';

const inputMessageEntry = CatalogEntry(
  slug: 'input-message',
  title: 'InputMessage',
  group: CatalogGroup.shellAndComposites,
  summary:
      'A chat composer where Enter sends the message, and on touch Return '
      'starts a new line instead.',
  page: InputMessagePage.new,
);

class InputMessagePage extends StatefulWidget {
  const InputMessagePage({super.key});

  @override
  State<InputMessagePage> createState() => _InputMessagePageState();
}

class _InputMessagePageState extends State<InputMessagePage> {
  var _compact = false;
  var _enabled = true;
  var _streaming = false;
  var _files = <DemoFile>[];

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'InputMessage',
    summary:
        'Enter sends the message and Shift+Enter breaks the line, while on '
        'touch Return starts a new line and the button sends. The same '
        'button stops the answer while a reply is streaming in.',
    hero: const _Conversation(),
    usage: '''
CoilInputMessage(
  status: replying
      ? CoilMessageStatus.streaming
      : CoilMessageStatus.idle,
  onSend: send,
  onStop: stop,
  attachments: attachments,
  leading: attachButton,
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Enter sends the message and Shift+Enter inserts a newline. Pressing '
            'Up in an empty field brings back the last message you sent.',
      ),
      CatalogNote(
        'Touch',
        'Return inserts a newline, so sending goes through the button. The '
            'remove button on an attachment tile is always visible and keeps '
            'a 44 px hit target.',
      ),
      CatalogNote(
        'Motion',
        'The attachment tray springs open smoothly and fades its contents '
            'in, and the send button morphs between its send, stop, and queue '
            'shapes.',
      ),
      CatalogNote(
        'Scrolling',
        'Place CoilInputMessage below a TurnScrollView from package:turns so '
            'each sent prompt pins cleanly at top clearance while the reply '
            'streams in.',
      ),
      CatalogNote(
        'Accessibility',
        'The field is announced as a multiline text field labeled "Message", '
            'and the button’s label follows whatever it currently does, so it '
            'reads as Send, Stop, or Queue message.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        controls: DemoControls(
          children: [
            DemoControl.toggle(
              label: 'Streaming',
              value: _streaming,
              onChanged: (v) => setState(() => _streaming = v),
            ),
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
            DemoControl.toggle(
              label: 'Enabled',
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
        ),
        child: CoilInputMessage(
          size: _compact ? CoilSize.compact : CoilSize.regular,
          enabled: _enabled,
          status: _streaming
              ? CoilMessageStatus.streaming
              : CoilMessageStatus.idle,
          onStop: () => setState(() => _streaming = false),
          onSend: (_) {},
          onQueue: (_) {},
          placeholder: const Text('Ask anything about the brief'),
          attachments: _files.isEmpty
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final file in _files)
                      demoThumbnail(
                        file,
                        onRemove: () => setState(
                          () => _files = [..._files]..remove(file),
                        ),
                      ),
                  ],
                ),
          leading: _AttachButton(
            files: _files,
            onChanged: (files) => setState(() => _files = files),
          ),
        ),
      ),
    ],
  );
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.files, required this.onChanged});

  final List<DemoFile> files;
  final ValueChanged<List<DemoFile>> onChanged;

  @override
  Widget build(BuildContext context) {
    final next = nextDemoFile(files);
    return CoilButton.icon(
      variant: CoilButtonVariant.ghost,
      size: CoilSize.compact,
      semanticLabel: 'Attach a file',
      icon: const CatalogIcon(Glyph.paperclip),
      onPressed: next == null ? null : () => onChanged([...files, next]),
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

class _MessageItem {
  const _MessageItem({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.files = const [],
    this.thinkingLabel,
    this.thinkingSteps = const [],
    this.streaming = false,
  });

  final String id;
  final CoilChatSender sender;
  final String text;
  final String time;
  final List<DemoFile> files;
  final String? thinkingLabel;
  final List<_StepItem> thinkingSteps;
  final bool streaming;

  _MessageItem copyWith({
    String? text,
    String? thinkingLabel,
    List<_StepItem>? thinkingSteps,
    bool? streaming,
  }) => _MessageItem(
    id: id,
    sender: sender,
    text: text ?? this.text,
    time: time,
    files: files,
    thinkingLabel: thinkingLabel ?? this.thinkingLabel,
    thinkingSteps: thinkingSteps ?? this.thinkingSteps,
    streaming: streaming ?? this.streaming,
  );
}

/// A live [TurnScrollView] conversation: attach files, or
/// type a reply and watch the assistant think and stream markdown back.
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

  late List<_MessageItem> _messages;
  var _files = <DemoFile>[];
  var _nextTurn = 3;

  String? _pinnedId;
  String? _streamingId;
  Timer? _thinkingTimer;
  Timer? _streamTimer;

  bool get _isStreaming => _streamingId != null;

  @override
  void initState() {
    super.initState();
    _messages = const [
      _MessageItem(
        id: 'input-u-1',
        sender: CoilChatSender.user,
        time: '11:02',
        text: 'Can you scan the launch brief before Thursday?',
      ),
      _MessageItem(
        id: 'input-a-1',
        sender: CoilChatSender.assistant,
        time: '11:02',
        text:
            'Ready whenever you are. I will check **scope**, **pricing**, and '
            '**release owners** first.',
      ),
      _MessageItem(
        id: 'input-u-2',
        sender: CoilChatSender.user,
        time: '11:04',
        text: 'Which sections of the launch brief need the most work?',
      ),
      _MessageItem(
        id: 'input-a-2',
        sender: CoilChatSender.assistant,
        time: '11:04',
        thinkingLabel: 'Thought for 1.0s',
        thinkingSteps: [
          _StepItem(
            id: 'brief',
            title: 'Scanned launch brief outline',
            sources: ['launch-brief.md'],
            status: CoilThinkingStepStatus.done,
          ),
        ],
        text:
            'The intro is solid, while two sections need a quick pass:\n\n'
            '- **Pricing:** Add the team seat cap and annual discount.\n'
            '- **Timeline:** Name one owner per launch milestone.\n\n'
            'Attach the latest draft below and I will mark it up.',
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
    _MessageItem Function(_MessageItem current) transform,
  ) {
    _messages = [
      for (final message in _messages)
        if (message.id == id) transform(message) else message,
    ];
  }

  /// A reply that fits what was typed, so the demo answers like a chat
  /// instead of from buttons. Null falls back to the general pass.
  static String? _replyFor(String prompt) {
    final words = [
      for (final m in RegExp('[a-z]+').allMatches(prompt.toLowerCase())) m[0]!,
    ];
    bool mentions(List<String> stems) =>
        stems.any((stem) => words.any((w) => w.startsWith(stem)));
    if (mentions(['pric', 'plan', 'tier', 'seat', 'cost'])) {
      return '### Suggested pricing copy\n\n'
          '- **Starter:** Free for solo builders and up to 3 projects.\n'
          r'- **Team:** $18 / seat / month, billed annually (save 20%).'
          '\n'
          '- **Enterprise:** Custom SSO, audit logs, and dedicated support.';
    }
    if (mentions([
      'timeline',
      'milestone',
      'owner',
      'schedul',
      'date',
      'week',
    ])) {
      return '### Launch week owners\n\n'
          '| Milestone | Owner | Target |\n'
          '| :--- | :--- | :--- |\n'
          '| Pricing page sign-off | Maya | Tue 14:00 |\n'
          '| QA & accessibility pass | Devon | Wed 17:00 |\n'
          '| Production rollout | Priya | Thu 10:00 |';
    }
    return null;
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_isStreaming) _stop();

    final attached = List<DemoFile>.of(_files);
    final turn = _nextTurn++;
    final userId = 'input-u-$turn';
    final assistantId = 'input-a-$turn';
    final time = '11:${(4 + turn).toString().padLeft(2, '0')}';

    final steps = <_StepItem>[
      if (attached.isNotEmpty)
        _StepItem(
          id: 'files',
          title: 'Inspecting ${attached.map((f) => f.name).join(', ')}',
          sources: [for (final f in attached) f.name],
          status: CoilThinkingStepStatus.running,
        ),
      const _StepItem(
        id: 'review',
        title: 'Checking launch brief gaps',
        detail: 'Cross-checks pricing tiers and milestone owners.',
        sources: ['launch-brief.md'],
        status: CoilThinkingStepStatus.running,
      ),
      const _StepItem(
        id: 'draft',
        title: 'Drafting marked-up edits',
        status: CoilThinkingStepStatus.running,
      ),
    ];

    final reply =
        (attached.isEmpty ? _replyFor(trimmed) : null) ??
        (attached.isEmpty
            ? 'Here is a focused pass on '
                  '**"${trimmed.replaceAll('"', "'")}"**:\n\n'
                  '1. **Pricing:** Lead with the two plans teams compare most '
                  'and keep add-ons in a footnote.\n'
                  '2. **Owners:** Assign a single DRI to QA sign-off and '
                  'docs.\n'
                  '3. **Next:** Attach `brief.pdf` if you want inline copy '
                  'suggestions.'
            : 'I reviewed **${attached.map((f) => f.name).join(' and ')}** '
                  'against the brief:\n\n'
                  '- **Nothing blocks the launch.** Visual assets and copy '
                  'match the hero headline.\n'
                  '- **Pricing paragraph:** Tighten the second sentence and '
                  'state seat minimums explicitly.\n'
                  '- **Dates:** Add one owner beside each milestone before '
                  'sharing externally.');

    _markFresh(userId);
    _markFresh(assistantId);
    _expandedThinking[assistantId] = true;

    setState(() {
      _messages = [
        ..._messages,
        _MessageItem(
          id: userId,
          sender: CoilChatSender.user,
          text: trimmed,
          time: time,
          files: attached,
        ),
        _MessageItem(
          id: assistantId,
          sender: CoilChatSender.assistant,
          text: '',
          time: time,
          thinkingLabel: 'Reading…',
          thinkingSteps: [steps.first],
          streaming: true,
        ),
      ];
      _files = [];
      _pinnedId = userId;
      _streamingId = assistantId;
    });

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
            thinkingLabel:
                'Thought for ${(steps.length * 0.4 + 0.3).toStringAsFixed(1)}s',
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

  void _stop() {
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

  Widget _buildMessage(BuildContext context, _MessageItem item) {
    final entrance = _freshIds.contains(item.id)
        ? CoilChatMessageEntrance.animated
        : CoilChatMessageEntrance.none;

    if (item.sender == CoilChatSender.user) {
      return CoilChatMessage(
        sender: CoilChatSender.user,
        entrance: entrance,
        time: Text(item.time),
        timeLabel: item.time,
        attachments: [for (final file in item.files) demoThumbnail(file)],
        child: Text(item.text),
      );
    }

    final copy = _copyFor(item.id);
    final expanded = _expandedThinking[item.id] ?? false;

    return CoilChatMessage(
      sender: CoilChatSender.assistant,
      entrance: entrance,
      time: item.streaming ? const Text('Streaming…') : Text(item.time),
      timeLabel: item.streaming ? 'Streaming' : item.time,
      actions: [
        if (!item.streaming && item.text.isNotEmpty)
          CoilChatMessageAction(
            label: const Text('Copy'),
            icon: Semantics(
              label: 'Copy',
              child: CoilCopyGlyph.listening(controller: copy),
            ),
            onPressed: () => unawaited(copy.copy(item.text, context: context)),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.thinkingSteps.isNotEmpty) ...[
            CoilThinkingSteps(
              label: Text(item.thinkingLabel ?? 'Reading…'),
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
      height: touch ? 460 : 420,
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
            placeholder: const Text(
              'Ask about pricing, owners or the timeline…',
            ),
            onSend: _send,
            onStop: _stop,
            attachments: _files.isEmpty
                ? null
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final file in _files)
                        demoThumbnail(
                          file,
                          onRemove: () => setState(
                            () => _files = [..._files]..remove(file),
                          ),
                        ),
                    ],
                  ),
            leading: _AttachButton(
              files: _files,
              onChanged: (files) => setState(() => _files = files),
            ),
          ),
          const ChatTurnsCredit(),
        ],
      ),
    );
  }
}
