import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:motor/motor.dart';
import 'package:turns/turns.dart';

/// Flagship AI assistant demo exercising [TurnScrollView] with `pinnedId`
/// ([SliverTurnStage] active-turn reservation), [CoilThinkingSteps],
/// [CoilMarkdown] streaming completion, [MarkdownSession] telemetry,
/// `0.0px`-shift prepend pagination, and a measured [CoilInputMessage]
/// composer.
class AiAssistantDemo extends StatefulWidget {
  /// Creates the AI assistant demo.
  const AiAssistantDemo({super.key});

  @override
  State<AiAssistantDemo> createState() => _AiAssistantDemoState();
}

enum _Role { user, assistant }

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
      chunkSize: 7,
      tick: const Duration(milliseconds: 24),
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
      chunkSize: 11,
      tick: const Duration(milliseconds: 22),
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
      chunkSize: 9,
      tick: const Duration(milliseconds: 24),
    );
  }

  void _startTurn({
    required String prompt,
    required List<_ThinkingStepData> steps,
    required String reply,
    required int chunkSize,
    required Duration tick,
  }) {
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
      thinkingLabel: 'Thinking…',
      thinkingSteps: [steps.first],
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
      if (done) {
        timer.cancel();
        _streamTimer = null;
      }
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

    return ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          _AiHeaderBar(
            isStreaming: _isStreaming,
            pinActive: _controller.isPinActive,
            stableBlocks: _stableBlockCount,
            hasPendingBlock: _hasPendingBlock,
            remainingOlderPages: remainingPages,
            onQuickShort: _sendQuickShort,
            onQuickLong: _sendQuickLong,
            onLoadOlder: remainingPages > 0 ? _loadOlderTurns : null,
          ),
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
                      controller: _controller,
                      edgeFades: CoilEdgeFades.none,
                      keyboard: false,
                      child: TurnScrollView<Object>(
                        controller: _controller,
                        itemCount: _messages.length,
                        itemId: (i) => _messages[i].id,
                        pinnedId: _pinnedId,
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
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _composerHeight + 14,
                      child: Center(
                        child: _JumpToBottomButton(
                          buttonKey: const Key('ai.jump_bottom'),
                          listenable: _controller.isAwayFromBottom,
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
                                    'Ask a follow-up — pins your turn at top…',
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

class _AiHeaderBar extends StatelessWidget {
  const _AiHeaderBar({
    required this.isStreaming,
    required this.pinActive,
    required this.stableBlocks,
    required this.hasPendingBlock,
    required this.remainingOlderPages,
    required this.onQuickShort,
    required this.onQuickLong,
    required this.onLoadOlder,
  });

  final bool isStreaming;
  final ValueListenable<bool> pinActive;
  final int stableBlocks;
  final bool hasPendingBlock;
  final int remainingOlderPages;
  final VoidCallback onQuickShort;
  final VoidCallback onQuickLong;
  final VoidCallback? onLoadOlder;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaces[1],
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(LucideIcons.sparkles, size: 16, color: colors.brandInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Assistant',
                    style: text.subtitle.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: pinActive,
                  builder: (context, isPinned, _) {
                    final stageLabel = isStreaming
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
                      child: Text(stageLabel, style: text.micro.tabular),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                CoilButton(
                  key: const Key('ai.quick_short'),
                  variant: CoilButtonVariant.secondary,
                  size: CoilSize.compact,
                  leading: const Icon(LucideIcons.zap, size: 14),
                  onPressed: onQuickShort,
                  child: const Text('Quick short reply'),
                ),
                CoilButton(
                  key: const Key('ai.quick_long'),
                  variant: CoilButtonVariant.secondary,
                  size: CoilSize.compact,
                  leading: const Icon(LucideIcons.fileCode2, size: 14),
                  onPressed: onQuickLong,
                  child: const Text('Deep-dive GFM stream'),
                ),
                CoilButton(
                  key: const Key('ai.load_older'),
                  variant: CoilButtonVariant.tertiary,
                  size: CoilSize.compact,
                  leading: const Icon(LucideIcons.history, size: 14),
                  onPressed: onLoadOlder,
                  child: Text(
                    remainingOlderPages > 0
                        ? 'Load older ($remainingOlderPages left)'
                        : 'History complete',
                  ),
                ),
              ],
            ),
          ],
        ),
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
    required this.listenable,
    required this.onPressed,
  });

  final Key buttonKey;
  final ValueListenable<bool> listenable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, visible, child) => SingleMotionBuilder(
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
      ),
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
Try tapping **Quick short reply**, **Deep-dive GFM stream**, or typing in the composer below:

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
