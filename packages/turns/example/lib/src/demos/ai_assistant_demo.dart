import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:motor/motor.dart';
import 'package:turns/turns.dart';
import 'package:turns_example/src/shell/turns_action_strip.dart';
import 'package:turns_example/src/shell/turns_playground.dart';

/// AI assistant playground: a [TurnScrollView] transcript whose `pinnedId`
/// pins each new prompt while the reply streams, with a settings panel for
/// the anchor, the scroll motion, the stream and the spacing, and an overlay
/// that draws the [SliverTurnStage] and the space it reserves.
class AiAssistantDemo extends StatefulWidget {
  /// Creates the AI assistant demo.
  const AiAssistantDemo({super.key});

  @override
  State<AiAssistantDemo> createState() => _AiAssistantDemoState();
}

enum _Role { user, assistant }

/// Starting points for the two [TurnAnchorConfig] sliders.
enum _AnchorPreset {
  standard('Standard', TurnAnchorConfig.standard),
  top('Top', TurnAnchorConfig.top);

  const _AnchorPreset(this.label, this.config);

  final String label;
  final TurnAnchorConfig config;
}

/// Starting points for the scroll spring's two sliders.
enum _MotionPreset {
  smooth('Smooth', 360, 0),
  snappy('Snappy', 240, 0.12),
  bouncy('Bouncy', 520, 0.32);

  const _MotionPreset(this.label, this.milliseconds, this.bounce);

  final String label;
  final double milliseconds;
  final double bounce;
}

enum _StreamSpeed {
  slow('Slow', 3, Duration(milliseconds: 40)),
  normal('Normal', 9, Duration(milliseconds: 24)),
  fast('Fast', 28, Duration(milliseconds: 16));

  const _StreamSpeed(this.label, this.chunkSize, this.tick);

  final String label;
  final int chunkSize;
  final Duration tick;
}

class _ThinkingStepData {
  const _ThinkingStepData({
    required this.id,
    required this.title,
    required this.detail,
    required this.sources,
    required this.status,
  });

  final String id;
  final String title;
  final String detail;
  final List<String> sources;
  final CoilThinkingStepStatus status;

  _ThinkingStepData copyWith({CoilThinkingStepStatus? status}) =>
      _ThinkingStepData(
        id: id,
        title: title,
        detail: detail,
        sources: sources,
        status: status ?? this.status,
      );
}

class _AiMessage {
  const _AiMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.time,
    this.thinkingLabel,
    this.thinkingSteps = const [],
    this.streaming = false,
  });

  final String id;
  final _Role role;
  final String text;
  final String time;
  final String? thinkingLabel;
  final List<_ThinkingStepData> thinkingSteps;
  final bool streaming;

  _AiMessage copyWith({
    String? text,
    String? thinkingLabel,
    List<_ThinkingStepData>? thinkingSteps,
    bool? streaming,
  }) => _AiMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    time: time,
    thinkingLabel: thinkingLabel ?? this.thinkingLabel,
    thinkingSteps: thinkingSteps ?? this.thinkingSteps,
    streaming: streaming ?? this.streaming,
  );
}

class _AiAssistantDemoState extends State<AiAssistantDemo> {
  final _controller = TurnScrollController();
  final _scrollViewKey = GlobalKey(debugLabel: 'AiAssistant.scrollView');

  /// Whether a new prompt becomes `pinnedId`; off, the view follows the
  /// bottom like a log.
  var _pinning = true;
  var _anchor = TurnAnchorConfig.standard;
  var _motionMilliseconds = _MotionPreset.smooth.milliseconds;
  var _motionBounce = _MotionPreset.smooth.bounce;

  /// autoScrollMotion from the two sliders; zero duration jumps.
  Motion get _motion => _motionMilliseconds < 1
      ? const Motion.instant()
      : Motion.cupertino(
          duration: Duration(milliseconds: _motionMilliseconds.round()),
          bounce: _motionBounce,
        );

  _MotionPreset? get _matchingPreset => _MotionPreset.values
      .where(
        (p) =>
            (p.milliseconds - _motionMilliseconds).abs() < 1 &&
            (p.bounce - _motionBounce).abs() < 0.005,
      )
      .firstOrNull;
  var _speed = _StreamSpeed.normal;
  var _showThinking = true;
  var _showStage = false;
  var _itemSpacing = 24.0;

  TurnAnchorConfig get _anchorConfig => _anchor;
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  final _session = MarkdownSession();

  late List<_AiMessage> _messages;
  final _freshIds = <String>{};
  final _expandedThinking = <String, bool>{};
  final _copyControllers = <String, CoilCopyController>{};
  final _timers = <Timer>[];

  String? _pinnedId;
  String? _streamingMessageId;
  Timer? _streamTimer;
  Timer? _thinkingTimer;

  int _olderPagesLoaded = 0;
  int _nextTurnNumber = 4;
  int _stableBlockCount = 0;
  bool _hasPendingBlock = false;
  double _composerHeight = 96;

  static const _maxOlderPages = 2;

  bool get _isStreaming => _streamingMessageId != null;

  @override
  void initState() {
    super.initState();
    _messages = _buildInitialConversation();
    _syncSessionTelemetry(_messages.last.text, streaming: false);
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _thinkingTimer?.cancel();
    for (final timer in _timers) {
      timer.cancel();
    }
    for (final copy in _copyControllers.values) {
      copy.dispose();
    }
    _controller.dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  CoilCopyController _copyControllerFor(String id) =>
      _copyControllers.putIfAbsent(id, CoilCopyController.new);

  void _syncSessionTelemetry(String source, {required bool streaming}) {
    final doc = _session.update(source, streaming: streaming);
    _stableBlockCount = doc.stable.length;
    _hasPendingBlock = doc.pending != null;
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

  void _loadOlderTurns() {
    if (_olderPagesLoaded >= _maxOlderPages) return;
    final page = _olderPagesLoaded + 1;
    final older = _buildOlderPage(page);
    setState(() {
      _messages = [...older, ..._messages];
      _olderPagesLoaded = page;
    });
  }

  void _stopStreaming() {
    _streamTimer?.cancel();
    _streamTimer = null;
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
    final activeId = _streamingMessageId;
    if (activeId == null) return;
    setState(() {
      _streamingMessageId = null;
      _messages = [
        for (final message in _messages)
          if (message.id == activeId)
            message.copyWith(
              streaming: false,
              text: message.text.isEmpty
                  ? '_Generation stopped before output started._'
                  : message.text,
              thinkingLabel: message.thinkingSteps.isEmpty
                  ? null
                  : 'Stopped after ${message.thinkingSteps.length} steps',
              thinkingSteps: [
                for (final step in message.thinkingSteps)
                  if (step.status == CoilThinkingStepStatus.running)
                    step.copyWith(status: CoilThinkingStepStatus.done)
                  else
                    step,
              ],
            )
          else
            message,
      ];
    });
    final stopped = _messages.where((m) => m.id == activeId).firstOrNull;
    if (stopped != null) {
      _syncSessionTelemetry(stopped.text, streaming: false);
    }
  }

  void _sendQuickShort() {
    _startTurn(
      prompt: 'How does SliverTurnStage pin a turn without layout jumps?',
      steps: const [
        _ThinkingStepData(
          id: 'inspect-stage',
          title: 'Inspecting SliverTurnStage.performLayout',
          detail: 'Checks anchor extent against usable viewport height.',
          sources: ['turn_sliver.dart'],
          status: CoilThinkingStepStatus.running,
        ),
        _ThinkingStepData(
          id: 'verify-scroll',
          title: 'Tracing maxScrollExtent stability',
          detail: 'Confirms reserved extent holds constant while reply grows.',
          sources: ['turn_scroll_engine.dart'],
          status: CoilThinkingStepStatus.running,
        ),
      ],
      reply: _shortStreamingReply,
    );
  }

  /// A prompt taller than the view: the anchor's minimum trailing space
  /// scrolls it up so the reply still gets room below it.
  void _sendQuickTall() {
    _startTurn(
      prompt:
          'Can you review this incident log and tell me what went wrong?'
          '\n\n${_incidentLog()}',
      steps: const [
        _ThinkingStepData(
          id: 'read-log',
          title: 'Reading 28 log lines',
          detail: 'Groups the retries by upstream.',
          sources: ['incident.log'],
          status: CoilThinkingStepStatus.running,
        ),
      ],
      reply:
          'The **cache node in eu-west** started refusing connections at '
          '09:17, and every retry after that piled onto the primary until '
          'its pool ran dry at 09:31.\n\n'
          '- **Root cause:** a config push that halved the pool size.\n'
          '- **Fix:** restore the pool size and cap retries at three.\n\n'
          'Notice how your message scrolled up when it was sent: it is '
          'taller than the view, so the anchor keeps half the view free '
          'below it for this reply (minTrailingFraction: 0.5).',
    );
  }

  void _sendQuickLong() {
    _startTurn(
      prompt:
          'Walk through bidirectional Viewport(center:) and streaming GFM '
          'markdown completion in turns.',
      steps: const [
        _ThinkingStepData(
          id: 'viewport',
          title: 'Analyzing bidirectional Viewport(center:) split',
          detail: 'Separates reverse above-center history from forward tail.',
          sources: ['turn_scroll_view.dart', 'turn_scroll_engine.dart'],
          status: CoilThinkingStepStatus.running,
        ),
        _ThinkingStepData(
          id: 'markdown',
          title: 'Reviewing MarkdownSession & completeMarkdown',
          detail:
              'Caches settled blocks by identity and repairs unfinished tails.',
          sources: ['markdown_session.dart', 'markdown_complete.dart'],
          status: CoilThinkingStepStatus.running,
        ),
        _ThinkingStepData(
          id: 'compose',
          title: 'Drafting architecture walkthrough and code sample',
          detail: 'Includes comparison table and live Dart snippet.',
          sources: ['packages/turns'],
          status: CoilThinkingStepStatus.running,
        ),
      ],
      reply: _longStreamingReply,
    );
  }

  void _handleComposerSend(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _startTurn(
      prompt: trimmed,
      steps: const [
        _ThinkingStepData(
          id: 'context',
          title: 'Reading recent thread context',
          detail: 'Anchors your prompt at top clearance while drafting.',
          sources: ['TurnScrollView'],
          status: CoilThinkingStepStatus.running,
        ),
        _ThinkingStepData(
          id: 'draft',
          title: 'Streaming response through MarkdownSession',
          detail: 'Keeps earlier blocks immutable while the tail updates.',
          sources: ['MarkdownSession'],
          status: CoilThinkingStepStatus.running,
        ),
      ],
      reply: _buildCustomReply(trimmed),
    );
  }

  void _startTurn({
    required String prompt,
    required List<_ThinkingStepData> steps,
    required String reply,
  }) {
    final chunkSize = _speed.chunkSize;
    final tick = _speed.tick;
    if (_isStreaming) {
      _stopStreaming();
    }

    final turnNumber = _nextTurnNumber++;
    final userId = 'ai-user-$turnNumber';
    final assistantId = 'ai-assistant-$turnNumber';
    final time = _formatClock(turnNumber);

    final userMessage = _AiMessage(
      id: userId,
      role: _Role.user,
      text: prompt,
      time: time,
    );
    final assistantMessage = _AiMessage(
      id: assistantId,
      role: _Role.assistant,
      text: '',
      time: time,
      thinkingLabel: _showThinking ? 'Thinking…' : null,
      thinkingSteps: _showThinking ? [steps.first] : const [],
      streaming: true,
    );

    _markFresh(userId);
    _markFresh(assistantId);
    _expandedThinking[assistantId] = true;

    setState(() {
      _messages = [..._messages, userMessage, assistantMessage];
      _pinnedId = userId;
      _streamingMessageId = assistantId;
      _syncSessionTelemetry('', streaming: true);
    });
    _followBottomIfUnpinned(force: true);

    if (!_showThinking) {
      _beginTokenStream(
        assistantId: assistantId,
        fullReply: reply,
        chunkSize: chunkSize,
        tick: tick,
      );
      return;
    }

    // Advance thinking steps cleanly with Timers, then stream markdown tokens.
    var revealedSteps = 1;
    _thinkingTimer?.cancel();
    _thinkingTimer = Timer.periodic(const Duration(milliseconds: 340), (timer) {
      if (!mounted || _streamingMessageId != assistantId) {
        timer.cancel();
        return;
      }
      if (revealedSteps < steps.length) {
        revealedSteps++;
        final nextSteps = <_ThinkingStepData>[
          for (var i = 0; i < revealedSteps; i++)
            if (i < revealedSteps - 1)
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
      final completedSteps = [
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
            thinkingSteps: completedSteps,
          ),
        );
      });
      _beginTokenStream(
        assistantId: assistantId,
        fullReply: reply,
        chunkSize: chunkSize,
        tick: tick,
      );
    });
  }

  void _beginTokenStream({
    required String assistantId,
    required String fullReply,
    required int chunkSize,
    required Duration tick,
  }) {
    var cursor = 0;
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(tick, (timer) {
      if (!mounted || _streamingMessageId != assistantId) {
        timer.cancel();
        return;
      }
      cursor = math.min(fullReply.length, cursor + chunkSize);
      final done = cursor >= fullReply.length;
      final slice = fullReply.substring(0, cursor);
      setState(() {
        _syncSessionTelemetry(slice, streaming: !done);
        _updateMessage(
          assistantId,
          (m) => m.copyWith(text: slice, streaming: !done),
        );
        if (done) {
          _streamingMessageId = null;
        }
      });
      _followBottomIfUnpinned();
      if (done) {
        timer.cancel();
        _streamTimer = null;
      }
    });
  }

  /// With pinning off the transcript behaves like a log: it follows the
  /// bottom while you are there, and stays put once you scroll up.
  void _followBottomIfUnpinned({bool force = false}) {
    if (_pinning) return;
    if (!force && _controller.isAwayFromBottom.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.scrollToBottom(animate: force));
    });
  }

  void _updateMessage(
    String id,
    _AiMessage Function(_AiMessage current) transform,
  ) {
    _messages = [
      for (final message in _messages)
        if (message.id == id) transform(message) else message,
    ];
  }

  void _onComposerHeight(double height) {
    if ((_composerHeight - height).abs() <= 0.5) return;
    setState(() => _composerHeight = height);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final text = CoilTheme.textOf(context);
    final remainingPages = _maxOlderPages - _olderPagesLoaded;

    final body = ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = math.max<double>(
                  16,
                  (constraints.maxWidth - 740) / 2,
                );
                return Stack(
                  children: [
                    CoilScrollArea(
                      key: _scrollViewKey,
                      controller: _controller,
                      edgeFades: CoilEdgeFades.none,
                      keyboard: false,
                      child: TurnScrollView<Object>(
                        controller: _controller,
                        itemCount: _messages.length,
                        itemId: (i) => _messages[i].id,
                        pinnedId: _pinning ? _pinnedId : null,
                        anchorConfig: _anchorConfig,
                        autoScrollMotion: _motion,
                        itemSpacing: _itemSpacing,
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          16,
                          horizontal,
                          _composerHeight + 28,
                        ),
                        leadingSlivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                horizontal,
                                0,
                                horizontal,
                                20,
                              ),
                              child: _TranscriptTopBanner(
                                remainingPages: remainingPages,
                                onLoadOlder: remainingPages > 0
                                    ? _loadOlderTurns
                                    : null,
                              ),
                            ),
                          ),
                        ],
                        itemBuilder: (context, index) =>
                            _buildMessageItem(context, _messages[index]),
                      ),
                    ),
                    if (_showStage)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _StageOverlay(scrollViewKey: _scrollViewKey),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _composerHeight + 14,
                      child: Center(
                        child: _JumpToBottomButton(
                          buttonKey: const Key('ai.jump_bottom'),
                          awayFromBottom: _controller.isAwayFromBottom,
                          autoScrolling: _controller.isAutoScrolling,
                          onPressed: _controller.scrollToBottom,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _HeightObserver(
                        onHeight: _onComposerHeight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      colors.background.withValues(alpha: 0),
                                      colors.background,
                                    ],
                                  ),
                                ),
                                child: const SizedBox(height: 18),
                              ),
                            ),
                            ColoredBox(
                              color: colors.background,
                              child: _Suggestions(
                                visible: !_isStreaming,
                                horizontal: horizontal,
                                onShort: _sendQuickShort,
                                onLong: _sendQuickLong,
                                onTall: _sendQuickTall,
                              ),
                            ),
                            ColoredBox(
                              color: colors.background,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  4,
                                  horizontal,
                                  16,
                                ),
                                child: CoilInputMessage(
                                  controller: _composerController,
                                  focusNode: _composerFocus,
                                  placeholder: Text(
                                    'Ask anything, your turn pins to the top',
                                    style: text.muted.field,
                                  ),
                                  status: _isStreaming
                                      ? CoilMessageStatus.streaming
                                      : CoilMessageStatus.idle,
                                  onSend: _handleComposerSend,
                                  onStop: _stopStreaming,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );

    return PlaygroundLayout(
      settingsKey: const Key('ai.settings'),
      body: body,
      settings: [
        PlaygroundSection(
          title: 'Live',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StageBadge(
                  isStreaming: _isStreaming,
                  pinActive: _controller.isPinActive,
                  stableBlocks: _stableBlockCount,
                  hasPendingBlock: _hasPendingBlock,
                ),
              ],
            ),
            PlaygroundToggle(
              key: const Key('ai.show_stage'),
              label: 'Show the stage',
              hint: 'Outlines the pinned turn and the space reserved below it.',
              value: _showStage,
              onChanged: (v) => setState(() => _showStage = v),
            ),
          ],
        ),
        PlaygroundSection(
          title: 'Pinning',
          children: [
            PlaygroundToggle(
              label: 'Pin new prompts',
              hint:
                  'Off, there is no pinnedId and the view follows the '
                  'bottom like a log.',
              value: _pinning,
              onChanged: (v) => setState(() => _pinning = v),
            ),
            if (_pinning) ...[
              PlaygroundPresets<_AnchorPreset>(
                presets: {for (final p in _AnchorPreset.values) p: p.label},
                selected: _AnchorPreset.values
                    .where((p) => p.config == _anchor)
                    .firstOrNull,
                onPick: (p) => setState(() => _anchor = p.config),
              ),
              PlaygroundSlider(
                label: 'Alignment',
                hint: 'Where the prompt rests: 0 at the top, 1 at the bottom.',
                value: _anchor.alignment,
                min: 0,
                max: 1,
                divisions: 20,
                format: (v) => v.toStringAsFixed(2),
                onChanged: (v) =>
                    setState(() => _anchor = _anchor.copyWith(alignment: v)),
              ),
              PlaygroundSlider(
                label: 'Min trailing',
                hint:
                    'Share of the view kept free below the prompt for the '
                    'reply; tall prompts scroll up to make room.',
                value: _anchor.minTrailingFraction ?? 0,
                min: 0,
                max: 1,
                divisions: 20,
                format: (v) => v == 0 ? 'Off' : '${(v * 100).round()} %',
                onChanged: (v) => setState(
                  () => _anchor = _anchor.copyWith(
                    minTrailingFraction: v == 0 ? null : v,
                  ),
                ),
              ),
            ],
          ],
        ),
        PlaygroundSection(
          title: 'Scroll motion',
          children: [
            PlaygroundPresets<_MotionPreset>(
              presets: {for (final p in _MotionPreset.values) p: p.label},
              selected: _matchingPreset,
              onPick: (p) => setState(() {
                _motionMilliseconds = p.milliseconds;
                _motionBounce = p.bounce;
              }),
            ),
            PlaygroundSlider(
              label: 'Duration',
              value: _motionMilliseconds,
              min: 0,
              max: 900,
              divisions: 36,
              format: (v) => v < 1 ? 'Instant' : '${v.round()} ms',
              onChanged: (v) => setState(() => _motionMilliseconds = v),
            ),
            PlaygroundSlider(
              label: 'Bounce',
              hint:
                  'autoScrollMotion for pins and jumps; a duration of 0 '
                  'jumps. Send a prompt to feel it.',
              value: _motionBounce,
              min: 0,
              max: 0.5,
              divisions: 20,
              format: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() => _motionBounce = v),
            ),
          ],
        ),
        PlaygroundSection(
          title: 'Reply',
          children: [
            PlaygroundChoice<_StreamSpeed>(
              label: 'Stream speed',
              value: _speed,
              options: {
                for (final speed in _StreamSpeed.values) speed: speed.label,
              },
              onChanged: (v) => setState(() => _speed = v),
            ),
            PlaygroundToggle(
              label: 'Thinking steps',
              hint: 'Grow the turn before the reply starts.',
              value: _showThinking,
              onChanged: (v) => setState(() => _showThinking = v),
            ),
          ],
        ),
        PlaygroundSection(
          title: 'Layout',
          children: [
            PlaygroundSlider(
              label: 'Item spacing',
              value: _itemSpacing,
              min: 8,
              max: 48,
              divisions: 10,
              format: (v) => '${v.round()} px',
              onChanged: (v) => setState(() => _itemSpacing = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageItem(BuildContext context, _AiMessage message) {
    final entrance = _freshIds.contains(message.id)
        ? CoilChatMessageEntrance.animated
        : CoilChatMessageEntrance.none;

    if (message.role == _Role.user) {
      return CoilChatMessage(
        sender: CoilChatSender.user,
        entrance: entrance,
        time: Text(message.time),
        timeLabel: message.time,
        child: Text(message.text),
      );
    }

    final colors = CoilTheme.of(context).colors;
    final copy = _copyControllerFor(message.id);
    final hasThinking = message.thinkingSteps.isNotEmpty;
    final expanded = _expandedThinking[message.id] ?? false;

    return CoilChatMessage(
      sender: CoilChatSender.assistant,
      entrance: entrance,
      time: message.streaming ? const Text('Streaming…') : Text(message.time),
      timeLabel: message.streaming ? 'Streaming' : message.time,
      actions: [
        if (!message.streaming && message.text.isNotEmpty)
          CoilChatMessageAction(
            label: const Text('Copy reply'),
            icon: Semantics(
              label: 'Copy reply',
              child: CoilCopyGlyph.listening(controller: copy),
            ),
            onPressed: () => copy.copy(message.text, context: context),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasThinking) ...[
            CoilThinkingSteps(
              label: Text(message.thinkingLabel ?? 'Thinking…'),
              expanded: expanded,
              onChanged: (value) =>
                  setState(() => _expandedThinking[message.id] = value),
              steps: [
                for (final step in message.thinkingSteps)
                  CoilThinkingStep(
                    key: ValueKey('${message.id}.${step.id}'),
                    title: Text(step.title),
                    detail: Text(step.detail),
                    sources: [for (final s in step.sources) Text(s)],
                    status: step.status,
                  ),
              ],
            ),
            if (message.text.isNotEmpty) const SizedBox(height: 10),
          ],
          if (message.text.isNotEmpty)
            CoilMarkdown(
              message.text,
              streaming: message.streaming,
              trailing: message.streaming
                  ? Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: colors.brand,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        child: const SizedBox(width: 6, height: 14),
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Live state of the [MarkdownSession] behind the streaming reply: how many
/// blocks are frozen, and whether the prompt's stage is pinned.
class _StageBadge extends StatelessWidget {
  const _StageBadge({
    required this.isStreaming,
    required this.pinActive,
    required this.stableBlocks,
    required this.hasPendingBlock,
  });

  final bool isStreaming;
  final ValueListenable<bool> pinActive;
  final int stableBlocks;
  final bool hasPendingBlock;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return ValueListenableBuilder<bool>(
      valueListenable: pinActive,
      builder: (context, isPinned, _) {
        final label = isStreaming
            ? 'Streaming · $stableBlocks stable'
                  '${hasPendingBlock ? ' + tail' : ''}'
            : isPinned
            ? 'Stage pinned · $stableBlocks blocks'
            : 'MarkdownSession · $stableBlocks blocks';
        return CoilBadge(
          variant: CoilBadgeVariant.dot,
          color: isStreaming
              ? CoilBadgeColor.emerald
              : isPinned
              ? CoilBadgeColor.brand
              : CoilBadgeColor.gray,
          shape: CoilBadgeShape.pill,
          size: CoilSize.compact,
          child: Text(label, style: text.micro.tabular),
        );
      },
    );
  }
}

/// Prompts to try, above the composer while nothing is streaming.
class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.visible,
    required this.horizontal,
    required this.onShort,
    required this.onLong,
    required this.onTall,
  });

  final bool visible;
  final double horizontal;
  final VoidCallback onShort;
  final VoidCallback onLong;
  final VoidCallback onTall;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    return SingleMotionBuilder(
      value: visible ? 1 : 0,
      motion: visible ? motion.standard : motion.fadeExit,
      // Hidden suggestions keep their room, so the composer (and the
      // bottom inset the transcript reads) never moves when they fade.
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: IgnorePointer(
          ignoring: !visible,
          child: ExcludeSemantics(excluding: !visible, child: child),
        ),
      ),
      child: TurnsActionStrip(
        padding: EdgeInsets.fromLTRB(horizontal, 2, horizontal, 4),
        children: [
          CoilButton(
            key: const Key('ai.quick_short'),
            variant: CoilButtonVariant.secondary,
            size: CoilSize.compact,
            style: const CoilButtonStyle(radius: 999),
            leading: const Icon(LucideIcons.zap, size: 14),
            onPressed: onShort,
            child: const Text('How does pinning avoid jumps?'),
          ),
          CoilButton(
            key: const Key('ai.quick_long'),
            variant: CoilButtonVariant.secondary,
            size: CoilSize.compact,
            style: const CoilButtonStyle(radius: 999),
            leading: const Icon(LucideIcons.fileCode2, size: 14),
            onPressed: onLong,
            child: const Text('Walk me through the architecture'),
          ),
          CoilButton(
            key: const Key('ai.quick_tall'),
            variant: CoilButtonVariant.secondary,
            size: CoilSize.compact,
            style: const CoilButtonStyle(radius: 999),
            leading: const Icon(LucideIcons.clipboardPaste, size: 14),
            onPressed: onTall,
            child: const Text('Paste a very long message'),
          ),
        ],
      ),
    );
  }
}

class _TranscriptTopBanner extends StatelessWidget {
  const _TranscriptTopBanner({
    required this.remainingPages,
    required this.onLoadOlder,
  });

  final int remainingPages;
  final VoidCallback? onLoadOlder;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surfaces[1],
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              remainingPages > 0
                  ? LucideIcons.arrowUpCircle
                  : LucideIcons.checkCircle2,
              size: 16,
              color: colors.mutedForeground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                remainingPages > 0
                    ? 'Earlier turns stay anchored at 0.0px shift when '
                          'prepended.'
                    : 'Beginning of transcript — all earlier turns loaded.',
                style: text.muted.caption,
              ),
            ),
            if (onLoadOlder != null) ...[
              const SizedBox(width: 8),
              CoilButton(
                variant: CoilButtonVariant.ghost,
                size: CoilSize.compact,
                onPressed: onLoadOlder,
                child: const Text('Load older'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JumpToBottomButton extends StatelessWidget {
  const _JumpToBottomButton({
    required this.buttonKey,
    required this.awayFromBottom,
    required this.autoScrolling,
    required this.onPressed,
  });

  final Key buttonKey;
  final ValueListenable<bool> awayFromBottom;
  final ValueListenable<bool> autoScrolling;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([awayFromBottom, autoScrolling]),
      builder: (context, child) {
        final visible = awayFromBottom.value && !autoScrolling.value;
        return SingleMotionBuilder(
          value: visible ? 1 : 0,
          motion: visible ? motion.standard : motion.fadeExit,
          debugLabel: 'AiAssistantDemo.jumpBottom',
          child: child,
          builder: (context, progress, child) {
            final clamped = progress.clamp(0.0, 1.0);
            return IgnorePointer(
              ignoring: !visible,
              child: Opacity(
                opacity: clamped,
                child: Transform.translate(
                  offset: Offset(0, (1 - progress) * 14),
                  child: child,
                ),
              ),
            );
          },
        );
      },
      child: CoilButton.icon(
        key: buttonKey,
        size: CoilSize.compact,
        semanticLabel: 'Jump to latest',
        style: const CoilButtonStyle(radius: 999),
        icon: const Icon(LucideIcons.arrowDown, size: 16),
        onPressed: onPressed,
      ),
    );
  }
}

class _HeightObserver extends SingleChildRenderObjectWidget {
  const _HeightObserver({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightObserver(onHeight: onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightObserver renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderHeightObserver extends RenderProxyBox {
  _RenderHeightObserver({required this.onHeight});

  ValueChanged<double> onHeight;
  double _lastHeight = -1;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if ((height - _lastHeight).abs() > 0.5) {
      _lastHeight = height;
      WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
    }
  }
}

const _incidentLines = [
  'WARN  cache-eu-west  connection refused, retrying (1/5)',
  'WARN  cache-eu-west  connection refused, retrying (2/5)',
  'INFO  api            falling back to primary for session reads',
  'WARN  primary        pool at 92% (46/50)',
  'ERROR cache-eu-west  giving up after 5 retries',
  'WARN  primary        pool at 100% (50/50), queueing',
  'ERROR api            session read timed out after 3000 ms',
];

/// Twenty-eight log lines, enough to make a prompt taller than the view.
String _incidentLog() => [
  for (var i = 0; i < 28; i++)
    '09:${(14 + i).toString().padLeft(2, '0')}  ${_incidentLines[i % 7]}',
].join('\n');

String _formatClock(int turnNumber) {
  final minutes = (14 + turnNumber * 2) % 60;
  final mm = minutes.toString().padLeft(2, '0');
  return '10:$mm AM';
}

List<_AiMessage> _buildInitialConversation() => const [
  _AiMessage(
    id: 'ai-user-1',
    role: _Role.user,
    time: '10:06 AM',
    text:
        'Why do standard Flutter chat lists jump when you prepend older '
        'messages or stream a long assistant reply?',
  ),
  _AiMessage(
    id: 'ai-assistant-1',
    role: _Role.assistant,
    time: '10:06 AM',
    text: '''
Two separate layout invariants break in a plain `ListView`:

1. **Prepending shifts every coordinate** — inserting items above index `0` pushes `scrollOffset` down by the newly laid-out heights unless you split the viewport around a `center` key.
2. **Streaming fights user scroll** — calling `jumpTo(maxScrollExtent)` on every token yanks the reader back down whenever they try to read earlier paragraphs.

`TurnScrollView` solves both at the sliver level: a bidirectional `Viewport(center:)` freezes visible items during prepends (`0.0px` shift), while `SliverTurnStage` reserves the active turn's height up front so `maxScrollExtent` stays constant while the reply grows into it.''',
  ),
  _AiMessage(
    id: 'ai-user-2',
    role: _Role.user,
    time: '10:09 AM',
    text:
        'And how does `MarkdownSession` avoid re-parsing the entire reply on '
        'every incoming token?',
  ),
  _AiMessage(
    id: 'ai-assistant-2',
    role: _Role.assistant,
    time: '10:09 AM',
    text: '''
`MarkdownSession` splits a growing reply at top-level block boundaries (`markdownBoundary`):

- **Stable segments** are parsed once, assigned a permanent `id`, and returned by identity on every subsequent `update(...)`.
- **The pending tail** is the only slice reparsed as tokens arrive — and while `streaming: true`, `completeMarkdown(tail)` temporarily closes unfinished `**bold**`, `` `code` ``, or `[links](url` so raw punctuation never flickers.''',
  ),
  _AiMessage(
    id: 'ai-user-3',
    role: _Role.user,
    time: '10:12 AM',
    text:
        'What happens if I send a follow-up while scrolled at the bottom of a '
        'tall answer?',
  ),
  _AiMessage(
    id: 'ai-assistant-3',
    role: _Role.assistant,
    time: '10:12 AM',
    text: '''
Pick a suggestion above the composer, or type your own question:

- Your new prompt becomes `pinnedId`, so `SliverTurnStage` wraps it as the anchor sliver and reserves a full viewport stage beneath it.
- Motor springs the prompt cleanly to top clearance (`defaultTurnAutoScrollMotion`), leaving room for `CoilThinkingSteps` and the streaming reply — and any touch drag or wheel scroll disengages auto-pinning immediately.''',
  ),
];

List<_AiMessage> _buildOlderPage(int page) {
  if (page == 1) {
    return const [
      _AiMessage(
        id: 'ai-older-p1-u1',
        role: _Role.user,
        time: '9:54 AM',
        text: 'Does TurnScrollView require knowing item heights ahead of time?',
      ),
      _AiMessage(
        id: 'ai-older-p1-a1',
        role: _Role.assistant,
        time: '9:54 AM',
        text: '''
No fixed heights needed. Every visible child is wrapped in `TurnScrollItem`, which reports its exact laid-out `size.height` and `RenderBox` during `performLayout()` — no `GlobalKey`s or post-frame measurement loops.

When `controller.scrollTo(offscreenId)` springs across unmeasured items, `TargetTrackingScrollActivity` retargets smoothly with preserved velocity as real extents come online.''',
      ),
      _AiMessage(
        id: 'ai-older-p1-u2',
        role: _Role.user,
        time: '9:58 AM',
        text: 'Can I still open directly on message #3,421 in O(1)?',
      ),
      _AiMessage(
        id: 'ai-older-p1-a2',
        role: _Role.assistant,
        time: '9:58 AM',
        text: '''
Yes — pass `initialItemId: targetId`. `TurnScrollView` sets `_centerIndex` straight to that item on frame 1 so Flutter lays out only the visible neighborhood around it, skipping `0..3,420` completely.''',
      ),
    ];
  }
  return const [
    _AiMessage(
      id: 'ai-older-p2-u1',
      role: _Role.user,
      time: '9:41 AM',
      text: 'How are keyboard insets handled when the composer opens?',
    ),
    _AiMessage(
      id: 'ai-older-p2-a1',
      role: _Role.assistant,
      time: '9:41 AM',
      text: '''
`TurnScrollPosition.applyContentDimensions` tracks `usableBottom = viewportDimension - effectiveBottom` synchronously during layout. When the software keyboard rises or falls, pixels shift by the exact bottom-edge delta in the same frame — zero 1-frame flash.''',
    ),
  ];
}

String _buildCustomReply(String prompt) =>
    '''
Got it — here is how `turns` handles **"${prompt.replaceAll('"', "'")}"** inside this active stage:

### Live Stage Behavior
- Your message is mounted as the **`anchorSliver`** inside `SliverTurnStage` and pinned to top clearance with a Motor spring.
- Earlier messages stay untouched above the seam, while this reply streams into the reserved stage below with `CoilMarkdown(streaming: true)`.

```dart
TurnScrollView(
  itemCount: messages.length,
  itemId: (i) => messages[i].id,
  pinnedId: activeUserMessageId,
  itemBuilder: (context, i) => buildMessage(messages[i]),
)
```

Scroll upward anytime — `TurnScrollPosition` cancels auto-pinning on the first drag or wheel event and surfaces the **Jump to latest** pill.''';

const _shortStreamingReply = '''
`SliverTurnStage` measures the **anchor sliver** (`H_u`) and compares it to the usable viewport height (`V`) in a single layout pass:

- **Short prompt (`H_u <= V / 2`)**: reserves `minExtent = V`, so scrolling to `maxScrollExtent` places your prompt right at `topClearance`.
- **Tall prompt (`H_u > V / 2`)**: reserves `minExtent = H_u + V / 2`, leaving the bottom half of the viewport open for the reply.

Because the reported extent is `max(minExtent, actualContentExtent)`, `maxScrollExtent` stays **completely flat** while tokens fill the reserved stage — zero layout jumps.''';

const _longStreamingReply = '''
## 1. Bidirectional `Viewport(center:)`

Instead of flipping the entire list upside down with `reverse: true`, `TurnScrollView` splits your chronological list at `_centerIndex`:

- **Above center** (`GrowthDirection.reverse`): older messages grow upward into negative scroll coordinates. Prepending history adds items to the top of this sliver without moving a single visible pixel (`0.0px` shift).
- **Below center** (`GrowthDirection.forward`): recent turns and the active `SliverTurnStage` grow naturally downward.

## 2. Streaming GFM with `completeMarkdown`

Notice as this paragraph streams in: **bold phrases**, *italic emphasis*, `inline_code_tokens`, and [package links](https://pub.dev/packages/turns) stay cleanly styled **mid-token** instead of flashing raw `**` or `` ` `` markers.

Once a blank line closes a top-level block, `MarkdownSession` freezes that segment permanently:

| Concern | `ListView(reverse: true)` | `TurnScrollView` |
| :--- | :--- | :--- |
| Prepend pagination | Shifts scroll offset unless compensated | `0.0px` shift via `Viewport(center:)` |
| Active turn pin | Manual spacer math + 1-frame jump | Single-pass `SliverTurnStage` |
| Streaming markdown | Full-document reparse per token | Incremental `MarkdownSession` cache |
| User scroll mid-stream | Fights `jumpTo(maxScrollExtent)` | Disengages immediately on drag/wheel |

## 3. Minimal Integration Pattern

Try scrolling up right now while this code block is still streaming — the viewport will never yank you back down, and the **Copy** button appears automatically once the fence settles:

```dart
final controller = TurnScrollController();

TurnScrollView(
  controller: controller,
  itemCount: messages.length,
  itemId: (index) => messages[index].id,
  pinnedId: activeTurnUserId,
  padding: EdgeInsets.fromLTRB(16, 16, 16, composerHeight + 24),
  itemBuilder: (context, index) {
    final message = messages[index];
    return CoilChatMessage(
      sender: message.isUser
          ? CoilChatSender.user
          : CoilChatSender.assistant,
      entrance: message.isFresh
          ? CoilChatMessageEntrance.animated
          : CoilChatMessageEntrance.none,
      child: CoilMarkdown(
        message.markdown,
        streaming: message.isStreaming,
      ),
    );
  },
);
```

### 4. Follow-Up From the Bottom

Because this reply is now taller than the viewport, `actualContentExtent` has cleanly overtaken `minExtent`. Send another prompt from the composer below and `SliverTurnStage` will hand off to your new turn seamlessly — springing it right back to the top edge with zero jank.''';

/// Draws the active [SliverTurnStage] over the transcript: the turn it lays
/// out (the prompt and its reply) and the empty space it reserves below so
/// the prompt can stay pinned while the reply is still short.
///
/// Reads the stage's render object after every frame; nothing here feeds
/// back into layout.
class _StageOverlay extends StatefulWidget {
  const _StageOverlay({required this.scrollViewKey});

  final GlobalKey scrollViewKey;

  @override
  State<_StageOverlay> createState() => _StageOverlayState();
}

class _StageOverlayState extends State<_StageOverlay> {
  ({Rect turn, Rect reserved, double reservedExtent})? _geometry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  RenderViewport? _findViewport(RenderObject node) {
    if (node is RenderViewport) return node;
    RenderViewport? found;
    node.visitChildren((child) {
      found ??= _findViewport(child);
    });
    return found;
  }

  void _measure(Duration _) {
    if (!mounted) return;
    // Every frame, for as long as the overlay is shown.
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    final root = widget.scrollViewKey.currentContext?.findRenderObject();
    final self = context.findRenderObject();
    final viewport = root == null ? null : _findViewport(root);
    RenderSliverTurnStage? stage;
    viewport?.visitChildren((child) {
      if (child is RenderSliverTurnStage) stage = child;
    });
    final next = _geometryOf(viewport, stage, self);
    if (next != _geometry) setState(() => _geometry = next);
  }

  ({Rect turn, Rect reserved, double reservedExtent})? _geometryOf(
    RenderViewport? viewport,
    RenderSliverTurnStage? stage,
    RenderObject? self,
  ) {
    if (viewport == null ||
        stage == null ||
        self is! RenderBox ||
        !self.hasSize ||
        stage.geometry == null ||
        stage.geometry!.paintExtent <= 0) {
      return null;
    }
    final parentData = stage.parentData;
    if (parentData is! SliverPhysicalParentData) return null;
    // Where the stage's leading edge sits in the viewport, even when it has
    // scrolled partly off the top.
    final top = parentData.paintOffset.dy - stage.constraints.scrollOffset;
    final origin = self.globalToLocal(viewport.localToGlobal(Offset(0, top)));
    final width = self.size.width;
    final content = stage.actualContentExtent;
    final total = math.max(stage.minExtent, content);
    return (
      turn: Rect.fromLTWH(8, origin.dy, width - 16, content),
      reserved: Rect.fromLTWH(
        8,
        origin.dy + content,
        width - 16,
        total - content,
      ),
      reservedExtent: total - content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _geometry;
    if (geometry == null) return const SizedBox.expand();
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return ClipRect(
      child: CustomPaint(
        painter: _StagePainter(
          turn: geometry.turn,
          reserved: geometry.reserved,
          stroke: colors.brandMark,
          fill: colors.brandWash,
          labelStyle: text.micro.copyWith(
            color: colors.brandInk,
            fontWeight: text.emphasis,
          ),
          turnLabel: 'SliverTurnStage · pinned turn',
          reservedLabel: geometry.reservedExtent < 1
              ? null
              : 'Reserved ${geometry.reservedExtent.round()} px · shrinks as '
                    'the reply grows',
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _StagePainter extends CustomPainter {
  const _StagePainter({
    required this.turn,
    required this.reserved,
    required this.stroke,
    required this.fill,
    required this.labelStyle,
    required this.turnLabel,
    required this.reservedLabel,
  });

  final Rect turn;
  final Rect reserved;
  final Color stroke;
  final Color fill;
  final TextStyle labelStyle;
  final String turnLabel;
  final String? reservedLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    _dashedRect(canvas, turn, line);
    if (reserved.height > 0.5) {
      canvas.drawRect(
        reserved,
        Paint()..color = fill.withValues(alpha: fill.a * 0.55),
      );
      _hatch(canvas, reserved, stroke.withValues(alpha: 0.18));
      _dashedRect(canvas, reserved, line);
    }
    _label(canvas, turnLabel, turn.topLeft + const Offset(6, 4));
    if (reservedLabel case final label?) {
      _label(canvas, label, reserved.topLeft + const Offset(6, 6));
    }
  }

  void _label(Canvas canvas, String label, Offset at) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = (at & painter.size).inflate(4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()..color = fill,
    );
    painter.paint(canvas, at);
  }

  void _hatch(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas
      ..save()
      ..clipRect(rect);
    for (var x = rect.left - rect.height; x < rect.right; x += 10) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        paint,
      );
    }
    canvas.restore();
  }

  void _dashedRect(Canvas canvas, Rect rect, Paint paint) {
    void dashed(Offset a, Offset b) {
      final length = (b - a).distance;
      if (length <= 0) return;
      final dir = (b - a) / length;
      for (var d = 0.0; d < length; d += 9) {
        canvas.drawLine(
          a + dir * d,
          a + dir * math.min(d + 5, length),
          paint,
        );
      }
    }

    dashed(rect.topLeft, rect.topRight);
    dashed(rect.topRight, rect.bottomRight);
    dashed(rect.bottomRight, rect.bottomLeft);
    dashed(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.turn != turn ||
      old.reserved != reserved ||
      old.stroke != stroke ||
      old.fill != fill ||
      old.turnLabel != turnLabel ||
      old.reservedLabel != reservedLabel;
}
