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

/// Canonical showcase for [CustomTurnScrollView] on a bounded sliver-rich
/// onboarding flow (~10–25 messages).
///
/// Composes a collapsing [SliverPersistentHeader] hero bar, an interactive
/// goal-picker [SliverGrid], a [SliverTurnList] conversation, and a
/// [SliverTurnStage] active turn stage when the user sends a prompt or
/// continues with their selected goals.
class OnboardingDemo extends StatefulWidget {
  /// Creates the bounded onboarding sliver-chat demo.
  const OnboardingDemo({super.key});

  @override
  State<OnboardingDemo> createState() => _OnboardingDemoState();
}

enum _OnboardingRole { assistant, user }

@immutable
class _OnboardingGoal {
  const _OnboardingGoal({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primitive,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String primitive;
}

@immutable
class _QuickReplyChip {
  const _QuickReplyChip({
    required this.id,
    required this.label,
    required this.prompt,
    required this.icon,
    required this.targetStep,
  });

  final String id;
  final String label;
  final String prompt;
  final IconData icon;
  final int targetStep;
}

@immutable
class _OnboardingMessage {
  const _OnboardingMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.time,
    this.streaming = false,
  });

  final String id;
  final _OnboardingRole role;
  final String text;
  final String time;
  final bool streaming;

  _OnboardingMessage copyWith({String? text, bool? streaming}) =>
      _OnboardingMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        time: time,
        streaming: streaming ?? this.streaming,
      );
}

const _step1MessageId = 'onboarding-step-1';

const _goals = <_OnboardingGoal>[
  _OnboardingGoal(
    id: 'ai',
    title: 'AI Assistant',
    subtitle: 'Turn stage & streaming GFM',
    icon: LucideIcons.sparkles,
    primitive: 'TurnScrollView + SliverTurnStage',
  ),
  _OnboardingGoal(
    id: 'channels',
    title: 'Team Channels',
    subtitle: 'Sticky sections & deep links',
    icon: LucideIcons.hash,
    primitive: 'TurnScrollView.sectioned',
  ),
  _OnboardingGoal(
    id: 'dm',
    title: 'Direct Messages',
    subtitle: '0px prepends & tapbacks',
    icon: LucideIcons.messageCircle,
    primitive: 'TurnScrollView.sectioned (inline)',
  ),
  _OnboardingGoal(
    id: 'support',
    title: 'Support Desk',
    subtitle: 'Guided triage & macros',
    icon: LucideIcons.lifeBuoy,
    primitive: 'CustomTurnScrollView + SliverTurnList',
  ),
];

const _quickReplies = <_QuickReplyChip>[
  _QuickReplyChip(
    id: 'stage',
    label: 'Show SliverTurnStage code',
    prompt: 'Show me how SliverTurnStage fits inside CustomTurnScrollView.',
    icon: LucideIcons.code2,
    targetStep: 3,
  ),
  _QuickReplyChip(
    id: 'compare',
    label: 'When to use TurnScrollView?',
    prompt:
        'When should I pick TurnScrollView over CustomTurnScrollView for a '
        'production chat app?',
    icon: LucideIcons.layers,
    targetStep: 3,
  ),
  _QuickReplyChip(
    id: 'finish',
    label: 'Wrap up setup',
    prompt: 'Looks great — give me a quick launch checklist to wrap up.',
    icon: LucideIcons.checkCircle2,
    targetStep: 4,
  ),
];

class _OnboardingDemoState extends State<OnboardingDemo> {
  final _controller = TurnScrollController();
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();

  late List<_OnboardingMessage> _messages;
  final _selectedGoalIds = <String>{'ai'};
  final _freshIds = <String>{};
  final _copyControllers = <String, CoilCopyController>{};
  final _timers = <Timer>[];

  String? _activePromptId;
  String? _streamingMessageId;
  Timer? _streamTimer;

  int _currentStep = 1;
  int _nextTurnNumber = 4;
  double _composerHeight = 132;

  static const _collapsedHeaderHeight = 72.0;
  static const _expandedHeaderHeight = 176.0;
  static const _headerBreathingGap = 12.0;

  bool get _isStreaming => _streamingMessageId != null;

  @override
  void initState() {
    super.initState();
    _messages = _buildInitialMessages();
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
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

  void _toggleGoal(String id) {
    setState(() {
      if (_selectedGoalIds.contains(id)) {
        _selectedGoalIds.remove(id);
      } else {
        _selectedGoalIds.add(id);
      }
    });
  }

  void _continueWithSelection() {
    if (_selectedGoalIds.isEmpty) return;
    final picked = [
      for (final goal in _goals)
        if (_selectedGoalIds.contains(goal.id)) goal,
    ];
    final names = picked.map((g) => g.title).join(', ');
    final prompt = picked.length == 1
        ? 'I want to build a ${picked.first.title} flow.'
        : 'I want to build flows for: $names.';
    final reply = _buildGoalReply(picked);
    _sendOnboardingTurn(
      prompt: prompt,
      reply: reply,
      nextStep: math.max(_currentStep, 2),
    );
  }

  void _handleQuickReply(_QuickReplyChip chip) {
    final reply = switch (chip.id) {
      'stage' => _stageSnippetReply,
      'compare' => _comparePrimitivesReply,
      'finish' => _buildFinishReply(_selectedGoalIds),
      _ => _buildCustomReply(chip.prompt),
    };
    _sendOnboardingTurn(
      prompt: chip.prompt,
      reply: reply,
      nextStep: math.max(_currentStep, chip.targetStep),
    );
  }

  void _handleComposerSend(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _sendOnboardingTurn(
      prompt: trimmed,
      reply: _buildCustomReply(trimmed),
      nextStep: math.min(4, math.max(_currentStep + 1, 2)),
    );
  }

  void _stopStreaming() {
    _streamTimer?.cancel();
    _streamTimer = null;
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
                  ? '_Stopped before output started._'
                  : message.text,
            )
          else
            message,
      ];
    });
  }

  void _sendOnboardingTurn({
    required String prompt,
    required String reply,
    required int nextStep,
  }) {
    if (_isStreaming) {
      _stopStreaming();
    }

    final turnNumber = _nextTurnNumber++;
    final userId = 'onboarding-user-$turnNumber';
    final assistantId = 'onboarding-assistant-$turnNumber';
    final time = _formatStepClock(turnNumber);

    final userMessage = _OnboardingMessage(
      id: userId,
      role: _OnboardingRole.user,
      text: prompt,
      time: time,
    );
    final assistantMessage = _OnboardingMessage(
      id: assistantId,
      role: _OnboardingRole.assistant,
      text: '',
      time: time,
      streaming: true,
    );

    _markFresh(userId);
    _markFresh(assistantId);

    setState(() {
      _messages = [..._messages, userMessage, assistantMessage];
      _activePromptId = userId;
      _streamingMessageId = assistantId;
      _currentStep = nextStep.clamp(1, 4);
    });

    var cursor = 0;
    const chunkSize = 8;
    _streamTimer = Timer.periodic(const Duration(milliseconds: 22), (timer) {
      if (!mounted || _streamingMessageId != assistantId) {
        timer.cancel();
        return;
      }
      cursor = math.min(reply.length, cursor + chunkSize);
      final done = cursor >= reply.length;
      final slice = reply.substring(0, cursor);
      setState(() {
        _messages = [
          for (final message in _messages)
            if (message.id == assistantId)
              message.copyWith(text: slice, streaming: !done)
            else
              message,
        ];
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

  void _jumpToStepOne() {
    unawaited(_controller.scrollTo(_step1MessageId));
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

    return ColoredBox(
      color: colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 520;
          final horizontal = math.max<double>(
            16,
            (constraints.maxWidth - 720) / 2,
          );

          final slivers = _buildSlivers(
            context: context,
            horizontal: horizontal,
            isNarrow: isNarrow,
          );

          return Stack(
            children: [
              CoilScrollArea(
                controller: _controller,
                edgeFades: CoilEdgeFades.none,
                keyboard: false,
                semanticLabel: 'Bounded sliver onboarding conversation',
                child: CustomTurnScrollView(
                  controller: _controller,
                  pinnedId: _activePromptId,
                  applyTopPadding: false,
                  applyBottomPadding: false,
                  initialAtBottom: false,
                  padding: EdgeInsets.only(
                    top: _collapsedHeaderHeight + _headerBreathingGap,
                    bottom: _composerHeight + 24,
                  ),
                  slivers: slivers,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: _composerHeight + 12,
                child: Center(
                  child: _JumpToBottomButton(
                    buttonKey: const Key('onboarding.jump_bottom'),
                    awayFromBottom: _controller.isAwayFromBottom,
                    autoScrolling: _controller.isAutoScrolling,
                    onPressed: () => unawaited(_controller.scrollToBottom()),
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
                          child: const SizedBox(height: 16),
                        ),
                      ),
                      ColoredBox(
                        color: colors.background,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TurnsActionStrip(
                              padding: EdgeInsets.fromLTRB(
                                horizontal,
                                2,
                                horizontal,
                                8,
                              ),
                              spacing: 8,
                              children: [
                                for (final chip in _quickReplies)
                                  _QuickReplyButton(
                                    chip: chip,
                                    onPressed: () => _handleQuickReply(chip),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                horizontal,
                                0,
                                horizontal,
                                14,
                              ),
                              child: CoilInputMessage(
                                controller: _composerController,
                                focusNode: _composerFocus,
                                placeholder: Text(
                                  'Ask about slivers or reply to continue…',
                                  style: text.muted.field,
                                ),
                                status: _isStreaming
                                    ? CoilMessageStatus.streaming
                                    : CoilMessageStatus.idle,
                                onSend: _handleComposerSend,
                                onStop: _stopStreaming,
                              ),
                            ),
                          ],
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
    );
  }

  List<Widget> _buildSlivers({
    required BuildContext context,
    required double horizontal,
    required bool isNarrow,
  }) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final pinIndex = _activePromptId == null
        ? -1
        : _messages.indexWhere((m) => m.id == _activePromptId);

    return <Widget>[
      SliverPersistentHeader(
        pinned: true,
        delegate: _OnboardingHeroHeaderDelegate(
          minExtent: _collapsedHeaderHeight,
          maxExtent: _expandedHeaderHeight,
          currentStep: _currentStep,
          horizontal: horizontal,
          colors: colors,
          text: text,
          onJumpStepOne: _jumpToStepOne,
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose what you are building',
                      style: text.subtitle.copyWith(fontWeight: text.emphasis),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toggle one or more cards inside this SliverGrid, then '
                      'continue into the turn stream.',
                      style: text.muted.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CoilBadge(
                color: _selectedGoalIds.isEmpty
                    ? CoilBadgeColor.gray
                    : CoilBadgeColor.brand,
                shape: CoilBadgeShape.pill,
                size: CoilSize.compact,
                child: Text(
                  '${_selectedGoalIds.length} picked',
                  style: text.micro.tabular,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            // Padding and icon row are fixed; the title and a subtitle that
            // may wrap on narrow cards grow with the text scale.
            mainAxisExtent:
                56 + MediaQuery.textScalerOf(context).scale(isNarrow ? 72 : 56),
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final goal = _goals[index];
            return _GoalOptionCard(
              key: Key('onboarding.goal.${goal.id}'),
              goal: goal,
              selected: _selectedGoalIds.contains(goal.id),
              onTap: () => _toggleGoal(goal.id),
            );
          }, childCount: _goals.length),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 20),
        sliver: SliverToBoxAdapter(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              CoilButton(
                key: const Key('onboarding.continue'),
                size: CoilSize.compact,
                trailing: const Icon(LucideIcons.arrowRight, size: 14),
                onPressed: _selectedGoalIds.isEmpty
                    ? null
                    : _continueWithSelection,
                child: const Text('Continue with selection'),
              ),
              Text(
                _selectedGoalIds.isEmpty
                    ? 'Pick at least one card to continue'
                    : 'Appends your selection and pins it in SliverTurnStage',
                style: text.muted.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Guided setup thread',
                        style: text.caption.copyWith(fontWeight: text.emphasis),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ColoredBox(
                        color: colors.border,
                        child: const SizedBox(height: 1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<bool>(
                valueListenable: _controller.isPinActive,
                builder: (context, isPinned, _) => CoilBadge(
                  variant: CoilBadgeVariant.dot,
                  color: _isStreaming
                      ? CoilBadgeColor.emerald
                      : isPinned
                      ? CoilBadgeColor.brand
                      : CoilBadgeColor.gray,
                  shape: CoilBadgeShape.pill,
                  size: CoilSize.compact,
                  child: Text(
                    _isStreaming
                        ? 'Streaming'
                        : isPinned
                        ? 'Stage pinned'
                        : '${_messages.length} turns',
                    style: text.micro.tabular,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (pinIndex < 0)
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          sliver: SliverTurnList(
            itemCount: _messages.length,
            itemId: (index) => _messages[index].id,
            itemSpacing: 14,
            itemBuilder: (context, index) =>
                _buildMessageItem(context, _messages[index]),
          ),
        )
      else ...[
        if (pinIndex > 0)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 14),
            sliver: SliverTurnList(
              itemCount: pinIndex,
              itemId: (index) => _messages[index].id,
              itemSpacing: 14,
              itemBuilder: (context, index) =>
                  _buildMessageItem(context, _messages[index]),
            ),
          ),
        SliverTurnStage(
          anchorSliver: SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            sliver: SliverToBoxAdapter(
              child: TurnScrollItem(
                id: _messages[pinIndex].id,
                child: _buildMessageItem(context, _messages[pinIndex]),
              ),
            ),
          ),
          afterSliver: SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 0),
            sliver: SliverTurnList(
              itemCount: _messages.length - pinIndex - 1,
              itemId: (index) => _messages[pinIndex + 1 + index].id,
              itemSpacing: 14,
              itemBuilder: (context, index) =>
                  _buildMessageItem(context, _messages[pinIndex + 1 + index]),
            ),
          ),
        ),
      ],
    ];
  }

  Widget _buildMessageItem(BuildContext context, _OnboardingMessage message) {
    final entrance = _freshIds.contains(message.id)
        ? CoilChatMessageEntrance.animated
        : CoilChatMessageEntrance.none;

    if (message.role == _OnboardingRole.user) {
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
            onPressed: () => unawaited(
              copy.copy(message.text, context: context),
            ),
          ),
      ],
      child: message.text.isEmpty
          ? Text(
              'Drafting tailored setup…',
              style: CoilTheme.textOf(context).muted.body,
            )
          : CoilMarkdown(
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
    );
  }
}

class _OnboardingHeroHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _OnboardingHeroHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.currentStep,
    required this.horizontal,
    required this.colors,
    required this.text,
    required this.onJumpStepOne,
  });

  @override
  final double minExtent;

  @override
  final double maxExtent;

  final int currentStep;
  final double horizontal;
  final CoilColors colors;
  final CoilTextTheme text;
  final VoidCallback onJumpStepOne;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = math.max<double>(1, maxExtent - minExtent);
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    final expandedOpacity = (1 - t * 2).clamp(0.0, 1.0);
    final compactOpacity = ((t - 0.35) / 0.65).clamp(0.0, 1.0);

    final heroTopColor = Color.lerp(colors.brandWash, colors.surfaces[1], t)!;
    final heroBottomColor = Color.lerp(
      Color.lerp(colors.brandWash, colors.background, 0.55),
      colors.surfaces[1],
      t,
    )!;

    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [heroTopColor, heroBottomColor],
          ),
          // The border token is already translucent; scale it, never replace
          // its alpha, or it turns into a solid black (or white) rule.
          border: Border(
            bottom: BorderSide(
              color: colors.border.withValues(
                alpha:
                    colors.border.a * (overlapsContent || t > 0.05 ? 1 : 0.6),
              ),
            ),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Expanded hero card body — smoothly fades and translates upward
            // as the header collapses into the 72px pinned top bar.
            // Expanded title and subtitle sit just above the progress track
            // and fade as the header collapses toward the compact bar.
            Positioned(
              left: horizontal,
              right: horizontal,
              bottom: 26,
              child: IgnorePointer(
                ignoring: expandedOpacity <= 0.05,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome to Turns',
                        style: text.title.copyWith(fontWeight: text.emphasis),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bounded sliver chat — collapsing hero, grid, and '
                        'turn stage',
                        style: text.muted.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // The step track stays on the header's bottom edge at every
            // extent, so a half-collapsed header never reads as empty.
            Positioned(
              left: horizontal,
              right: horizontal,
              bottom: 12,
              child: _StepProgressTrack(
                currentStep: currentStep,
                totalSteps: 4,
                colors: colors,
              ),
            ),
            // Persistent 72px top bar hosting the compact title, step pill,
            // and "Step 1" chip.
            Positioned(
              left: horizontal,
              right: horizontal,
              top: 0,
              height: minExtent - 18,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.compass,
                          size: 16,
                          color: colors.brandInk,
                        ),
                        const SizedBox(width: 8),
                        if (compactOpacity > 0.02) ...[
                          Flexible(
                            child: Opacity(
                              opacity: compactOpacity,
                              child: Text(
                                'Onboarding',
                                style: text.body.copyWith(
                                  fontWeight: text.emphasis,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: CoilBadge(
                            variant: CoilBadgeVariant.dot,
                            color: CoilBadgeColor.brand,
                            shape: CoilBadgeShape.pill,
                            size: CoilSize.compact,
                            child: Text(
                              'Step $currentStep of 4',
                              style: text.micro.tabular,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CoilButton(
                    key: const Key('onboarding.jump_step1'),
                    variant: CoilButtonVariant.secondary,
                    size: CoilSize.compact,
                    leading: const Icon(LucideIcons.cornerLeftUp, size: 13),
                    onPressed: onJumpStepOne,
                    child: const Text('Step 1'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_OnboardingHeroHeaderDelegate oldDelegate) =>
      minExtent != oldDelegate.minExtent ||
      maxExtent != oldDelegate.maxExtent ||
      currentStep != oldDelegate.currentStep ||
      horizontal != oldDelegate.horizontal ||
      colors != oldDelegate.colors ||
      text != oldDelegate.text;
}

class _QuickReplyButton extends StatelessWidget {
  const _QuickReplyButton({required this.chip, required this.onPressed});

  final _QuickReplyChip chip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CoilButton(
    key: Key('onboarding.chip.${chip.id}'),
    variant: CoilButtonVariant.secondary,
    size: CoilSize.compact,
    leading: Icon(chip.icon, size: 13),
    onPressed: onPressed,
    child: Text(chip.label),
  );
}

class _StepProgressTrack extends StatelessWidget {
  const _StepProgressTrack({
    required this.currentStep,
    required this.totalSteps,
    required this.colors,
  });

  final int currentStep;
  final int totalSteps;
  final CoilColors colors;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= totalSteps; i++) ...[
        if (i > 1) const SizedBox(width: 6),
        Expanded(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: i <= currentStep
                  ? colors.brand
                  : colors.border.withValues(alpha: 0.7),
              shape: const StadiumBorder(),
            ),
            child: const SizedBox(height: 4),
          ),
        ),
      ],
    ],
  );
}

class _GoalOptionCard extends StatelessWidget {
  const _GoalOptionCard({
    required this.goal,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _OnboardingGoal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final radius = BorderRadius.circular(14);

    return Semantics(
      button: true,
      selected: selected,
      label: '${goal.title}, ${goal.subtitle}',
      child: CoilInteraction(
        onPressed: onTap,
        excludeFromSemantics: true,
        builder: (context, states, child) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          final fill = selected
              ? Color.lerp(colors.surfaces[1], colors.brandWash, 0.55)!
              : pressed
              ? colors.active
              : hovered
              ? colors.hover
              : colors.surfaces[1];
          final borderColor = selected ? colors.brand : colors.border;

          return CoilFocusRing(
            visible: states.contains(WidgetState.focused),
            borderRadius: radius,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(
                    color: borderColor,
                    width: selected ? 1.5 : 1,
                  ),
                ),
              ),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: selected ? colors.brandWash : colors.muted,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        goal.icon,
                        size: 15,
                        color: selected
                            ? colors.brandInk
                            : colors.mutedForeground,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(
                      LucideIcons.checkCircle2,
                      size: 16,
                      color: colors.brand,
                    )
                  else
                    Icon(
                      LucideIcons.circle,
                      size: 16,
                      color: colors.border,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                goal.title,
                style: text.body.copyWith(fontWeight: text.emphasis),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                goal.subtitle,
                style: text.muted.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
          debugLabel: 'OnboardingDemo.jumpBottom',
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
        semanticLabel: 'Jump to bottom',
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

String _formatStepClock(int turnNumber) {
  final minutes = (turnNumber - 1) % 60;
  final mm = minutes.toString().padLeft(2, '0');
  return '09:$mm AM';
}

List<_OnboardingMessage> _buildInitialMessages() => const [
  _OnboardingMessage(
    id: _step1MessageId,
    role: _OnboardingRole.assistant,
    time: '09:00 AM',
    text: '''
Welcome! This entire onboarding flow runs inside a single **`CustomTurnScrollView`**:

- **Collapsing hero header** (`SliverPersistentHeader(pinned: true)`) shrinks cleanly from `176px` to `72px`.
- **Interactive goal picker** (`SliverGrid`) sits right above this `SliverTurnList` without nested scrollables.
- **Turn stage pinning** (`SliverTurnStage`) activates as soon as you continue or send a message below.''',
  ),
  _OnboardingMessage(
    id: 'onboarding-step-2',
    role: _OnboardingRole.user,
    time: '09:01 AM',
    text:
        'When should I reach for CustomTurnScrollView instead of '
        'TurnScrollView?',
  ),
  _OnboardingMessage(
    id: 'onboarding-step-3',
    role: _OnboardingRole.assistant,
    time: '09:02 AM',
    text: '''
Use **`CustomTurnScrollView`** for **bounded flows (~10–25 messages)** where rich Flutter slivers — collapsing app bars, hero cards, `SliverGrid` pickers, or mixed sections — belong in the same scroll surface.

For unbounded chat timelines (Slack channels, WhatsApp history, long AI threads), prefer **`TurnScrollView`** or **`TurnScrollView.sectioned`** for O(1) opening at any message and `0.0px`-shift prepend pagination.

Pick any cards above and tap **Continue with selection**, or try a quick reply below.''',
  ),
];

String _buildGoalReply(List<_OnboardingGoal> picked) {
  final bullets = picked
      .map((g) => '- **${g.title}** → `${g.primitive}` (${g.subtitle})')
      .join('\n');
  return '''
Great pick! Here is your recommended `turns` starting point:

$bullets

Notice how your message just pinned neatly below the `72px` collapsed header via **`SliverTurnStage`** while this reply streamed in — and tapping **Step 1** in the pinned header springs straight back to message #1 with exact header clearance.''';
}

const _stageSnippetReply = '''
Wrap the active turn inside **`SliverTurnStage`** at the tail of `CustomTurnScrollView.slivers`:

```dart
CustomTurnScrollView(
  controller: controller,
  pinnedId: activePromptId,
  applyTopPadding: false,
  applyBottomPadding: false,
  initialAtBottom: false,
  slivers: [
    SliverPersistentHeader(pinned: true, delegate: heroDelegate),
    SliverGrid(/* goal picker */),
    SliverTurnList(/* earlier turns */),
    SliverTurnStage(
      anchorSliver: SliverToBoxAdapter(
        child: TurnScrollItem(id: activePromptId, child: promptBubble),
      ),
      afterSliver: SliverTurnList(/* streaming reply */),
    ),
  ],
)
```

`SliverTurnStage` reserves the usable viewport height in one layout pass so `maxScrollExtent` never jumps while tokens arrive.''';

const _comparePrimitivesReply = '''
Here is the quick rule of thumb:

| Primitive | Best for | Key superpower |
| --- | --- | --- |
| `TurnScrollView` | Production AI threads & long chats | O(1) bottom/deep-link open + `0.0px` prepends |
| `TurnScrollView.sectioned` | WhatsApp / Slack / iMessage timelines | Floating or inline sticky date headers |
| `CustomTurnScrollView` | Bounded onboarding, forms, mixed slivers | Full `SliverPersistentHeader` + `SliverGrid` freedom |

Most production messaging screens should default to `TurnScrollView` or `TurnScrollView.sectioned`.''';

String _buildFinishReply(Set<String> selectedIds) {
  final summary = selectedIds.isEmpty
      ? 'your custom flow'
      : _goals
            .where((g) => selectedIds.contains(g.id))
            .map((g) => '**${g.title}**')
            .join(', ');
  return '''
You are all set for $summary! Quick checklist before shipping:

1. Attach a **`TurnScrollController`** to drive `scrollTo(...)`, `scrollToBottom()`, and `isAwayFromBottom`.
2. Wrap every sliver-list item with **`SliverTurnList`** (or `TurnScrollItem`) so offscreen `scrollTo` clears pinned headers automatically.
3. Pair streaming replies with **`CoilMarkdown(text, streaming: true)`** powered by `MarkdownSession`.''';
}

String _buildCustomReply(String prompt) =>
    '''
Got it — regarding *"$prompt"*:

Because this screen uses **`CustomTurnScrollView`**, your prompt was promoted into **`SliverTurnStage`** right below the `72px` collapsed hero bar, keeping the `SliverGrid` and earlier turns intact above.

Try tapping **Step 1** in the top bar or scrolling up to watch the hero header expand smoothly back to `176px`.''';
