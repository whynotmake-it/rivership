// The home page's tiles: small product surfaces, each composed of several
// live components, the way an app would use them together.
import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/accordion_page.dart';
import 'package:coil_example/src/pages/components/badge_page.dart';
import 'package:coil_example/src/pages/components/banner_page.dart';
import 'package:coil_example/src/pages/components/breadcrumb_page.dart';
import 'package:coil_example/src/pages/components/button_page.dart';
import 'package:coil_example/src/pages/components/calendar_page.dart';
import 'package:coil_example/src/pages/components/card_page.dart';
import 'package:coil_example/src/pages/components/carousel_dots_page.dart';
import 'package:coil_example/src/pages/components/chat_message_page.dart';
import 'package:coil_example/src/pages/components/data_table_page.dart';
import 'package:coil_example/src/pages/components/date_picker_page.dart';
import 'package:coil_example/src/pages/components/dropdown_page.dart';
import 'package:coil_example/src/pages/components/input_copy_page.dart';
import 'package:coil_example/src/pages/components/input_group_page.dart';
import 'package:coil_example/src/pages/components/input_message_page.dart';
import 'package:coil_example/src/pages/components/queued_stack_page.dart';
import 'package:coil_example/src/pages/components/radio_group_page.dart';
import 'package:coil_example/src/pages/components/select_page.dart';
import 'package:coil_example/src/pages/components/slider_page.dart';
import 'package:coil_example/src/pages/components/switch_page.dart';
import 'package:coil_example/src/pages/components/textarea_page.dart';
import 'package:coil_example/src/pages/components/thinking_steps_page.dart';
import 'package:coil_example/src/pages/components/toggle_group_page.dart';
import 'package:coil_example/src/pages/components/tooltip_page.dart';
import 'package:coil_example/src/pages/home/bento.dart';
import 'package:coil_example/src/widgets/catalog_asset.dart';
import 'package:coil_example/src/widgets/chat_widgets.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:turns/turns.dart';

/// The album cover and deck photo both share coil's one bundled image.
/// [CatalogAsset] loads it whether the catalog runs on its own or inside the
/// aggregate example app, where the asset key gains a package prefix.
const _photo = CatalogAsset('assets/images/dunes.jpg');

/// Every tile, in reading order: the flagship surfaces first, the
/// supporting ones below.
final homeTiles = <BentoTileData>[
  BentoTileData(
    title: 'Agent chat',
    span: 2,
    links: const [
      chatMessageEntry,
      thinkingStepsEntry,
      queuedStackEntry,
      inputMessageEntry,
    ],
    builder: (_) => const AgentTile(),
  ),
  BentoTileData(
    title: 'Now playing',
    links: const [sliderEntry, buttonEntry, dropdownEntry],
    builder: (_) => const NowPlayingTile(),
  ),
  // Checkout before Inbox so that, in the two-column layout, the span-one
  // tiles pair up instead of leaving one stretched across a whole row.
  BentoTileData(
    title: 'Checkout',
    links: const [radioGroupEntry, inputGroupEntry, buttonEntry],
    builder: (_) => const CheckoutTile(),
  ),
  BentoTileData(
    title: 'Inbox',
    span: 2,
    links: const [dataTableEntry, badgeEntry, tooltipEntry],
    builder: (_) => const InboxTile(),
  ),
  BentoTileData(
    title: 'Preferences',
    links: const [switchEntry, selectEntry, sliderEntry],
    builder: (_) => const PreferencesTile(),
  ),
  BentoTileData(
    title: 'Schedule',
    links: const [calendarEntry, datePickerEntry],
    builder: (_) => const ScheduleTile(),
  ),
  BentoTileData(
    title: 'Editor',
    links: const [toggleGroupEntry, textareaEntry],
    builder: (_) => const EditorTile(),
  ),
  BentoTileData(
    title: 'Share',
    links: const [breadcrumbEntry, carouselDotsEntry, inputCopyEntry],
    builder: (_) => const ShareTile(),
  ),
  BentoTileData(
    title: 'Status',
    links: const [bannerEntry, accordionEntry],
    builder: (_) => const StatusTile(),
  ),
  BentoTileData(
    title: 'Projects',
    links: const [cardEntry],
    builder: (_) => const ProjectsTile(),
  ),
];

/// A tile's heading: what the surface is, in the muted caption style.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = CoilTheme.textOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        header: true,
        child: Text(text, style: style.muted.caption),
      ),
    );
  }
}

/// A duration as m:ss, for scrubbers and track lengths.
String _time(num seconds) {
  final s = seconds.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Agent chat

class _AgentStep {
  const _AgentStep({
    required this.id,
    required this.glyph,
    required this.title,
    required this.status,
    this.detail,
    this.sources = const [],
  });

  final String id;
  final Glyph glyph;
  final String title;
  final String? detail;
  final List<String> sources;
  final CoilThinkingStepStatus status;

  _AgentStep copyWith({CoilThinkingStepStatus? status}) => _AgentStep(
    id: id,
    glyph: glyph,
    title: title,
    detail: detail,
    sources: sources,
    status: status ?? this.status,
  );
}

class _AgentMessage {
  const _AgentMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.thinkingLabel,
    this.thinkingSteps = const [],
    this.streaming = false,
  });

  final String id;
  final CoilChatSender sender;
  final String text;
  final String time;
  final String? thinkingLabel;
  final List<_AgentStep> thinkingSteps;
  final bool streaming;

  _AgentMessage copyWith({
    String? text,
    String? thinkingLabel,
    List<_AgentStep>? thinkingSteps,
    bool? streaming,
  }) => _AgentMessage(
    id: id,
    sender: sender,
    text: text ?? this.text,
    time: time,
    thinkingLabel: thinkingLabel ?? this.thinkingLabel,
    thinkingSteps: thinkingSteps ?? this.thinkingSteps,
    streaming: streaming ?? this.streaming,
  );
}

const _initialAgentMessages = <_AgentMessage>[
  _AgentMessage(
    id: 'agent-u-1',
    sender: CoilChatSender.user,
    time: '09:40',
    text: 'Where are new teams dropping off in onboarding?',
  ),
  _AgentMessage(
    id: 'agent-a-1',
    sender: CoilChatSender.assistant,
    time: '09:40',
    text:
        'Half of signups stall on **Invite teammates** before they have '
        'created a workspace:\n\n'
        '- **Step 1 (Account):** 92% completion\n'
        '- **Step 2 (Invite team):** 48% completion\n'
        '- **Step 3 (First project):** 84% of teams that reach it finish',
  ),
  _AgentMessage(
    id: 'agent-u-2',
    sender: CoilChatSender.user,
    time: '09:42',
    text: 'Plan the onboarding redesign',
  ),
  _AgentMessage(
    id: 'agent-a-2',
    sender: CoilChatSender.assistant,
    time: '09:42',
    thinkingLabel: 'Thought for 3.2s',
    thinkingSteps: [
      _AgentStep(
        id: 'funnel',
        glyph: Glyph.search,
        title: 'Read the onboarding funnel',
        sources: ['analytics', 'interviews.md'],
        status: CoilThinkingStepStatus.done,
      ),
      _AgentStep(
        id: 'dropoff',
        glyph: Glyph.chart,
        title: 'Isolated the invite drop-off',
        detail: 'Half of new teams stop before creating a first project.',
        status: CoilThinkingStepStatus.done,
      ),
      _AgentStep(
        id: 'compare',
        glyph: Glyph.lightbulb,
        title: 'Compared three rollout options',
        detail: 'Kept the sequence with the fewest moving parts.',
        status: CoilThinkingStepStatus.done,
      ),
      _AgentStep(
        id: 'draft',
        glyph: Glyph.pencil,
        title: 'Drafted the three-step plan',
        status: CoilThinkingStepStatus.done,
      ),
    ],
    text:
        'Move the invite step **after the first project**, and let solo '
        'builders skip it in one tap:\n\n'
        '1. **Workspace name** — single field with sensible defaults.\n'
        '2. **First project** — pre-seeded template so teams see value fast.\n'
        '3. **Invite teammates** — optional share link once the project is '
        'live.',
  ),
];

const _timelineReply = '''
Here is a lightweight **two-week rollout**:

- **Days 1–3:** Ship the reordered flow behind `onboarding_v2` for 20% of new signups.
- **Days 4–7:** Track first-project completion and solo-skip rate against the baseline.
- **Week 2:** Roll to 100% and retire the blocking invite screen.''';

const _kickoffReply = '''
### Kickoff note draft

**Subject:** Onboarding v2 — faster path to first project

We are moving **Invite teammates** after the first project so new teams hit value in under two minutes:

- **Scope:** Reorder steps 2 and 3, add a one-tap skip link.
- **Metric:** Lift day-1 project creation from `48%` to `70%+`.
- **Target:** Flag on for internal workspaces this Thursday.''';

const _deepDiveReply = '''
### Funnel & instrumentation plan

Keeping the active turn anchored in `TurnScrollView` lets reviewers scroll up to compare numbers while this plan streams in:

| Milestone | Baseline | Target | Guardrail |
| :--- | :--- | :--- | :--- |
| First project created | 48% | 72% | Time to interactive < 2m |
| Teammate invited (D7) | 41% | 45% | Prompt inside project header |
| Skip-and-return rate | — | < 15% | One-click share link |

1. Emit `onboarding_step_completed` with `skipped: true | false`.
2. Keep the invite modal reachable from the top bar so skipping never feels permanent.''';

/// An agent at work: a [TurnScrollView] transcript with thinking steps,
/// streaming markdown replies, quick prompts, and a queue of waiting follow-ups
/// you can fan out, reorder and edit.
class AgentTile extends StatefulWidget {
  const AgentTile({super.key});

  @override
  State<AgentTile> createState() => _AgentTileState();
}

class _AgentTileState extends State<AgentTile> {
  final _controller = TurnScrollController();
  final _composer = TextEditingController();
  final _copyControllers = <String, CoilCopyController>{};
  final _freshIds = <String>{};
  final _expandedThinking = <String, bool>{};
  final _timers = <Timer>[];
  final _texts = <Object, String>{};

  late List<_AgentMessage> _messages;
  var _queue = <CoilQueuedMessage>[];
  var _queueIds = 0;
  var _nextTurn = 3;

  String? _pinnedId;
  String? _streamingMessageId;
  Timer? _thinkingTimer;
  Timer? _streamTimer;

  bool get _isStreaming => _streamingMessageId != null;

  @override
  void initState() {
    super.initState();
    _messages = [..._initialAgentMessages];
    _queue = [
      _queuedMessage('Add a rollout timeline'),
      _queuedMessage('Draft the kickoff note'),
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
    _composer.dispose();
    super.dispose();
  }

  CoilCopyController _copyFor(String id) =>
      _copyControllers.putIfAbsent(id, CoilCopyController.new);

  CoilQueuedMessage _queuedMessage(String text) {
    final id = _queueIds++;
    _texts[id] = text;
    return CoilQueuedMessage(id: id, child: Text(text));
  }

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
    _AgentMessage Function(_AgentMessage current) transform,
  ) {
    _messages = [
      for (final message in _messages)
        if (message.id == id) transform(message) else message,
    ];
  }

  void _startTurn({
    required String prompt,
    required List<_AgentStep> steps,
    required String reply,
    int chunkSize = 8,
  }) {
    if (_isStreaming) {
      _stopStreaming();
    }

    final turn = _nextTurn++;
    final userId = 'agent-u-$turn';
    final assistantId = 'agent-a-$turn';
    final time = '09:${(42 + turn).toString().padLeft(2, '0')}';

    _markFresh(userId);
    _markFresh(assistantId);
    _expandedThinking[assistantId] = true;

    setState(() {
      _messages = [
        ..._messages,
        _AgentMessage(
          id: userId,
          sender: CoilChatSender.user,
          text: prompt,
          time: time,
        ),
        _AgentMessage(
          id: assistantId,
          sender: CoilChatSender.assistant,
          text: '',
          time: time,
          thinkingLabel: 'Planning…',
          thinkingSteps: [steps.first],
          streaming: true,
        ),
      ];
      _pinnedId = userId;
      _streamingMessageId = assistantId;
    });

    var revealed = 1;
    _thinkingTimer?.cancel();
    _thinkingTimer = Timer.periodic(const Duration(milliseconds: 340), (timer) {
      if (!mounted || _streamingMessageId != assistantId) {
        timer.cancel();
        return;
      }
      if (revealed < steps.length) {
        revealed++;
        final nextSteps = <_AgentStep>[
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
      _beginStream(
        assistantId: assistantId,
        fullReply: reply,
        chunkSize: chunkSize,
      );
    });
  }

  void _beginStream({
    required String assistantId,
    required String fullReply,
    required int chunkSize,
  }) {
    var cursor = 0;
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(const Duration(milliseconds: 24), (timer) {
      if (!mounted || _streamingMessageId != assistantId) {
        timer.cancel();
        return;
      }
      cursor = math.min(fullReply.length, cursor + chunkSize);
      final done = cursor >= fullReply.length;
      final slice = fullReply.substring(0, cursor);
      setState(() {
        _updateMessage(
          assistantId,
          (m) => m.copyWith(text: slice, streaming: !done),
        );
        if (done) {
          _streamingMessageId = null;
        }
      });
      if (done) {
        timer.cancel();
        _streamTimer = null;
        if (_queue.isNotEmpty) {
          late final Timer nextTimer;
          nextTimer = Timer(const Duration(milliseconds: 700), () {
            _timers.remove(nextTimer);
            if (mounted && !_isStreaming) _resumeQueue();
          });
          _timers.add(nextTimer);
        }
      }
    });
  }

  void _stopStreaming({bool drainQueue = false}) {
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
    _streamTimer?.cancel();
    _streamTimer = null;
    final activeId = _streamingMessageId;
    if (activeId == null) return;
    setState(() {
      _streamingMessageId = null;
      _expandedThinking[activeId] = false;
      _updateMessage(
        activeId,
        (m) => m.copyWith(
          streaming: false,
          text: m.text.isEmpty ? '_Generation stopped._' : m.text,
          thinkingLabel: m.thinkingSteps.isEmpty ? null : 'Stopped',
          thinkingSteps: [
            for (final step in m.thinkingSteps)
              step.copyWith(status: CoilThinkingStepStatus.done),
          ],
        ),
      );
    });
    if (drainQueue && _queue.isNotEmpty) {
      _resumeQueue();
    }
  }

  void _sendPrompt(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('timeline')) {
      _startTurn(
        prompt: prompt,
        steps: const [
          _AgentStep(
            id: 'scope',
            glyph: Glyph.calendar,
            title: 'Mapped rollout milestones',
            detail: 'Splits flag ramp and instrumentation into two weeks.',
            sources: ['release.md'],
            status: CoilThinkingStepStatus.running,
          ),
          _AgentStep(
            id: 'owners',
            glyph: Glyph.pencil,
            title: 'Drafted launch checkpoints',
            status: CoilThinkingStepStatus.running,
          ),
        ],
        reply: _timelineReply,
      );
      return;
    }
    if (lower.contains('kickoff') || lower.contains('email')) {
      _startTurn(
        prompt: prompt,
        steps: const [
          _AgentStep(
            id: 'summary',
            glyph: Glyph.mail,
            title: 'Collected funnel highlights',
            sources: ['analytics'],
            status: CoilThinkingStepStatus.running,
          ),
          _AgentStep(
            id: 'note',
            glyph: Glyph.pencil,
            title: 'Drafted kickoff note',
            status: CoilThinkingStepStatus.running,
          ),
        ],
        reply: _kickoffReply,
      );
      return;
    }
    _startTurn(
      prompt: prompt,
      steps: const [
        _AgentStep(
          id: 'context',
          glyph: Glyph.search,
          title: 'Reviewed onboarding context',
          detail: 'Anchors the new turn while drafting the reply.',
          sources: ['funnel.md'],
          status: CoilThinkingStepStatus.running,
        ),
        _AgentStep(
          id: 'draft',
          glyph: Glyph.sparkles,
          title: 'Drafted recommendation',
          status: CoilThinkingStepStatus.running,
        ),
      ],
      reply:
          'Updated the plan for **"${prompt.replaceAll('"', "'")}"**:\n\n'
          '- Keep the first-project step front and center.\n'
          '- Surface team invites right inside the project header once '
          'created.\n'
          '- Watch day-1 completion before expanding the rollout.',
    );
  }

  void _sendDeepDive() {
    _startTurn(
      prompt: 'Break down the funnel metrics and guardrails in detail',
      steps: const [
        _AgentStep(
          id: 'metrics',
          glyph: Glyph.chart,
          title: 'Pulled baseline conversion numbers',
          sources: ['analytics', 'events.sql'],
          status: CoilThinkingStepStatus.running,
        ),
        _AgentStep(
          id: 'guardrails',
          glyph: Glyph.shield,
          title: 'Checked activation guardrails',
          detail: 'Pairs D1 project creation with D7 team invite health.',
          status: CoilThinkingStepStatus.running,
        ),
      ],
      reply: _deepDiveReply,
      chunkSize: 10,
    );
  }

  void _resumeQueue() {
    if (_isStreaming || _queue.isEmpty) return;
    final next = _queue.first;
    final text = _texts.remove(next.id);
    setState(() => _queue = _queue.sublist(1));
    if (text != null) {
      _sendPrompt(text);
    }
  }

  Widget _buildMessage(BuildContext context, _AgentMessage message) {
    final entrance = _freshIds.contains(message.id)
        ? CoilChatMessageEntrance.animated
        : CoilChatMessageEntrance.none;

    if (message.sender == CoilChatSender.user) {
      return CoilChatMessage(
        sender: CoilChatSender.user,
        entrance: entrance,
        time: Text(message.time),
        timeLabel: message.time,
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
              label: Text(message.thinkingLabel ?? 'Planning…'),
              expanded: expanded,
              onChanged: (v) =>
                  setState(() => _expandedThinking[message.id] = v),
              steps: [
                for (final step in message.thinkingSteps)
                  CoilThinkingStep(
                    key: ValueKey('${message.id}.${step.id}'),
                    leading: CatalogIcon(step.glyph),
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
    return SizedBox(
      height: touch ? 480 : 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: Row(
              spacing: 6,
              children: [
                CoilButton(
                  variant: CoilButtonVariant.secondary,
                  size: CoilSize.compact,
                  leading: const CatalogIcon(Glyph.zap),
                  onPressed: () => _sendPrompt('Add a rollout timeline'),
                  child: const Text('Add timeline'),
                ),
                CoilButton(
                  variant: CoilButtonVariant.secondary,
                  size: CoilSize.compact,
                  leading: const CatalogIcon(Glyph.chart),
                  onPressed: _sendDeepDive,
                  child: const Text('Metrics deep dive'),
                ),
                if (!_isStreaming && _queue.isNotEmpty)
                  CoilButton(
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                    trailing: const CatalogIcon(Glyph.arrowRight),
                    onPressed: _resumeQueue,
                    child: Text(
                      _queue.length == 1
                          ? 'Run 1 queued'
                          : 'Run ${_queue.length} queued',
                    ),
                  ),
              ],
            ),
          ),
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
                  onEdit: (message) => setState(() {
                    _composer.text = _texts.remove(message.id)!;
                    _queue = [
                      for (final m in _queue)
                        if (m.id != message.id) m,
                    ];
                  }),
                  icon: const CatalogIcon(Glyph.cornerDownRight),
                  editIcon: const CatalogIcon(Glyph.pencil),
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
                          itemSpacing: 14,
                          jumpThreshold: 80,
                          padding: const EdgeInsets.only(top: 4, bottom: 12),
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
              _isStreaming ? 'Send to queue a message…' : 'Ask for a change…',
            ),
            status: _isStreaming
                ? CoilMessageStatus.streaming
                : CoilMessageStatus.idle,
            onSend: (text) {
              final trimmed = text.trim();
              if (trimmed.isEmpty) return;
              if (_isStreaming) {
                setState(() => _queue = [..._queue, _queuedMessage(trimmed)]);
              } else {
                _sendPrompt(trimmed);
              }
            },
            onQueue: (text) {
              final trimmed = text.trim();
              if (trimmed.isEmpty) return;
              setState(() => _queue = [..._queue, _queuedMessage(trimmed)]);
            },
            onStop: _stopStreaming,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Now playing

typedef _Track = ({String title, String artist, int length});

/// A music player: the cover, a scrubber you can drag, transport controls
/// and a queue you can play from. Play advances the scrubber a second at a
/// time; the up-next tracks move into the cover when you pick them.
class NowPlayingTile extends StatefulWidget {
  const NowPlayingTile({super.key});

  @override
  State<NowPlayingTile> createState() => _NowPlayingTileState();
}

class _NowPlayingTileState extends State<NowPlayingTile> {
  static const _tracks = <_Track>[
    (title: 'Coastline', artist: 'Hannah Park', length: 214),
    (title: 'Paper Planes', artist: 'The Lowlands', length: 187),
    (title: 'Golden Hour', artist: 'David Morales', length: 203),
    (title: 'Night Drive', artist: 'Claire Bennett', length: 231),
  ];

  var _current = 0;
  var _position = 72.0;
  var _playing = false;
  var _shuffle = false;
  var _liked = true;
  Timer? _timer;

  _Track get _track => _tracks[_current];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _timer?.cancel();
    if (_playing) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _position += 1;
          if (_position >= _track.length) {
            _position = 0;
            _skip(1);
          }
        });
      });
    }
  }

  void _skip(int by) {
    setState(() {
      _current = (_current + by) % _tracks.length;
      if (_current < 0) _current += _tracks.length;
      _position = 0;
    });
  }

  void _playFrom(int index) {
    _timer?.cancel();
    setState(() {
      _current = index;
      _position = 0;
      _playing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final colors = CoilTheme.of(context).colors;
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).item + 2);
    final upNext = [
      for (var i = 1; i < _tracks.length; i++) (_current + i) % _tracks.length,
    ];
    return SizedBox(
      height: touch ? 480 : 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Eyebrow('Now playing'),
          Row(
            children: [
              SizedBox.square(
                dimension: 56,
                child: ClipRRect(
                  borderRadius: radius,
                  child: const Image(
                    image: _photo,
                    fit: BoxFit.cover,
                    alignment: Alignment(0, -0.2),
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _track.title,
                      style: text.body.copyWith(fontWeight: text.emphasis),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _track.artist,
                      style: text.muted.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              CoilButton.icon(
                variant: CoilButtonVariant.ghost,
                selected: _liked,
                semanticLabel: _liked
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                icon: const CatalogIcon(Glyph.heart),
                onPressed: () => setState(() => _liked = !_liked),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CoilSlider(
            value: _position.clamp(0, _track.length.toDouble()),
            max: _track.length.toDouble(),
            semanticLabel: 'Seek',
            valueBuilder: (_, v) => Text(_time(v)),
            semanticFormatter: _time,
            onChanged: (v) => setState(() => _position = v),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _time(_position),
                style: text.muted.micro.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                _time(_track.length),
                style: text.muted.micro.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoilButton.icon(
                variant: CoilButtonVariant.ghost,
                selected: _shuffle,
                semanticLabel: 'Shuffle',
                icon: const CatalogIcon(Glyph.shuffle),
                onPressed: () => setState(() => _shuffle = !_shuffle),
              ),
              const SizedBox(width: 4),
              CoilButton.icon(
                variant: CoilButtonVariant.ghost,
                semanticLabel: 'Previous track',
                icon: const CatalogIcon(Glyph.skipBack),
                onPressed: () => _skip(-1),
              ),
              const SizedBox(width: 4),
              CoilButton.icon(
                semanticLabel: _playing ? 'Pause' : 'Play',
                icon: CatalogIcon(_playing ? Glyph.pause : Glyph.play),
                onPressed: _togglePlay,
              ),
              const SizedBox(width: 4),
              CoilButton.icon(
                variant: CoilButtonVariant.ghost,
                semanticLabel: 'Next track',
                icon: const CatalogIcon(Glyph.skipForward),
                onPressed: () => _skip(1),
              ),
              const SizedBox(width: 4),
              CoilDropdown(
                entries: [
                  CoilAction(
                    label: const Text('Add to playlist'),
                    searchText: 'Add to playlist',
                    leading: const CatalogIcon(Glyph.plus),
                    onPressed: () {},
                  ),
                  CoilAction(
                    label: const Text('Go to artist'),
                    searchText: 'Go to artist',
                    leading: const CatalogIcon(Glyph.user),
                    onPressed: () {},
                  ),
                  CoilAction(
                    label: const Text('Share'),
                    searchText: 'Share',
                    leading: const CatalogIcon(Glyph.link),
                    onPressed: () {},
                  ),
                ],
                builder: (context, menu) => CoilButton.icon(
                  variant: CoilButtonVariant.ghost,
                  semanticLabel: 'More',
                  icon: const CatalogIcon(Glyph.more),
                  onPressed: menu.open,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CatalogIcon(Glyph.listMusic),
              const SizedBox(width: 8),
              Text('Up next', style: text.muted.caption),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              primary: false,
              padding: EdgeInsets.zero,
              children: [
                for (final index in upNext)
                  CoilButton(
                    variant: CoilButtonVariant.ghost,
                    onPressed: () => _playFrom(index),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tracks[index].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _tracks[index].artist,
                                style: text.muted.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _time(_tracks[index].length),
                          style: text.muted.caption.copyWith(
                            color: colors.mutedForeground,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inbox

typedef _Mail = ({String from, String subject, String time, _MailTag tag});

enum _MailTag {
  unread('Unread', CoilBadgeColor.blue),
  priority('Priority', CoilBadgeColor.amber),
  read('Read', CoilBadgeColor.gray);

  const _MailTag(this.label, this.color);

  final String label;
  final CoilBadgeColor color;
}

/// An inbox you triage: select rows (adjacent ones merge into one block)
/// and act on them from the toolbar, whose buttons wake up once something
/// is picked. Archiving, snoozing or deleting takes the rows out.
class InboxTile extends StatefulWidget {
  const InboxTile({super.key});

  @override
  State<InboxTile> createState() => _InboxTileState();
}

class _InboxTileState extends State<InboxTile> {
  static const _inbox = <_Mail>[
    (
      from: 'Ada Lovelace',
      subject: 'Re: onboarding funnel numbers',
      time: '09:24',
      tag: _MailTag.unread,
    ),
    (
      from: 'Deploy bot',
      subject: 'v2.4.0 is live in all regions',
      time: '08:51',
      tag: _MailTag.priority,
    ),
    (
      from: 'Grace Hopper',
      subject: 'Notes from the design review',
      time: 'Yesterday',
      tag: _MailTag.unread,
    ),
    (
      from: 'Katherine Johnson',
      subject: 'Kickoff deck is ready to share',
      time: 'Yesterday',
      tag: _MailTag.read,
    ),
    (
      from: 'Barbara Liskov',
      subject: 'Lunch on Thursday?',
      time: 'Mon',
      tag: _MailTag.read,
    ),
    (
      from: 'Linus Torvalds',
      subject: 'Re: arrow keys skip disabled days',
      time: 'Mon',
      tag: _MailTag.read,
    ),
    (
      from: 'Margaret Hamilton',
      subject: 'Review the release checklist',
      time: 'Sun',
      tag: _MailTag.unread,
    ),
  ];

  late final _controller = CoilDataTableController<_Mail>(rows: [..._inbox]);

  @override
  void initState() {
    super.initState();
    // Two neighbors selected, so the merged highlight shows at a glance.
    _controller.selected = {_inbox[1], _inbox[2]};
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _remove() {
    final selected = _controller.selected;
    _controller
      ..rows = [
        for (final mail in _controller.rows)
          if (!selected.contains(mail)) mail,
      ]
      ..selected = const {};
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _Eyebrow('Inbox')),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final any = _controller.selected.isNotEmpty;
                return Row(
                  children: [
                    for (final (label, glyph) in const [
                      ('Archive', Glyph.archive),
                      ('Snooze', Glyph.clock),
                      ('Delete', Glyph.trash),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: CoilTooltip(
                          message: Text(label),
                          child: CoilButton.icon(
                            variant: CoilButtonVariant.ghost,
                            size: CoilSize.compact,
                            semanticLabel: label,
                            icon: CatalogIcon(glyph),
                            onPressed: any ? _remove : null,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        CoilDataTable<_Mail>(
          controller: _controller,
          searchable: false,
          semanticLabel: 'Inbox',
          empty: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Inbox zero. All caught up.',
              textAlign: TextAlign.center,
              style: text.muted.body,
            ),
          ),
          columns: [
            CoilDataColumn(
              label: const Text('From'),
              cellBuilder: (context, m) => Text(
                m.from,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: m.tag == _MailTag.read
                    ? null
                    : text.body.copyWith(fontWeight: text.emphasis),
              ),
            ),
            CoilDataColumn(
              label: const Text('Subject'),
              flex: 2,
              minWidth: 110,
              cellBuilder: (context, m) =>
                  Text(m.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            CoilDataColumn(
              label: const Text('Status'),
              width: 116,
              cellBuilder: (context, m) => CoilBadge(
                variant: CoilBadgeVariant.dot,
                color: m.tag.color,
                child: Text(m.tag.label),
              ),
            ),
            CoilDataColumn(
              label: const Text('Time'),
              width: 92,
              alignment: AlignmentDirectional.centerEnd,
              cellBuilder: (context, m) => Text(
                m.time,
                style: text.muted.caption.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Checkout

typedef _Shipping = ({String name, String eta, double price});

/// A checkout panel: pick a shipping speed from choice cards, add a promo
/// code in the grouped fields, and the total keeps up. STUDENT takes 15 %
/// off.
class CheckoutTile extends StatefulWidget {
  const CheckoutTile({super.key});

  @override
  State<CheckoutTile> createState() => _CheckoutTileState();
}

class _CheckoutTileState extends State<CheckoutTile> {
  static const _subtotal = 48.0;
  static const _shipping = <String, _Shipping>{
    'standard': (name: 'Standard', eta: '3–5 days', price: 0),
    'express': (name: 'Express', eta: '1–2 days', price: 9),
  };

  final _email = TextEditingController(text: 'ada@example.com');
  final _promo = TextEditingController();

  var _speed = 'standard';
  var _applied = false;

  @override
  void dispose() {
    _email.dispose();
    _promo.dispose();
    super.dispose();
  }

  double get _discount => _applied ? _subtotal * 0.15 : 0;
  double get _total => _subtotal + _shipping[_speed]!.price - _discount;

  @override
  Widget build(BuildContext context) {
    final gap = CoilTheme.metricsOf(context).buttonGap;
    final valid = _promo.text.trim().toUpperCase() == 'STUDENT';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Checkout'),
        CoilRadioGroup<String>.custom(
          value: _speed,
          onChanged: (v) => setState(() => _speed = v),
          semanticLabel: 'Shipping',
          child: CoilFieldGroup(
            children: [
              for (final MapEntry(key: id, value: option) in _shipping.entries)
                CoilChoiceCard(
                  size: CoilSize.compact,
                  selected: _speed == id,
                  control: CoilRadio(value: id, semanticLabel: option.name),
                  title: Text(option.name),
                  description: Text(
                    option.price == 0
                        ? '${option.eta} · free'
                        : '${option.eta} · €${option.price.toStringAsFixed(0)}',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CoilInputGroup(
          size: CoilSize.compact,
          children: [
            CoilField(
              label: const Text('Email'),
              child: CoilInput(
                controller: _email,
                leading: const CatalogIcon(Glyph.mail),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
            ),
            CoilField(
              label: const Text('Promo code'),
              child: CoilInput(
                controller: _promo,
                placeholder: const Text('STUDENT'),
                leading: const CatalogIcon(Glyph.tag),
                autocorrect: false,
                trailing: CoilButton(
                  variant: CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  onPressed: valid && !_applied
                      ? () => setState(() => _applied = true)
                      : null,
                  child: Text(_applied ? 'Applied' : 'Apply'),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _TotalRow(label: 'Subtotal', amount: _subtotal, muted: true),
        _TotalRow(
          label: 'Shipping',
          amount: _shipping[_speed]!.price,
          muted: true,
          free: _shipping[_speed]!.price == 0,
        ),
        if (_applied)
          _TotalRow(label: 'Student discount', amount: -_discount, muted: true),
        const SizedBox(height: 4),
        _TotalRow(label: 'Total', amount: _total),
        SizedBox(height: gap + 4),
        CoilButton(
          leading: const CatalogIcon(Glyph.creditCard),
          onPressed: () {},
          child: Text('Pay €${_total.toStringAsFixed(2)}'),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.muted = false,
    this.free = false,
  });

  final String label;
  final double amount;
  final bool muted;
  final bool free;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final style = muted
        ? text.muted.body
        : text.body.copyWith(fontWeight: text.emphasis);
    final sign = amount < 0 ? '-' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            free ? 'Free' : '$sign€${amount.abs().toStringAsFixed(2)}',
            style: style.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preferences

/// App preferences: switch rows, a select and two sliders.
class PreferencesTile extends StatefulWidget {
  const PreferencesTile({super.key});

  @override
  State<PreferencesTile> createState() => _PreferencesTileState();
}

class _PreferencesTileState extends State<PreferencesTile> {
  var _notifications = true;
  var _autosave = false;
  var _sounds = true;
  var _digest = false;
  var _language = 'en';
  var _volume = 0.6;
  var _quality = 3.0;

  static const _languages = {
    'en': 'English',
    'de': 'Deutsch',
    'fr': 'Français',
    'ja': '日本語',
  };

  static String _percent(double v) => '${(v * 100).round()}%';

  static String _qualityName(double v) => switch (v.round()) {
    1 => 'Draft',
    2 => 'Low',
    3 => 'Balanced',
    4 => 'High',
    _ => 'Best',
  };

  @override
  Widget build(BuildContext context) {
    final gap = CoilTheme.tierOf(context) == CoilTier.touch ? 16.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Preferences'),
        CoilFieldGroup(
          children: [
            CoilSwitch(
              value: _notifications,
              onChanged: (v) => setState(() => _notifications = v),
              label: const Text('Notifications'),
            ),
            CoilSwitch(
              value: _autosave,
              onChanged: (v) => setState(() => _autosave = v),
              label: const Text('Auto-save drafts'),
            ),
            CoilSwitch(
              value: _sounds,
              onChanged: (v) => setState(() => _sounds = v),
              label: const Text('Sound effects'),
            ),
            CoilSwitch(
              value: _digest,
              onChanged: (v) => setState(() => _digest = v),
              label: const Text('Weekly digest'),
            ),
          ],
        ),
        SizedBox(height: gap),
        CoilField(
          label: const Text('Language'),
          child: CoilSelect<String>(
            value: _language,
            onChanged: (v) => setState(() => _language = v),
            options: [
              for (final MapEntry(:key, :value) in _languages.entries)
                CoilOption(value: key, label: Text(value), searchText: value),
            ],
          ),
        ),
        SizedBox(height: gap),
        CoilSlider(
          label: const Text('Volume'),
          value: _volume,
          valueBuilder: (_, v) => Text(_percent(v)),
          semanticFormatter: _percent,
          onChanged: (v) => setState(() => _volume = v),
        ),
        SizedBox(height: gap),
        CoilSlider(
          label: const Text('Quality'),
          variant: CoilSliderVariant.pips,
          min: 1,
          max: 5,
          divisions: 4,
          value: _quality,
          valueBuilder: (_, v) => Text(_qualityName(v)),
          semanticFormatter: _qualityName,
          onChanged: (v) => setState(() => _quality = v),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Schedule

/// A month to pick a day in, and a field that picks a date and time.
class ScheduleTile extends StatefulWidget {
  const ScheduleTile({super.key});

  @override
  State<ScheduleTile> createState() => _ScheduleTileState();
}

class _ScheduleTileState extends State<ScheduleTile> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  DateTime? _day = _firstWorkday();
  DateTime? _reminder;

  /// Today, or the next weekday: the calendar disables weekends.
  static DateTime _firstWorkday() {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    while (day.weekday >= DateTime.saturday) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return day;
  }

  /// A stand-in agenda: how many events a day holds.
  static int _events(DateTime day) => (day.day * 5 + day.month) % 4;

  static String _label(DateTime day) {
    final events = _events(day);
    final count = switch (events) {
      0 => 'No events',
      1 => '1 event',
      _ => '$events events',
    };
    return '${_weekdays[day.weekday - 1]} ${day.day} '
        '${_months[day.month - 1]} · $count';
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Schedule'),
        Center(
          child: CoilCalendar(
            selected: day,
            isDisabled: (day) => day.weekday >= DateTime.saturday,
            onSelected: (day) => setState(() => _day = day),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            day == null ? 'Pick a day to see its events' : _label(day),
            style: CoilTheme.textOf(context).muted.caption,
          ),
        ),
        const SizedBox(height: 12),
        CoilField(
          label: const Text('Reminder'),
          child: CoilDatePicker(
            value: _reminder,
            withTime: true,
            minuteInterval: 15,
            placeholder: const Text('No reminder'),
            onChanged: (v) => setState(() => _reminder = v),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Editor

/// The marks a note's text can carry, as bits of a character's style.
const _marks = {'bold': 1, 'italic': 2, 'underline': 4};

/// A text controller whose text carries bold, italic and underline marks.
///
/// It keeps one style per character, in step with every edit: typed text
/// takes the style of the character before it, or the style picked while
/// the caret was collapsed, and deleted text takes its style with it.
class _NoteController extends TextEditingController {
  _NoteController(List<(String, int)> segments)
    : _styles = [
        for (final (text, style) in segments)
          ...List.filled(text.length, style),
      ],
      super(text: segments.map((s) => s.$1).join());

  final List<int> _styles;

  /// The style the next typed character gets, when one was picked with a
  /// collapsed caret. Moving the caret forgets it.
  int? _typing;

  TextSelection get _range => selection.isValid
      ? selection
      : TextSelection.collapsed(offset: text.length);

  /// The marks at the caret, or the ones every selected character shares.
  int get active {
    final range = _range;
    if (range.isCollapsed) {
      final typing = _typing;
      if (typing != null) return typing;
      if (_styles.isEmpty) return 0;
      return _styles[range.start > 0 ? range.start - 1 : 0];
    }
    var shared = _marks.values.fold(0, (a, b) => a | b);
    for (var i = range.start; i < range.end; i++) {
      shared &= _styles[i];
    }
    return shared;
  }

  Set<String> get activeMarks => {
    for (final MapEntry(:key, :value) in _marks.entries)
      if (active & value != 0) key,
  };

  /// Makes the marks in [wanted] the active ones: on the selection, or on
  /// what is typed next when the caret is collapsed.
  void apply(Set<String> wanted) {
    final range = _range;
    final current = active;
    var next = current;
    for (final MapEntry(:key, :value) in _marks.entries) {
      next = wanted.contains(key) ? next | value : next & ~value;
    }
    if (next == current) return;
    if (range.isCollapsed) {
      _typing = next;
    } else {
      final changed = current ^ next;
      for (var i = range.start; i < range.end; i++) {
        _styles[i] = (_styles[i] & ~changed) | (next & changed);
      }
    }
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != text) {
      _edit(newValue.text);
    } else if (newValue.selection != selection) {
      _typing = null;
    }
    super.value = newValue;
  }

  /// Finds what changed between the old text and [next], and gives the
  /// inserted characters their style.
  void _edit(String next) {
    final old = text;
    if (_styles.length != old.length) {
      _styles
        ..clear()
        ..addAll(List.filled(old.length, 0));
    }
    final shortest = math.min(old.length, next.length);
    var start = 0;
    while (start < shortest &&
        old.codeUnitAt(start) == next.codeUnitAt(start)) {
      start++;
    }
    var end = 0;
    while (end < shortest - start &&
        old.codeUnitAt(old.length - 1 - end) ==
            next.codeUnitAt(next.length - 1 - end)) {
      end++;
    }
    final removed = old.length - start - end;
    final added = next.length - start - end;
    final style =
        _typing ?? (_styles.isEmpty ? 0 : _styles[start > 0 ? start - 1 : 0]);
    _styles.replaceRange(start, start + removed, List.filled(added, style));
    if (added > 0) _typing = null;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    if (_styles.length != text.length || text.isEmpty) {
      return TextSpan(style: style, text: text);
    }
    final weight = CoilTheme.textOf(context).emphasis;
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i < text.length && _styles[i] == _styles[start]) continue;
      final marks = _styles[start];
      spans.add(
        TextSpan(
          text: text.substring(start, i),
          style: TextStyle(
            fontWeight: marks & 1 != 0 ? weight : null,
            fontStyle: marks & 2 != 0 ? FontStyle.italic : null,
            decoration: marks & 4 != 0 ? TextDecoration.underline : null,
          ),
        ),
      );
      start = i;
    }
    return TextSpan(style: style, children: spans);
  }
}

/// A note editor: the formatting toggles show the marks at the caret or
/// selection and change them, on the selection or on what is typed next.
class EditorTile extends StatefulWidget {
  const EditorTile({super.key});

  @override
  State<EditorTile> createState() => _EditorTileState();
}

class _EditorTileState extends State<EditorTile> {
  final _focus = FocusNode();
  final _note = _NoteController(const [
    ('Send the ', 0),
    ('onboarding', 1),
    (' notes before ', 0),
    ('Friday', 4),
    ('. Review the timeline ', 0),
    ('first', 2),
    ('.', 0),
  ]);

  @override
  void dispose() {
    _focus.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _summary(String text) {
    final trimmed = text.trim();
    final words = trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
    if (words == 0) return 'Empty';
    final minutes = math.max(1, (words / 200).ceil());
    return '$words ${words == 1 ? 'word' : 'words'} · $minutes min read';
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return ListenableBuilder(
      listenable: _note,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Eyebrow('Note'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CoilToggleGroup<String>(
                values: _note.activeMarks,
                onChanged: (values) {
                  _note.apply(values);
                  // Pressing a toggle must not end the editing.
                  _focus.requestFocus();
                },
                options: const [
                  CoilOption(
                    value: 'bold',
                    label: CatalogIcon(Glyph.bold, semanticLabel: 'Bold'),
                  ),
                  CoilOption(
                    value: 'italic',
                    label: CatalogIcon(Glyph.italic, semanticLabel: 'Italic'),
                  ),
                  CoilOption(
                    value: 'underline',
                    label: CatalogIcon(
                      Glyph.underline,
                      semanticLabel: 'Underline',
                    ),
                  ),
                ],
              ),
              Text(_summary(_note.text), style: text.muted.caption),
            ],
          ),
          const SizedBox(height: 12),
          CoilInput.multiline(
            controller: _note,
            focusNode: _focus,
            minLines: 7,
            placeholder: const Text('Write a note…'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Share

typedef _Slide = (String title, Alignment alignment, double scale);

/// Sharing a deck: the crumb trail to it, a swipeable preview of its
/// slides, dots that follow and drive the page, and a link to copy. You can
/// drag the preview with a finger or the mouse; the dots glide along.
class ShareTile extends StatefulWidget {
  const ShareTile({super.key});

  @override
  State<ShareTile> createState() => _ShareTileState();
}

class _ShareTileState extends State<ShareTile> {
  final _controller = PageController();
  var _page = 0;

  /// Each slide's title and how the photo is framed for it.
  static const _slides = <_Slide>[
    ('Cover', Alignment.center, 1),
    ('Agenda', Alignment.topLeft, 1.6),
    ('Metrics', Alignment.bottomRight, 1.35),
    ('The team', Alignment(-0.6, 0.4), 1.9),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_follow);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_follow)
      ..dispose();
    super.dispose();
  }

  // The dots track the page the view is nearest; their pill glides there
  // on its own spring, so there is no jump between the images.
  void _follow() {
    final page = (_controller.page ?? _page.toDouble()).round();
    if (page != _page) setState(() => _page = page);
  }

  void _go(int page) => unawaited(
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Share'),
        CoilBreadcrumb(
          crumbs: [
            CoilCrumb(label: const Text('Projects'), onPressed: () {}),
            CoilCrumb(label: const Text('Onboarding'), onPressed: () {}),
            const CoilCrumb(label: Text('Kickoff deck')),
          ],
        ),
        const SizedBox(height: 12),
        // A mouse drags the slides as a finger would.
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: PointerDeviceKind.values.toSet(),
            scrollbars: false,
          ),
          child: SizedBox(
            height: 168,
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              itemBuilder: (context, i) => _SlideView(
                slide: _slides[i],
                index: i,
                count: _slides.length,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: CoilCarouselDots(
            count: _slides.length,
            value: _page,
            onChanged: _go,
          ),
        ),
        const SizedBox(height: 8),
        const CoilInputCopy(value: 'https://coil.dev/s/kickoff'),
      ],
    );
  }
}

/// One deck slide: a differently framed crop of the photo with its title.
class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.index,
    required this.count,
  });

  final _Slide slide;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final (title, alignment, scale) = slide;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        label: 'Slide ${index + 1} of $count: $title',
        image: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            CoilTheme.radiiOf(context).container,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: Transform.scale(
                  scale: scale,
                  alignment: alignment,
                  child: const Image(image: _photo, fit: BoxFit.cover),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: ExcludeSemantics(
                  child: Text(
                    title,
                    style: text.body.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontWeight: text.emphasis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status

/// A deploy's status: a banner you can dismiss and bring back, over
/// answers that open one at a time.
class StatusTile extends StatefulWidget {
  const StatusTile({super.key});

  @override
  State<StatusTile> createState() => _StatusTileState();
}

class _StatusTileState extends State<StatusTile> {
  var _shown = true;
  String? _open = 'rollback';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Eyebrow('Status'),
      if (_shown)
        CoilBanner(
          status: CoilBannerStatus.success,
          title: const Text('Deployed to production'),
          description: const Text('v2.4.0 is live in all regions.'),
          onDismissRequested: () => setState(() => _shown = false),
        )
      else
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoilButton(
            variant: CoilButtonVariant.secondary,
            size: CoilSize.compact,
            onPressed: () => setState(() => _shown = true),
            child: const Text('Show the banner'),
          ),
        ),
      const SizedBox(height: 12),
      CoilAccordion<String>.single(
        value: _open,
        onChanged: (v) => setState(() => _open = v),
        items: const [
          CoilAccordionItem(
            value: 'rollback',
            label: Text('Can I roll back?'),
            panel: Text('Yes, any release from the last 30 days.'),
          ),
          CoilAccordionItem(
            value: 'downtime',
            label: Text('Was there downtime?'),
            panel: Text('No. Traffic moved over one region at a time.'),
          ),
          CoilAccordionItem(
            value: 'notify',
            label: Text('Who was notified?'),
            panel: Text('Everyone watching the project.'),
          ),
          CoilAccordionItem(
            value: 'schedule',
            label: Text('Can I schedule a release?'),
            panel: Text('Yes, pick a time when you publish.'),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Projects

/// Cards in a group: pressable rows with an icon, one you can dismiss.
class ProjectsTile extends StatefulWidget {
  const ProjectsTile({super.key});

  @override
  State<ProjectsTile> createState() => _ProjectsTileState();
}

class _ProjectsTileState extends State<ProjectsTile> {
  var _tipShown = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Eyebrow('Projects'),
      CoilCardGroup(
        children: [
          CoilCard(
            icon: const CatalogIcon(Glyph.zap),
            title: const Text('Onboarding'),
            description: const Text('3 tasks due this week'),
            onPressed: () {},
          ),
          CoilCard(
            icon: const CatalogIcon(Glyph.chart),
            title: const Text('Growth report'),
            description: const Text('Updated 2 hours ago'),
            onPressed: () {},
          ),
        ],
      ),
      if (_tipShown) ...[
        const SizedBox(height: 12),
        CoilCard(
          icon: const CatalogIcon(Glyph.lightbulb),
          title: const Text('Tip'),
          description: const Text('Search finds any page: ⌘K or Ctrl+K.'),
          onDismissed: () => setState(() => _tipShown = false),
        ),
      ],
    ],
  );
}
