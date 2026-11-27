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

const queuedStackEntry = CatalogEntry(
  slug: 'queued-stack',
  title: 'QueuedStack',
  group: CatalogGroup.shellAndComposites,
  summary:
      'A pile above the composer that holds the messages you send while the '
      'assistant is still replying.',
  page: QueuedStackPage.new,
);

class QueuedStackPage extends StatelessWidget {
  const QueuedStackPage({super.key});

  @override
  Widget build(BuildContext context) => const CatalogPage(
    title: 'QueuedStack',
    summary:
        'Send something while the assistant is replying and the message '
        'waits in a pile above the composer. Hovering the pile, or tapping it '
        'on touch, fans it out so you can reorder, edit or remove what is '
        'still waiting.',
    hero: _Chat(),
    usage: '''
CoilQueuedStack(
  messages: queue,
  onChanged: (next) => setState(() => queue = next),
  onEdit: (message) => edit(message),
  child: transcript,
)''',
    notes: [
      CatalogNote(
        'Pointer',
        'Hovering the pile or moving focus into it fans the cards out. A card '
            'reveals its actions on hover, a double click edits it, and once '
            'the pile is fanned out you can drag a card to reorder it.',
      ),
      CatalogNote(
        'Touch',
        'A tap fans the pile out and keeps it open, and while two or more '
            'messages wait the gutter at the start turns into a collapse '
            'button. Each card shows its actions all the time on touch.',
      ),
      CatalogNote(
        'Keyboard',
        'Each card is its own tab stop, starting with the one at the front. '
            'Enter or F2 edits the card, Delete removes it, and Alt+Up and '
            'Alt+Down move it through the queue.',
      ),
      CatalogNote(
        'Motion',
        'The stack folds and fans out smoothly on a spring, and a message '
            'that lands behind a folded stack makes it recoil gently by '
            '7 px.',
      ),
      CatalogNote(
        "Do / Don't",
        'Give the stack a bounded height and pass a TurnScrollView or '
            'transcript as its child, because CoilQueuedStack adds the folded '
            'pile’s height to the child’s bottom MediaQuery padding so the '
            'last message never ends up underneath it.',
      ),
    ],
    children: [_Pile()],
  );
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

class _ChatMessage {
  const _ChatMessage({
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

  _ChatMessage copyWith({
    String? text,
    String? thinkingLabel,
    List<_StepItem>? thinkingSteps,
    bool? streaming,
  }) => _ChatMessage(
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

const _overviewStreamReply = '''
Starting with the **overview screen** — three quick wins stand out:

1. **Card rhythm:** Align every summary card to the 16 px grid and unify padding.
2. **KPI labels:** Raise muted caption contrast so secondary stats stay crisp in dark mode.
3. **Header density:** Move secondary filters into a compact toolbar row.''';

/// A live [TurnScrollView] chat with a paused reply in progress and three
/// queued follow-ups ready to fan out, reorder, edit, or stream through.
class _Chat extends StatefulWidget {
  const _Chat();

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _controller = TurnScrollController();
  final _composer = TextEditingController();
  final _copyControllers = <String, CoilCopyController>{};
  final _freshIds = <String>{};
  final _expandedThinking = <String, bool>{};
  final _timers = <Timer>[];

  /// The text and files of each queued message, by id.
  final _texts = <Object, String>{};
  final _queuedFiles = <Object, List<DemoFile>>{};

  var _messages = <_ChatMessage>[];
  var _queue = <CoilQueuedMessage>[];
  var _files = <DemoFile>[];
  var _queueIds = 0;
  var _nextTurn = 4;

  String? _pinnedId;
  String? _activeAssistantId;
  String _activeFullReply = '';
  int _activeCursor = 0;
  List<_StepItem> _activeSteps = const [];
  int _revealedSteps = 0;

  var _replying = false;
  var _paused = true;
  Timer? _thinkingTimer;
  Timer? _streamTimer;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void dispose() {
    _cancelTimers();
    for (final copy in _copyControllers.values) {
      copy.dispose();
    }
    _controller.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
    _streamTimer?.cancel();
    _streamTimer = null;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
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
    _ChatMessage Function(_ChatMessage current) transform,
  ) {
    _messages = [
      for (final message in _messages)
        if (message.id == id) transform(message) else message,
    ];
  }

  /// A reply paused mid-thought with three messages waiting, so the pile
  /// reads at a glance without background timers running.
  void _seed() {
    _cancelTimers();
    _texts.clear();
    _queuedFiles.clear();
    _freshIds.clear();
    _expandedThinking.clear();

    const initialSteps = <_StepItem>[
      _StepItem(
        id: 'scan',
        title: 'Inspecting overview layout spacing',
        sources: ['overview_screen.dart'],
        status: CoilThinkingStepStatus.done,
      ),
      _StepItem(
        id: 'contrast',
        title: 'Checking muted label contrast ratios',
        detail: 'Paused — tap Resume reply to stream through the queue.',
        status: CoilThinkingStepStatus.done,
      ),
    ];

    _messages = const [
      _ChatMessage(
        id: 'q-u-1',
        sender: CoilChatSender.user,
        time: '14:10',
        text: 'Help me polish the dashboard design',
      ),
      _ChatMessage(
        id: 'q-a-1',
        sender: CoilChatSender.assistant,
        time: '14:10',
        text:
            'Happy to. The **spacing is uneven** and a few labels are hard to '
            'read. Want me to go through it screen by screen?',
      ),
      _ChatMessage(
        id: 'q-u-2',
        sender: CoilChatSender.user,
        time: '14:12',
        text: 'Yes, start with the overview screen',
      ),
      _ChatMessage(
        id: 'q-a-2',
        sender: CoilChatSender.assistant,
        time: '14:12',
        thinkingLabel: 'Paused — resume to stream',
        thinkingSteps: initialSteps,
        text: 'Starting with the **overview screen**…',
      ),
    ];
    _expandedThinking['q-a-2'] = true;

    _queue = [
      _queuedMessage('Fix spacing'),
      _queuedMessage('Match the mockups'),
      _queuedMessage('Audit the color contrast across the dashboard'),
    ];
    _pinnedId = null;
    _activeAssistantId = 'q-a-2';
    _activeFullReply = _overviewStreamReply;
    _activeCursor = 0;
    _activeSteps = initialSteps;
    _revealedSteps = initialSteps.length;
    _replying = true;
    _paused = true;
    _nextTurn = 3;
  }

  CoilQueuedMessage _queuedMessage(
    String text, [
    List<DemoFile> files = const [],
  ]) {
    final id = _queueIds++;
    _texts[id] = text;
    _queuedFiles[id] = files;
    return CoilQueuedMessage(
      id: id,
      child: Text(text),
      attachments: [
        for (final file in files)
          CoilFileThumbnail(name: file.name, image: file.image),
      ],
    );
  }

  void _queueMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _queue = [..._queue, _queuedMessage(trimmed, _files)];
      _files = [];
    });
  }

  String _replyFor(String prompt, List<DemoFile> files) {
    final lower = prompt.toLowerCase();
    if (lower.contains('spacing')) {
      return 'Tightened **card spacing** to a consistent `16 px` outer gutter '
          'and `12 px` internal gap across every overview section.';
    }
    if (lower.contains('mockup')) {
      return 'Aligned typography weights and header radii with the latest '
          'mockups — section titles now use semibold and chart cards share a '
          'single border token.';
    }
    if (lower.contains('contrast')) {
      return 'Audited text and badge tokens across light and dark themes:\n\n'
          '- Raised secondary captions to **AA (4.8:1)**.\n'
          '- Darkened focus rings so keyboard selection reads clearly.';
    }
    final fileNote = files.isEmpty
        ? ''
        : ' (with ${files.map((f) => f.name).join(', ')})';
    return 'Applied **"${prompt.replaceAll('"', "'")}"**$fileNote:\n\n'
        '- Anchored this turn in `TurnScrollView` while streaming.\n'
        '- Kept any remaining follow-ups safely stacked above the composer.';
  }

  void _send(String text, [List<DemoFile>? files]) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final attached = files ?? List<DemoFile>.of(_files);
    final turn = _nextTurn++;
    final userId = 'q-u-$turn';
    final assistantId = 'q-a-$turn';
    final time = '14:${(10 + turn).toString().padLeft(2, '0')}';

    final steps = <_StepItem>[
      _StepItem(
        id: 'analyze',
        title: 'Reviewing "$trimmed"',
        sources: [
          if (attached.isEmpty)
            'dashboard.dart'
          else
            ...attached.map((f) => f.name),
        ],
        status: CoilThinkingStepStatus.running,
      ),
      const _StepItem(
        id: 'apply',
        title: 'Streaming updated summary',
        status: CoilThinkingStepStatus.running,
      ),
    ];

    _markFresh(userId);
    _markFresh(assistantId);
    _expandedThinking[assistantId] = true;

    setState(() {
      _messages = [
        ..._messages,
        _ChatMessage(
          id: userId,
          sender: CoilChatSender.user,
          text: trimmed,
          time: time,
          files: attached,
        ),
        _ChatMessage(
          id: assistantId,
          sender: CoilChatSender.assistant,
          text: '',
          time: time,
          thinkingLabel: 'Thinking…',
          thinkingSteps: [steps.first],
          streaming: true,
        ),
      ];
      if (files == null) _files = [];
      _pinnedId = userId;
      _activeAssistantId = assistantId;
      _activeFullReply = _replyFor(trimmed, attached);
      _activeCursor = 0;
      _activeSteps = steps;
      _revealedSteps = 1;
      _replying = true;
      _paused = false;
    });

    _resumeActiveTurn();
  }

  void _togglePause() {
    if (!_replying) {
      setState(_seed);
      return;
    }
    if (_paused) {
      final activeId = _activeAssistantId;
      setState(() {
        _paused = false;
        if (activeId == 'q-a-2') {
          _pinnedId = 'q-u-2';
        }
        if (activeId != null) {
          _updateMessage(
            activeId,
            (m) => m.copyWith(
              streaming: true,
              thinkingLabel: _revealedSteps < _activeSteps.length
                  ? 'Thinking…'
                  : 'Thought for 1.1s',
            ),
          );
        }
      });
      _resumeActiveTurn();
    } else {
      _thinkingTimer?.cancel();
      _thinkingTimer = null;
      _streamTimer?.cancel();
      _streamTimer = null;
      final activeId = _activeAssistantId;
      setState(() {
        _paused = true;
        if (activeId != null) {
          _updateMessage(
            activeId,
            (m) => m.copyWith(
              streaming: false,
              thinkingLabel: 'Paused',
            ),
          );
        }
      });
    }
  }

  void _resumeActiveTurn() {
    final activeId = _activeAssistantId;
    if (activeId == null || _paused) return;

    if (_revealedSteps < _activeSteps.length) {
      _thinkingTimer?.cancel();
      _thinkingTimer = Timer.periodic(const Duration(milliseconds: 340), (
        timer,
      ) {
        if (!mounted || _paused || _activeAssistantId != activeId) {
          timer.cancel();
          return;
        }
        if (_revealedSteps < _activeSteps.length) {
          _revealedSteps++;
          final nextSteps = <_StepItem>[
            for (var i = 0; i < _revealedSteps; i++)
              if (i < _revealedSteps - 1)
                _activeSteps[i].copyWith(status: CoilThinkingStepStatus.done)
              else
                _activeSteps[i],
          ];
          setState(() {
            _updateMessage(
              activeId,
              (m) => m.copyWith(thinkingSteps: nextSteps),
            );
          });
          return;
        }
        timer.cancel();
        _thinkingTimer = null;
        final doneSteps = [
          for (final step in _activeSteps)
            step.copyWith(status: CoilThinkingStepStatus.done),
        ];
        setState(() {
          _expandedThinking[activeId] = false;
          _updateMessage(
            activeId,
            (m) => m.copyWith(
              thinkingLabel: 'Thought for 1.1s',
              thinkingSteps: doneSteps,
            ),
          );
        });
        _startTokenLoop(activeId);
      });
      return;
    }

    setState(() => _expandedThinking[activeId] = false);
    _startTokenLoop(activeId);
  }

  void _startTokenLoop(String assistantId) {
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(const Duration(milliseconds: 24), (timer) {
      if (!mounted || _paused || _activeAssistantId != assistantId) {
        timer.cancel();
        return;
      }
      _activeCursor = math.min(_activeFullReply.length, _activeCursor + 8);
      final done = _activeCursor >= _activeFullReply.length;
      final slice = _activeFullReply.substring(0, _activeCursor);
      setState(() {
        _updateMessage(
          assistantId,
          (m) => m.copyWith(text: slice, streaming: !done),
        );
        if (done) {
          _replying = false;
          _activeAssistantId = null;
        }
      });
      if (done) {
        timer.cancel();
        _streamTimer = null;
        _drainNextQueued();
      }
    });
  }

  void _drainNextQueued() {
    if (_queue.isEmpty) return;
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 650), () {
      _timers.remove(timer);
      if (!mounted || _replying || _queue.isEmpty) return;
      final next = _queue.first;
      final text = _texts.remove(next.id);
      final files = _queuedFiles.remove(next.id) ?? const <DemoFile>[];
      setState(() => _queue = _queue.sublist(1));
      if (text != null) {
        _send(text, files);
      }
    });
    _timers.add(timer);
  }

  void _stop() {
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
    _streamTimer?.cancel();
    _streamTimer = null;
    final activeId = _activeAssistantId;
    setState(() {
      _replying = false;
      _paused = false;
      _activeAssistantId = null;
      if (activeId != null) {
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
      }
    });
  }

  void _edit(CoilQueuedMessage message) => setState(() {
    _composer.text = _texts.remove(message.id)!;
    _files = _queuedFiles.remove(message.id) ?? [];
    _queue = [
      for (final m in _queue)
        if (m.id != message.id) m,
    ];
  });

  Widget _buildMessage(BuildContext context, _ChatMessage message) {
    final entrance = _freshIds.contains(message.id)
        ? CoilChatMessageEntrance.animated
        : CoilChatMessageEntrance.none;

    if (message.sender == CoilChatSender.user) {
      return CoilChatMessage(
        sender: CoilChatSender.user,
        entrance: entrance,
        time: Text(message.time),
        timeLabel: message.time,
        attachments: [for (final file in message.files) demoThumbnail(file)],
        child: Text(message.text),
      );
    }

    final copy = _copyFor(message.id);
    final expanded = _expandedThinking[message.id] ?? false;

    return CoilChatMessage(
      sender: CoilChatSender.assistant,
      entrance: entrance,
      time: message.streaming ? const Text('Streaming…') : Text(message.time),
      timeLabel: message.streaming ? 'Streaming' : message.time,
      actions: [
        if (!message.streaming && message.text.isNotEmpty)
          CoilChatMessageAction(
            label: const Text('Copy'),
            icon: Semantics(
              label: 'Copy',
              child: CoilCopyGlyph.listening(controller: copy),
            ),
            onPressed: () =>
                unawaited(copy.copy(message.text, context: context)),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.thinkingSteps.isNotEmpty) ...[
            CoilThinkingSteps(
              label: Text(message.thinkingLabel ?? 'Thinking…'),
              expanded: expanded,
              onChanged: (v) =>
                  setState(() => _expandedThinking[message.id] = v),
              steps: [
                for (final step in message.thinkingSteps)
                  CoilThinkingStep(
                    key: ValueKey('${message.id}.${step.id}'),
                    title: Text(step.title),
                    detail: step.detail == null ? null : Text(step.detail!),
                    sources: [for (final s in step.sources) Text(s)],
                    status: step.status,
                  ),
              ],
            ),
            if (message.text.isNotEmpty) const SizedBox(height: 8),
          ],
          if (message.text.isNotEmpty)
            CoilMarkdown(
              message.text,
              streaming: message.streaming,
              trailing: message.streaming ? const ChatStreamingCaret() : null,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    final motion = CoilTheme.motionOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            CoilButton(
              variant: CoilButtonVariant.secondary,
              size: CoilSize.compact,
              leading: CatalogIcon(
                !_replying
                    ? Glyph.rotate
                    : _paused
                    ? Glyph.play
                    : Glyph.pause,
              ),
              onPressed: _togglePause,
              child: Text(
                !_replying
                    ? 'Start over'
                    : _paused
                    ? 'Resume reply'
                    : 'Pause reply',
              ),
            ),
            if (!_replying && _queue.isNotEmpty)
              CoilButton(
                variant: CoilButtonVariant.ghost,
                size: CoilSize.compact,
                trailing: const CatalogIcon(Glyph.arrowRight),
                onPressed: _drainNextQueued,
                child: Text(
                  _queue.length == 1
                      ? 'Send 1 queued'
                      : 'Send ${_queue.length} queued',
                ),
              ),
          ],
        ),
        SizedBox(
          height: touch ? 460 : 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeBottom: true,
                  child: MediaQuery.removeViewInsets(
                    context: context,
                    removeBottom: true,
                    child: CoilQueuedStack(
                      messages: _queue,
                      onChanged: (queue) => setState(() => _queue = queue),
                      onEdit: _edit,
                      icon: const CatalogIcon(Glyph.cornerDownRight),
                      editIcon: const CatalogIcon(Glyph.pencil),
                      // TurnScrollView reads the bottom MediaQuery padding
                      // CoilQueuedStack injects so the last message always
                      // stays clear of the folded pile.
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
                              itemSpacing: 16,
                              jumpThreshold: 80,
                              padding: const EdgeInsets.only(
                                top: 4,
                                bottom: 12,
                              ),
                              itemBuilder: (context, index) =>
                                  _buildMessage(context, _messages[index]),
                            ),
                          ),
                          Builder(
                            builder: (context) => Positioned(
                              left: 0,
                              right: 0,
                              bottom: MediaQuery.paddingOf(context).bottom + 10,
                              child: Center(
                                child: ChatJumpToBottomButton(
                                  controller: _controller,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              CoilInputMessage(
                controller: _composer,
                placeholder: Text(
                  _replying
                      ? 'Message the assistant to queue it'
                      : 'Message the assistant',
                ),
                status: _replying
                    ? CoilMessageStatus.streaming
                    : CoilMessageStatus.idle,
                onSend: _send,
                onQueue: _queueMessage,
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
                leading: CoilButton.icon(
                  variant: CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  semanticLabel: 'Attach a file',
                  icon: const CatalogIcon(Glyph.paperclip),
                  onPressed: nextDemoFile(_files) == null
                      ? null
                      : () => setState(
                          () => _files = [..._files, nextDemoFile(_files)!],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The pile on its own, to see how it reads with one message, two or five.
class _Pile extends StatefulWidget {
  const _Pile();

  @override
  State<_Pile> createState() => _PileState();
}

class _PileState extends State<_Pile> {
  static const _texts = [
    'Fix spacing',
    'Match the mockups',
    'Check contrast on the charts',
    'Use tabular figures in tables',
    'Add an empty state',
  ];

  var _count = 3;
  late var _queue = _build(_count);

  static List<CoilQueuedMessage> _build(int count) => [
    for (var i = 0; i < count; i++)
      CoilQueuedMessage(
        id: _texts[i],
        child: Text(_texts[i]),
      ),
  ];

  @override
  Widget build(BuildContext context) => DemoSection(
    title: 'The pile on its own',
    description:
        'While the stack is folded, two cards peek 12 px out behind the '
        'front one and the rest fade away. Hover it to fan the whole queue '
        'into a list.',
    controls: DemoControls(
      children: [
        DemoControl.choice(
          label: 'Queued',
          value: _count,
          values: const [1, 2, 3, 5],
          labelOf: (v) => '$v',
          onChanged: (v) => setState(() {
            _count = v;
            _queue = _build(v);
          }),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: CoilQueuedStack(
        messages: _queue,
        onChanged: (queue) => setState(() => _queue = queue),
        onEdit: (message) => setState(
          () => _queue = [
            for (final m in _queue)
              if (m.id != message.id) m,
          ],
        ),
        icon: const CatalogIcon(Glyph.cornerDownRight),
        editIcon: const CatalogIcon(Glyph.pencil),
      ),
    ),
  );
}
