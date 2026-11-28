import 'dart:async';

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';
import 'package:turns_example/src/shell/turns_action_strip.dart';

/// Slack-style channel demo showcasing [TurnScrollView.sectioned] across a
/// 3,000-message O(1) timeline with `isPinned` section headers (hairline rule
/// inline vs transparent elevated date pill when pinned), `0.0px`-shift
/// prepend pagination via [TurnScrollNotification] and `"Load earlier days"`,
/// `"10 new messages"` unread jump landing on the inline `"New"` divider,
/// cross-history [TurnScrollController.scrollTo], rich [CoilMarkdown]
/// messages, interactive reactions & threads, and live messaging.
class SlackDemo extends StatefulWidget {
  /// Creates the Slack channel demo.
  const SlackDemo({super.key});

  @override
  State<SlackDemo> createState() => _SlackDemoState();
}

class _SlackDemoState extends State<SlackDemo> {
  static const _rfcMessageId = 'msg-rfc-42';
  static const _deployMessageId = 'msg-deploy-checklist';
  static const _firstUnreadId = 'msg-unread-first';
  static const _kickoffMessageId = 'msg-h0420';
  static final _today = DateTime(2026, 5, 15);

  final _controller = TurnScrollController(debugLabel: 'SlackDemo');
  final _composerController = TextEditingController();

  late List<_SlackMessage> _messages;
  late List<List<_SlackMessage>> _archivePages;
  final _expandedThreads = <String>{};

  bool _showUnreadPill = true;
  bool _isAutoLoadingEarlier = false;
  String? _highlightedId;
  Timer? _highlightTimer;
  Timer? _autoLoadTimer;
  int _nextMessageNumber = 1;

  @override
  void initState() {
    super.initState();
    _messages = _buildInitialMessages();
    _archivePages = _buildArchivePages();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _autoLoadTimer?.cancel();
    _composerController.dispose();
    _controller.dispose();
    super.dispose();
  }

  int get _unreadCount {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].id == _firstUnreadId) {
        return _messages.length - i;
      }
    }
    return 0;
  }

  Future<bool> _jumpToMessage(String id, {double alignment = 0.08}) async {
    _highlightTimer?.cancel();
    // Highlight as soon as the flight looks done, not once it settles.
    if (!await _controller.scrollTo(id, alignment: alignment).ended) {
      return false;
    }
    if (!mounted) return false;
    setState(() => _highlightedId = id);
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() {
        if (_highlightedId == id) _highlightedId = null;
      });
    });
    return true;
  }

  Future<void> _jumpToUnread() async {
    final arrived = await _jumpToMessage(_firstUnreadId);
    if (!mounted || !arrived) return;
    if (_showUnreadPill) {
      setState(() => _showUnreadPill = false);
    }
  }

  // Any distance animates: long flights recenter next to the bottom and glide
  // the last viewport, so jumping back from the Feb 1 kickoff stays cheap.
  Future<void> _scrollToBottom() => _controller.scrollToBottom();

  void _dismissUnread() {
    if (!_showUnreadPill) return;
    setState(() => _showUnreadPill = false);
  }

  void _loadEarlierDays({bool fromAutoScroll = false}) {
    if (_archivePages.isEmpty) {
      if (_isAutoLoadingEarlier) {
        setState(() => _isAutoLoadingEarlier = false);
      }
      return;
    }
    if (!fromAutoScroll) {
      _autoLoadTimer?.cancel();
    }
    setState(() {
      final earlierPage = _archivePages.removeAt(0);
      _messages = [...earlierPage, ..._messages];
      _isAutoLoadingEarlier = false;
    });
  }

  bool _onTurnScroll(TurnScrollNotification notification) {
    if (notification.isProgrammatic) return false;
    if (_archivePages.isEmpty || _isAutoLoadingEarlier) return false;
    if (notification.leadingExtent > 160) return false;

    setState(() => _isAutoLoadingEarlier = true);
    _autoLoadTimer?.cancel();
    _autoLoadTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _loadEarlierDays(fromAutoScroll: true);
    });
    return false;
  }

  void _toggleReaction(String messageId, _ReactionKind kind) {
    setState(() {
      for (var i = _messages.length - 1; i >= 0; i--) {
        final message = _messages[i];
        if (message.id != messageId) continue;
        final index = message.reactions.indexWhere((r) => r.kind == kind);
        if (index < 0) return;
        final current = message.reactions[index];
        final nextReacted = !current.reactedByMe;
        message.reactions[index] = _SlackReaction(
          kind: current.kind,
          count: current.count + (nextReacted ? 1 : -1),
          reactedByMe: nextReacted,
        );
        return;
      }
    });
  }

  void _toggleThread(String messageId) {
    setState(() {
      if (!_expandedThreads.remove(messageId)) {
        _expandedThreads.add(messageId);
      }
    });
  }

  void _handleSend(String text) {
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final newMessage = _SlackMessage(
      id: 'msg-live-${_nextMessageNumber++}',
      day: _today,
      author: _SlackAuthor.you,
      timestamp: '$hour12:$minute $period',
      markdown: text,
      reactions: [
        const _SlackReaction(
          kind: _ReactionKind.thumbsUp,
          count: 1,
          reactedByMe: true,
        ),
      ],
    );

    setState(() {
      _messages = [..._messages, newMessage];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_scrollToBottom());
    });
  }

  void _insertMarkdownSnippet() {
    const snippet =
        'Verified `TurnScrollView.sectioned` `isPinned` date header:\n'
        '```dart\n'
        'TurnScrollView<DateTime>.sectioned(\n'
        '  itemCount: messages.length,\n'
        '  itemId: (i) => messages[i].id,\n'
        '  sectionId: (i) => messages[i].day,\n'
        '  sectionHeaderBuilder: (context, day, isPinned) =>\n'
        '      DayHeader(day: day, isPinned: isPinned),\n'
        '  itemBuilder: buildRow,\n'
        ');\n'
        '```';
    final existing = _composerController.text;
    _composerController
      ..text = existing.isEmpty ? snippet : '$existing\n$snippet'
      ..selection = TextSelection.collapsed(
        offset: _composerController.text.length,
      );
  }

  @override
  Widget build(BuildContext context) {
    return CoilTheme.override(
      transform: (theme) => theme.copyWith(
        brandSelection: true,
        colors: CoilColors.fromSeed(
          brightness: theme.colors.brightness,
          brand: const Color(0xFF7C3AED),
          neutralHue: 305,
          neutralChroma: 0.008,
        ),
      ),
      child: Builder(
        builder: (context) {
          final theme = CoilTheme.of(context);
          final colors = theme.colors;
          final motion = CoilTheme.motionOf(context);
          final markdownStyle = CoilMarkdownStyle.fallback(context).merge(
            CoilMarkdownStyle(
              blockGap: 0.55,
              headingGapAbove: 0.85,
              headingGapBelow: 0.3,
              listItemGap: 0.25,
              codeFill: colors.muted,
              linkStyle: TextStyle(
                color: colors.brandInk,
                decoration: TextDecoration.underline,
                decorationColor: colors.brandInk.withValues(alpha: 0.45),
              ),
            ),
          );

          return ColoredBox(
            color: colors.background,
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _ChannelHeader(messageCount: _messages.length),
                ),
                _BookmarksBar(
                  onJumpRfc: () => unawaited(_jumpToMessage(_rfcMessageId)),
                  onJumpDeploy: () =>
                      unawaited(_jumpToMessage(_deployMessageId)),
                  onJumpUnread: () => unawaited(_jumpToUnread()),
                  onJumpKickoff: () =>
                      unawaited(_jumpToMessage(_kickoffMessageId)),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    child: Stack(
                      children: [
                        NotificationListener<TurnScrollNotification>(
                          onNotification: _onTurnScroll,
                          child: CoilScrollArea(
                            controller: _controller,
                            edgeFades: CoilEdgeFades.none,
                            semanticLabel:
                                '#engineering-scroll channel messages',
                            child: TurnScrollView<DateTime>.sectioned(
                              controller: _controller,
                              itemCount: _messages.length,
                              itemId: (i) => _messages[i].id,
                              sectionId: (i) => _messages[i].day,
                              applyTopPadding: false,
                              applyBottomPadding: false,
                              itemSpacing: 2,
                              sectionHeaderSpacing: 2,
                              padding: const EdgeInsets.only(bottom: 16),
                              leadingSlivers: [
                                SliverToBoxAdapter(
                                  child: _ChannelWelcomeBanner(
                                    remainingArchivePages: _archivePages.length,
                                    loadingEarlier: _isAutoLoadingEarlier,
                                    onLoadEarlier: _loadEarlierDays,
                                  ),
                                ),
                              ],
                              sectionHeaderBuilder: (context, day, isPinned) =>
                                  _DaySectionHeader(
                                    label: _formatDay(day),
                                    isPinned: isPinned,
                                  ),
                              itemBuilder: (context, i) {
                                final message = _messages[i];
                                return _SlackMessageRow(
                                  message: message,
                                  markdownStyle: markdownStyle,
                                  highlighted: _highlightedId == message.id,
                                  showUnreadDivider:
                                      message.id == _firstUnreadId,
                                  threadExpanded: _expandedThreads.contains(
                                    message.id,
                                  ),
                                  onToggleReaction: (kind) =>
                                      _toggleReaction(message.id, kind),
                                  onToggleThread: () =>
                                      _toggleThread(message.id),
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 44,
                          left: 16,
                          right: 16,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: SingleMotionBuilder(
                              value: _showUnreadPill ? 1.0 : 0.0,
                              motion: _showUnreadPill
                                  ? motion.standard
                                  : motion.fadeExit,
                              builder: (context, t, child) {
                                final clamped = t.clamp(0.0, 1.0);
                                if (!_showUnreadPill && clamped <= 0.01) {
                                  return const SizedBox.shrink();
                                }
                                return IgnorePointer(
                                  ignoring: !_showUnreadPill,
                                  child: Opacity(
                                    opacity: clamped,
                                    child: Transform.translate(
                                      offset: Offset(0, (1 - t) * -10),
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              child: _UnreadBannerPill(
                                count: _unreadCount,
                                onJump: () => unawaited(_jumpToUnread()),
                                onDismiss: _dismissUnread,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          bottom: 12,
                          child: ListenableBuilder(
                            listenable: Listenable.merge([
                              _controller.isAwayFromBottom,
                              _controller.isAutoScrolling,
                            ]),
                            builder: (context, child) {
                              final shown =
                                  _controller.isAwayFromBottom.value &&
                                  !_controller.isAutoScrolling.value;
                              return SingleMotionBuilder(
                                value: shown ? 1.0 : 0.0,
                                motion: shown
                                    ? motion.standard
                                    : motion.fadeExit,
                                builder: (context, t, child) {
                                  final clamped = t.clamp(0.0, 1.0);
                                  if (!shown && clamped <= 0.01) {
                                    return const SizedBox.shrink();
                                  }
                                  return IgnorePointer(
                                    ignoring: !shown,
                                    child: Opacity(
                                      opacity: clamped,
                                      child: Transform.translate(
                                        offset: Offset(0, (1 - t) * 14),
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: child,
                              );
                            },
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadowColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CoilButton(
                                key: const Key('slack.jump_bottom'),
                                variant: CoilButtonVariant.brand,
                                size: CoilSize.compact,
                                leading: const Icon(
                                  LucideIcons.arrowDown,
                                  size: 14,
                                ),
                                onPressed: () => unawaited(_scrollToBottom()),
                                child: const Text('Jump to latest'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaces[1],
                    border: Border(top: BorderSide(color: colors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: CoilInputMessage(
                        controller: _composerController,
                        placeholder: const Text(
                          'Message #engineering-scroll… (Markdown supported)',
                        ),
                        leading: CoilButton.icon(
                          variant: CoilButtonVariant.ghost,
                          size: CoilSize.compact,
                          semanticLabel: 'Insert markdown snippet',
                          icon: const Icon(LucideIcons.code, size: 16),
                          onPressed: _insertMarkdownSnippet,
                        ),
                        onSend: _handleSend,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatDay(DateTime day) {
    if (day == _today) return 'Today';
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[day.weekday - 1];
    final month = months[day.month - 1];
    if (day.year < _today.year) {
      return '$weekday, $month ${day.day}, ${day.year}';
    }
    return '$weekday, $month ${day.day}';
  }

  static String _formatCount(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      if (i > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({required this.messageCount});

  final int messageCount;

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.brandWash,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(LucideIcons.hash, size: 16, color: colors.brandInk),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'engineering-scroll',
                    style: text.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'TurnScrollView.sectioned · O(1) open · isPinned headers',
                    style: text.muted.micro,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CoilBadge(
              variant: CoilBadgeVariant.dot,
              color: CoilBadgeColor.brand,
              shape: CoilBadgeShape.pill,
              size: CoilSize.compact,
              child: Text('${_SlackDemoState._formatCount(messageCount)} msgs'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarksBar extends StatelessWidget {
  const _BookmarksBar({
    required this.onJumpRfc,
    required this.onJumpDeploy,
    required this.onJumpUnread,
    required this.onJumpKickoff,
  });

  static const double _height = 44;

  final VoidCallback onJumpRfc;
  final VoidCallback onJumpDeploy;
  final VoidCallback onJumpUnread;
  final VoidCallback onJumpKickoff;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaces[1],
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        height: _height,
        child: TurnsActionStrip(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Icon(LucideIcons.bookmark, size: 13, color: colors.mutedForeground),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Text('Bookmarks', style: text.muted.micro),
            ),
            _BookmarkChip(
              key: const Key('slack.jump_rfc'),
              icon: LucideIcons.fileText,
              label: 'RFC #42 · May 13',
              onPressed: onJumpRfc,
            ),
            _BookmarkChip(
              key: const Key('slack.jump_deploy'),
              icon: LucideIcons.rocket,
              label: 'Deploy checklist · May 14',
              onPressed: onJumpDeploy,
            ),
            _BookmarkChip(
              key: const Key('slack.jump_unread'),
              icon: LucideIcons.sparkles,
              label: 'First unread · May 14',
              accent: true,
              onPressed: onJumpUnread,
            ),
            _BookmarkChip(
              key: const Key('slack.jump_kickoff'),
              icon: LucideIcons.history,
              label: 'Kickoff · #420 · Feb 1',
              onPressed: onJumpKickoff,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkChip extends StatelessWidget {
  const _BookmarkChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final radius = BorderRadius.circular(999);

    return Semantics(
      button: true,
      label: 'Jump to $label',
      child: CoilInteraction(
        onPressed: onPressed,
        excludeFromSemantics: true,
        builder: (context, states, child) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          final focused = states.contains(WidgetState.focused);
          final baseFill = accent ? colors.brandWash : colors.muted;
          final fill = pressed
              ? colors.active
              : hovered
              ? (accent
                    ? colors.brandWash.withValues(alpha: 0.28)
                    : colors.hover)
              : baseFill;
          return CoilFocusRing(
            visible: focused,
            borderRadius: radius,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(
                    color: accent
                        ? colors.brandMark.withValues(alpha: 0.35)
                        : colors.border,
                  ),
                ),
              ),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: accent ? colors.brandInk : colors.mutedForeground,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: text.micro.copyWith(
                  color: accent ? colors.brandInk : colors.foreground,
                  fontWeight: text.emphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelWelcomeBanner extends StatelessWidget {
  const _ChannelWelcomeBanner({
    required this.remainingArchivePages,
    required this.loadingEarlier,
    required this.onLoadEarlier,
  });

  final int remainingArchivePages;
  final bool loadingEarlier;
  final VoidCallback onLoadEarlier;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final hasEarlier = remainingArchivePages > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.surfaces[1],
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colors.border),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.brandFill,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Center(
                        child: Icon(
                          LucideIcons.hash,
                          size: 20,
                          color: colors.onBrandFill,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to #engineering-scroll',
                          style: text.title,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'TurnScrollView.sectioned · 3,000+ msgs',
                          style: text.muted.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Backed by TurnScrollView<DateTime>.sectioned for O(1) open, '
                '0.0px-shift prepend pagination, and section headers that '
                'adapt between hairline rules inline and transparent floating '
                'pills when isPinned == true.',
                style: text.muted.caption,
              ),
              const SizedBox(height: 12),
              CoilButton(
                key: const Key('slack.load_earlier'),
                variant: hasEarlier
                    ? CoilButtonVariant.secondary
                    : CoilButtonVariant.tertiary,
                size: CoilSize.compact,
                loading: loadingEarlier,
                leading: Icon(
                  hasEarlier ? LucideIcons.history : LucideIcons.check,
                  size: 14,
                ),
                onPressed: hasEarlier ? onLoadEarlier : null,
                child: Text(
                  hasEarlier
                      ? 'Load earlier days ($remainingArchivePages more)'
                      : 'Beginning of #engineering-scroll',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({required this.label, required this.isPinned});

  static const double _height = 40;

  final String label;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);

    final pill = DecoratedBox(
      decoration: ShapeDecoration(
        color: isPinned ? colors.surfaces[2] : colors.surfaces[1],
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: colors.border),
        ),
        shadows: isPinned
            ? [
                BoxShadow(
                  color: colors.shadowColor.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: text.micro.copyWith(fontWeight: text.emphasis),
        ),
      ),
    );

    return SizedBox(
      height: _height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: isPinned
            ? Center(child: pill)
            : Row(
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: colors.border,
                      child: const SizedBox(height: 1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: pill,
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: colors.border,
                      child: const SizedBox(height: 1),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _UnreadBannerPill extends StatelessWidget {
  const _UnreadBannerPill({
    required this.count,
    required this.onJump,
    required this.onDismiss,
  });

  final int count;
  final VoidCallback onJump;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final pillRadius = BorderRadius.circular(999);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.brandFill,
        shape: RoundedSuperellipseBorder(borderRadius: pillRadius),
        shadows: [
          BoxShadow(
            color: colors.shadowColor.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Jump to $count new messages',
            child: CoilInteraction(
              key: const Key('slack.unread_pill'),
              onPressed: onJump,
              excludeFromSemantics: true,
              builder: (context, states, child) {
                final hovered = states.contains(WidgetState.hovered);
                final pressed = states.contains(WidgetState.pressed);
                final focused = states.contains(WidgetState.focused);
                final overlay = pressed
                    ? const Color(0x24000000)
                    : hovered
                    ? const Color(0x14FFFFFF)
                    : const Color(0x00000000);
                return CoilFocusRing(
                  visible: focused,
                  borderRadius: pillRadius,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: overlay,
                      shape: const RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(999),
                        ),
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.arrowUp,
                      size: 13,
                      color: colors.onBrandFill,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count new messages',
                      style: text.micro.copyWith(
                        color: colors.onBrandFill,
                        fontWeight: text.emphasis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ColoredBox(
            color: colors.onBrandFill.withValues(alpha: 0.25),
            child: const SizedBox(width: 1, height: 14),
          ),
          Semantics(
            button: true,
            label: 'Mark as read',
            child: CoilInteraction(
              key: const Key('slack.unread_dismiss'),
              onPressed: onDismiss,
              excludeFromSemantics: true,
              builder: (context, states, child) {
                final hovered = states.contains(WidgetState.hovered);
                final pressed = states.contains(WidgetState.pressed);
                final focused = states.contains(WidgetState.focused);
                final overlay = pressed
                    ? const Color(0x24000000)
                    : hovered
                    ? const Color(0x14FFFFFF)
                    : const Color(0x00000000);
                return CoilFocusRing(
                  visible: focused,
                  borderRadius: pillRadius,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: overlay,
                      shape: const RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(999),
                        ),
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                child: Icon(
                  LucideIcons.x,
                  size: 13,
                  color: colors.onBrandFill.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: ColoredBox(
              color: colors.red.withValues(alpha: 0.75),
              child: const SizedBox(height: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          const CoilBadge(
            color: CoilBadgeColor.red,
            shape: CoilBadgeShape.pill,
            size: CoilSize.compact,
            child: Text('New'),
          ),
        ],
      ),
    );
  }
}

class _SlackMessageRow extends StatelessWidget {
  const _SlackMessageRow({
    required this.message,
    required this.markdownStyle,
    required this.highlighted,
    required this.showUnreadDivider,
    required this.threadExpanded,
    required this.onToggleReaction,
    required this.onToggleThread,
  });

  final _SlackMessage message;
  final CoilMarkdownStyle markdownStyle;
  final bool highlighted;
  final bool showUnreadDivider;
  final bool threadExpanded;
  final ValueChanged<_ReactionKind> onToggleReaction;
  final VoidCallback onToggleThread;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final motion = CoilTheme.motionOf(context);

    final row = SingleMotionBuilder(
      value: highlighted ? 1.0 : 0.0,
      motion: highlighted ? motion.fade : motion.fadeExit,
      builder: (context, t, child) {
        final strength = t.clamp(0.0, 1.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: strength > 0.005
                ? colors.brandWash.withValues(
                    alpha: colors.brandWash.a * strength,
                  )
                : null,
            border: Border(
              left: BorderSide(
                width: 3,
                color: strength > 0.005
                    ? colors.brandMark.withValues(alpha: strength)
                    : const Color(0x00000000),
              ),
            ),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AuthorAvatar(author: message.author),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        message.author.name,
                        style: text.body.copyWith(fontWeight: text.emphasis),
                      ),
                      if (message.author.roleBadge != null)
                        CoilBadge(
                          color: message.author.badgeColor,
                          size: CoilSize.compact,
                          child: Text(message.author.roleBadge!),
                        ),
                      if (message.bookmarkTag != null)
                        CoilBadge(
                          variant: CoilBadgeVariant.dot,
                          color: CoilBadgeColor.brand,
                          shape: CoilBadgeShape.pill,
                          size: CoilSize.compact,
                          child: Text(message.bookmarkTag!),
                        ),
                      Text(message.timestamp, style: text.muted.micro),
                    ],
                  ),
                  const SizedBox(height: 4),
                  CoilMarkdown(message.markdown, style: markdownStyle),
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final reaction in message.reactions)
                          _ReactionChip(
                            reaction: reaction,
                            onPressed: () => onToggleReaction(reaction.kind),
                          ),
                      ],
                    ),
                  ],
                  if (message.threadReplies.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ThreadSummaryPill(
                      replies: message.threadReplies,
                      lastReplyLabel: message.lastReplyLabel ?? 'just now',
                      expanded: threadExpanded,
                      onPressed: onToggleThread,
                    ),
                    if (threadExpanded) ...[
                      const SizedBox(height: 8),
                      _InlineThreadList(replies: message.threadReplies),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!showUnreadDivider) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const _UnreadDivider(), row],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.author, this.size = 36});

  final _SlackAuthor author;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = CoilTheme.of(context).colors.brightness == Brightness.dark;
    final text = CoilTheme.textOf(context);
    final background = isDark ? author.darkFill : author.lightFill;
    final foreground = isDark ? author.darkInk : author.lightInk;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            author.initials,
            style: (size >= 30 ? text.caption : text.micro).copyWith(
              color: foreground,
              fontWeight: text.emphasis,
              fontSize: size >= 30 ? 12 : 9,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.reaction, required this.onPressed});

  final _SlackReaction reaction;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final radius = BorderRadius.circular(999);

    return Semantics(
      button: true,
      selected: reaction.reactedByMe,
      label: '${reaction.kind.label} reaction, ${reaction.count}',
      child: CoilInteraction(
        onPressed: onPressed,
        excludeFromSemantics: true,
        builder: (context, states, child) {
          final hovered = states.contains(WidgetState.hovered);
          final focused = states.contains(WidgetState.focused);
          final fill = reaction.reactedByMe
              ? colors.brandWash
              : hovered
              ? colors.hover
              : colors.muted;
          final borderColor = reaction.reactedByMe
              ? colors.brandMark.withValues(alpha: 0.48)
              : colors.border;
          return CoilFocusRing(
            visible: focused,
            borderRadius: radius,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(color: borderColor),
                ),
              ),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                reaction.kind.icon,
                size: 13,
                color: reaction.reactedByMe
                    ? colors.brandInk
                    : colors.mutedForeground,
              ),
              const SizedBox(width: 4),
              Text(
                '${reaction.count}',
                style: text.micro.copyWith(
                  color: reaction.reactedByMe
                      ? colors.brandInk
                      : colors.mutedForeground,
                  fontWeight: text.emphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadSummaryPill extends StatelessWidget {
  const _ThreadSummaryPill({
    required this.replies,
    required this.lastReplyLabel,
    required this.expanded,
    required this.onPressed,
  });

  final List<_ThreadReply> replies;
  final String lastReplyLabel;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final radius = BorderRadius.circular(8);
    final uniqueAuthors = <_SlackAuthor>[];
    for (final reply in replies) {
      if (!uniqueAuthors.contains(reply.author)) {
        uniqueAuthors.add(reply.author);
      }
      if (uniqueAuthors.length == 3) break;
    }

    return Semantics(
      button: true,
      label: '${replies.length} thread replies',
      child: CoilInteraction(
        onPressed: onPressed,
        excludeFromSemantics: true,
        builder: (context, states, child) {
          final hovered = states.contains(WidgetState.hovered);
          final focused = states.contains(WidgetState.focused);
          return CoilFocusRing(
            visible: focused,
            borderRadius: radius,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: hovered || expanded ? colors.surfaces[1] : null,
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(
                    color: hovered || expanded
                        ? colors.border
                        : const Color(0x00000000),
                  ),
                ),
              ),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < uniqueAuthors.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                _AuthorAvatar(author: uniqueAuthors[i], size: 18),
              ],
              const SizedBox(width: 8),
              Icon(
                LucideIcons.messageSquare,
                size: 12,
                color: colors.brandInk,
              ),
              const SizedBox(width: 4),
              Text(
                '${replies.length} '
                '${replies.length == 1 ? 'reply' : 'replies'}',
                style: text.micro.copyWith(
                  color: colors.brandInk,
                  fontWeight: text.emphasis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Last reply $lastReplyLabel',
                  style: text.muted.micro,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                size: 13,
                color: colors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineThreadList extends StatelessWidget {
  const _InlineThreadList({required this.replies});

  final List<_ThreadReply> replies;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colors.brandMark.withValues(alpha: 0.45),
            width: 2,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < replies.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AuthorAvatar(author: replies[i].author, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              replies[i].author.name,
                              style: text.caption.copyWith(
                                fontWeight: text.emphasis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(replies[i].timestamp, style: text.muted.micro),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(replies[i].body, style: text.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlackMessage {
  _SlackMessage({
    required this.id,
    required this.day,
    required this.author,
    required this.timestamp,
    required this.markdown,
    List<_SlackReaction>? reactions,
    this.threadReplies = const [],
    this.lastReplyLabel,
    this.bookmarkTag,
  }) : reactions = reactions ?? [];

  final String id;
  final DateTime day;
  final _SlackAuthor author;
  final String timestamp;
  final String markdown;
  final List<_SlackReaction> reactions;
  final List<_ThreadReply> threadReplies;
  final String? lastReplyLabel;
  final String? bookmarkTag;
}

enum _ReactionKind {
  rocket(LucideIcons.rocket, 'Ship it'),
  flame(LucideIcons.flame, 'Fire'),
  thumbsUp(LucideIcons.thumbsUp, 'Thumbs up'),
  heart(LucideIcons.heart, 'Love'),
  sparkles(LucideIcons.sparkles, 'Sparkles'),
  check(LucideIcons.circleCheck, 'Verified'),
  eye(LucideIcons.eye, 'Watching'),
  zap(LucideIcons.zap, 'Fast'),
  party(LucideIcons.partyPopper, 'Celebrate'),
  layers(LucideIcons.layers, 'Architecture'),
  pin(LucideIcons.pin, 'Pinned'),
  target(LucideIcons.target, 'On target'),
  clipboard(LucideIcons.clipboardCheck, 'Checklist'),
  palette(LucideIcons.palette, 'Design'),
  keyboard(LucideIcons.keyboard, 'Shortcuts');

  const _ReactionKind(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _SlackReaction {
  const _SlackReaction({
    required this.kind,
    required this.count,
    this.reactedByMe = false,
  });

  final _ReactionKind kind;
  final int count;
  final bool reactedByMe;
}

class _ThreadReply {
  const _ThreadReply({
    required this.author,
    required this.timestamp,
    required this.body,
  });

  final _SlackAuthor author;
  final String timestamp;
  final String body;
}

enum _SlackAuthor {
  maya(
    name: 'Maya Rivera',
    initials: 'MR',
    roleBadge: 'Maintainer',
    badgeColor: CoilBadgeColor.purple,
    lightFill: Color(0xFFEDE9FE),
    lightInk: Color(0xFF5B21B6),
    darkFill: Color(0xFF3B2469),
    darkInk: Color(0xFFDDD6FE),
  ),
  amir(
    name: 'Amir Khoury',
    initials: 'AK',
    lightFill: Color(0xFFDCFCE7),
    lightInk: Color(0xFF166534),
    darkFill: Color(0xFF144329),
    darkInk: Color(0xFFBBF7D0),
  ),
  devon(
    name: 'Devon Lin',
    initials: 'DL',
    lightFill: Color(0xFFDBEAFE),
    lightInk: Color(0xFF1E40AF),
    darkFill: Color(0xFF1E355E),
    darkInk: Color(0xFFBFDBFE),
  ),
  sara(
    name: 'Sara Patel',
    initials: 'SP',
    roleBadge: 'Design',
    badgeColor: CoilBadgeColor.pink,
    lightFill: Color(0xFFFCE7F3),
    lightInk: Color(0xFF9D174D),
    darkFill: Color(0xFF551C39),
    darkInk: Color(0xFFFBCFE8),
  ),
  releaseBot(
    name: 'Release Bot',
    initials: 'CI',
    roleBadge: 'APP',
    badgeColor: CoilBadgeColor.amber,
    lightFill: Color(0xFFFEF3C7),
    lightInk: Color(0xFF92400E),
    darkFill: Color(0xFF4C3311),
    darkInk: Color(0xFFFDE68A),
  ),
  you(
    name: 'You',
    initials: 'YO',
    lightFill: Color(0xFFE0E7FF),
    lightInk: Color(0xFF3730A3),
    darkFill: Color(0xFF2B2D66),
    darkInk: Color(0xFFC7D2FE),
  );

  const _SlackAuthor({
    required this.name,
    required this.initials,
    required this.lightFill,
    required this.lightInk,
    required this.darkFill,
    required this.darkInk,
    this.roleBadge,
    this.badgeColor = CoilBadgeColor.gray,
  });

  final String name;
  final String initials;
  final String? roleBadge;
  final CoilBadgeColor badgeColor;
  final Color lightFill;
  final Color lightInk;
  final Color darkFill;
  final Color darkInk;
}

const _historyAuthors = <_SlackAuthor>[
  _SlackAuthor.maya,
  _SlackAuthor.amir,
  _SlackAuthor.devon,
  _SlackAuthor.sara,
  _SlackAuthor.releaseBot,
  _SlackAuthor.you,
];

const _historyTopics = <String>[
  'Benchmarked `Viewport(center:)` open at `#3,000` — sub-millisecond layout.',
  'Verified `0.0px`-shift prepend pagination inserting 40 older messages.',
  'Checked sticky push-up across the seam: inline vs `isPinned: true`.',
  'Confirmed `MarkdownSession` freezes settled blocks by identity.',
  'Tested trackpad fling mid-spring: `onUserScroll()` cancels immediately.',
  'Reviewed `TurnScrollNotification.leadingExtent` threshold (`160px`).',
  'Ran `dart analyze --fatal-infos` across `turns` and `coil` — 0 issues.',
  'Confirmed `stickyHeaderIgnoresPointer` lets drags pass through date pills.',
  'Keyboard inset anchoring locked the bottom item with zero 1-frame flash.',
  'Verified `Visibility.maintain` prevents double-rendered date pills.',
  'Audit: zero bare `AnimationController` — all transitions run on Motor.',
  'Spot-checked light and dark aubergine theme contrast across badges.',
];

const _historyReactions = <_ReactionKind>[
  _ReactionKind.thumbsUp,
  _ReactionKind.check,
  _ReactionKind.sparkles,
  _ReactionKind.zap,
  _ReactionKind.rocket,
  _ReactionKind.eye,
];

List<_SlackMessage> _generateHistoryRange({
  required String idPrefix,
  required int startNumber,
  required int count,
  required DateTime startDay,
  required int daySpan,
  int? kickoffNumber,
}) {
  return List<_SlackMessage>.generate(count, (i) {
    final number = startNumber + i;
    final dayOffset = (i * daySpan) ~/ count;
    final day = DateTime(
      startDay.year,
      startDay.month,
      startDay.day + dayOffset,
    );

    if (kickoffNumber != null && number == kickoffNumber) {
      return _SlackMessage(
        id: _SlackDemoState._kickoffMessageId,
        day: DateTime(2026, 2),
        author: _SlackAuthor.maya,
        timestamp: '10:00 AM',
        bookmarkTag: 'Kickoff · #420',
        markdown:
            '**Architecture Kickoff (#420 of 3,000)**\n\n'
            'We just jumped straight across 2,500+ messages in O(1) via '
            '`TurnScrollView.sectioned`! Only the visible window around this '
            'message was built, and the sticky `Sunday, Feb 1` header synced '
            'immediately.',
        reactions: [
          const _SlackReaction(
            kind: _ReactionKind.rocket,
            count: 9,
            reactedByMe: true,
          ),
          const _SlackReaction(kind: _ReactionKind.zap, count: 6),
        ],
      );
    }

    final author =
        _historyAuthors[(number * 5 + dayOffset) % _historyAuthors.length];
    final slot = i % 24;
    final hour24 = 8 + (slot * 11) ~/ 24;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final minute = ((number * 17 + slot * 11) % 60).toString().padLeft(2, '0');
    final topic =
        _historyTopics[(number * 3 + dayOffset) % _historyTopics.length];
    final hasReaction = number % 7 == 0;

    return _SlackMessage(
      id: '$idPrefix${number.toString().padLeft(4, '0')}',
      day: day,
      author: author,
      timestamp: '$hour12:$minute $period',
      markdown: topic,
      reactions: hasReaction
          ? [
              _SlackReaction(
                kind: _historyReactions[number % _historyReactions.length],
                count: 2 + (number % 5),
              ),
            ]
          : null,
    );
  });
}

List<List<_SlackMessage>> _buildArchivePages() {
  final jan11 = DateTime(2026, 1, 11);
  final jan12 = DateTime(2026, 1, 12);

  return [
    // Page 1 (closest older: Jan 4 – Jan 12, 2026; 40 messages)
    [
      ..._generateHistoryRange(
        idPrefix: 'msg-p1-',
        startNumber: 1,
        count: 33,
        startDay: DateTime(2026, 1, 4),
        daySpan: 7,
      ),
      _SlackMessage(
        id: 'msg-arch-11-1',
        day: jan11,
        author: _SlackAuthor.devon,
        timestamp: '10:02 AM',
        markdown:
            'Opened the tracking issue for **bidirectional chat timelines** — '
            'teams want Slack-scale channels with sticky date pills AND '
            '`0.0px`-shift prepend pagination.',
        reactions: [const _SlackReaction(kind: _ReactionKind.eye, count: 4)],
      ),
      _SlackMessage(
        id: 'msg-arch-11-2',
        day: jan11,
        author: _SlackAuthor.maya,
        timestamp: '1:30 PM',
        markdown:
            'Agreed. Let’s split the scroll API into two focused widgets:\n'
            '- `TurnScrollView` / `TurnScrollView.sectioned` for bidirectional '
            '`Viewport(center:)` feeds\n'
            '- `CustomTurnScrollView` + `SliverTurnList` for bounded feeds '
            'needing arbitrary Flutter slivers',
        reactions: [
          const _SlackReaction(
            kind: _ReactionKind.sparkles,
            count: 6,
            reactedByMe: true,
          ),
        ],
      ),
      _SlackMessage(
        id: 'msg-arch-11-3',
        day: jan11,
        author: _SlackAuthor.sara,
        timestamp: '3:15 PM',
        markdown:
            'Love how clear that mental model is — default to '
            '`TurnScrollView.sectioned` for chat timelines, reach for '
            '`CustomTurnScrollView` only for mixed sliver layouts.',
      ),
      _SlackMessage(
        id: 'msg-arch-12-1',
        day: jan12,
        author: _SlackAuthor.maya,
        timestamp: '9:18 AM',
        markdown:
            'Kicked off the `packages/turns` extraction branch! Keeping zero '
            'dependency on `coil` so any Flutter app can drop in '
            '`TurnScrollView` directly.',
        reactions: [
          const _SlackReaction(kind: _ReactionKind.party, count: 5),
          const _SlackReaction(kind: _ReactionKind.flame, count: 3),
        ],
      ),
      _SlackMessage(
        id: 'msg-arch-12-2',
        day: jan12,
        author: _SlackAuthor.amir,
        timestamp: '11:04 AM',
        markdown:
            'Quick benchmark note: reusing `RenderTurnItemExtentObserver` '
            'eliminates `GlobalKey` lookups during layout and keeps extent '
            'estimates within ~1% once a section has scrolled.',
        reactions: [const _SlackReaction(kind: _ReactionKind.zap, count: 4)],
      ),
      _SlackMessage(
        id: 'msg-arch-12-3',
        day: jan12,
        author: _SlackAuthor.sara,
        timestamp: '2:45 PM',
        markdown:
            'Typography & spacing review for the Slack channel demo: keep '
            'inline date pills centered on a `1px` rule and float a shadowed '
            'pill with no rule whenever `isPinned == true`.',
        reactions: [
          const _SlackReaction(kind: _ReactionKind.sparkles, count: 2),
        ],
      ),
      _SlackMessage(
        id: 'msg-arch-12-4',
        day: jan12,
        author: _SlackAuthor.devon,
        timestamp: '4:52 PM',
        markdown:
            'Verified `MarkdownSession` preserves stable block IDs across '
            'rebuilds — zero re-parsing of settled paragraphs or code fences.',
        reactions: [const _SlackReaction(kind: _ReactionKind.check, count: 3)],
      ),
    ],
    // Page 2 (Dec 23 – Jan 3; 40 messages)
    _generateHistoryRange(
      idPrefix: 'msg-p2-',
      startNumber: 41,
      count: 40,
      startDay: DateTime(2025, 12, 23),
      daySpan: 12,
    ),
    // Page 3 (Dec 10 – Dec 22, 2025; 40 messages)
    _generateHistoryRange(
      idPrefix: 'msg-p3-',
      startNumber: 81,
      count: 40,
      startDay: DateTime(2025, 12, 10),
      daySpan: 13,
    ),
  ];
}

List<_SlackMessage> _buildInitialMessages() {
  final may13 = DateTime(2026, 5, 13);
  final may14 = DateTime(2026, 5, 14);
  final today = _SlackDemoState._today;

  // 2,981 historical messages (Jan 13 – May 12, 2026) + 19 recent = 3,000.
  final earlier = _generateHistoryRange(
    idPrefix: 'msg-h',
    startNumber: 1,
    count: 2981,
    startDay: DateTime(2026, 1, 13),
    daySpan: 120,
    kickoffNumber: 420,
  );

  return [
    ...earlier,
    // --- Wednesday, May 13 (7 messages, including RFC #42) ---
    _SlackMessage(
      id: 'msg-13-1',
      day: may13,
      author: _SlackAuthor.amir,
      timestamp: '9:05 AM',
      markdown:
          'Morning team! Ready to walk through the `TurnSectionHeaderBuilder` '
          '`isPinned` API before we freeze `0.1.0`.',
    ),
    _SlackMessage(
      id: _SlackDemoState._rfcMessageId,
      day: may13,
      author: _SlackAuthor.maya,
      timestamp: '9:24 AM',
      bookmarkTag: 'RFC #42',
      markdown:
          '**RFC #42: `TurnScrollView.sectioned` with `isPinned` headers**\n\n'
          'Passing `bool isPinned` into `TurnSectionHeaderBuilder<S>` lets '
          'Slack-scale 3,000+ message channels stay on the O(1) bidirectional '
          '`Viewport(center:)` without forward-only slivers:\n\n'
          '```dart\n'
          'TurnScrollView<DateTime>.sectioned(\n'
          '  controller: controller,\n'
          '  itemCount: messages.length,\n'
          '  itemId: (i) => messages[i].id,\n'
          '  sectionId: (i) => messages[i].day,\n'
          '  sectionHeaderBuilder: (context, day, isPinned) =>\n'
          '      DayHeader(day: day, isPinned: isPinned),\n'
          '  itemBuilder: buildRow,\n'
          ')\n'
          '```\n\n'
          '- `isPinned: false` renders the `1px` hairline rule + date pill\n'
          '- `isPinned: true` floats only the transparent elevated pill on top',
      reactions: [
        const _SlackReaction(
          kind: _ReactionKind.rocket,
          count: 7,
          reactedByMe: true,
        ),
        const _SlackReaction(kind: _ReactionKind.sparkles, count: 4),
        const _SlackReaction(kind: _ReactionKind.check, count: 3),
      ],
      lastReplyLabel: 'yesterday',
      threadReplies: const [
        _ThreadReply(
          author: _SlackAuthor.devon,
          timestamp: '9:41 AM',
          body:
              'Tested with 3,000 messages and sticky push-up across the center '
              'seam — lands within 1px every time.',
        ),
        _ThreadReply(
          author: _SlackAuthor.sara,
          timestamp: '10:02 AM',
          body:
              'Love that alignment: 0.08 gives just enough breathing room '
              'below the pinned date pill.',
        ),
      ],
    ),
    _SlackMessage(
      id: 'msg-13-3',
      day: may13,
      author: _SlackAuthor.devon,
      timestamp: '10:48 AM',
      markdown:
          'Double-checked `TargetTrackingScrollActivity`: any mouse wheel, '
          'trackpad fling, or touch drag cancels the spring immediately via '
          '`onUserScroll()` with zero fighting.',
      reactions: [
        const _SlackReaction(kind: _ReactionKind.thumbsUp, count: 3),
      ],
    ),
    _SlackMessage(
      id: 'msg-13-4',
      day: may13,
      author: _SlackAuthor.sara,
      timestamp: '11:32 AM',
      markdown:
          'For the highlight pulse when landing from a bookmark jump, let’s '
          'drive it with `SingleMotionBuilder` and `CoilTheme.motionOf` so '
          '`TickerRateScope` and reduced-motion settings work automatically.',
      reactions: [const _SlackReaction(kind: _ReactionKind.heart, count: 4)],
    ),
    _SlackMessage(
      id: 'msg-13-5',
      day: may13,
      author: _SlackAuthor.amir,
      timestamp: '1:15 PM',
      markdown:
          'Caught a nice subtlety in `scrollToBottom()`: we verify the final '
          '`RenderBox` is attached and not `keptAlive` offscreen before '
          'freezing the spring target.',
    ),
    _SlackMessage(
      id: 'msg-13-6',
      day: may13,
      author: _SlackAuthor.releaseBot,
      timestamp: '3:00 PM',
      markdown:
          '**CI green** on `feat/turns` — all unit tests passing in '
          '`packages/turns` and `packages/coil`.',
      reactions: [const _SlackReaction(kind: _ReactionKind.check, count: 5)],
    ),
    _SlackMessage(
      id: 'msg-13-7',
      day: may13,
      author: _SlackAuthor.maya,
      timestamp: '4:42 PM',
      markdown:
          'Wrapping up for today. Tomorrow we’ll wire the release checklist '
          'and test cross-day jumps under both light and dark themes.',
    ),

    // --- Thursday, May 14 (7 messages: Deploy checklist + 5 unread) ---
    _SlackMessage(
      id: 'msg-14-1',
      day: may14,
      author: _SlackAuthor.sara,
      timestamp: '9:12 AM',
      markdown:
          'Aubergine seed (`0xFF7C3AED` with `neutralHue: 305`, '
          '`neutralChroma: 0.008`) looks super crisp in both light and dark '
          'modes via `CoilTheme.override`.',
      reactions: [
        const _SlackReaction(kind: _ReactionKind.palette, count: 4),
      ],
    ),
    _SlackMessage(
      id: _SlackDemoState._deployMessageId,
      day: may14,
      author: _SlackAuthor.devon,
      timestamp: '10:36 AM',
      bookmarkTag: 'Deploy checklist',
      markdown:
          '**Release 0.1.0-dev.0 Deploy Checklist**\n\n'
          'Before merging `feat/turns` into `main`, verify each gate:\n\n'
          '- [x] `dart analyze --fatal-infos` clean across workspace\n'
          '- [x] Zero Material/Cupertino imports in `turns` and `turns_example`\n'
          '- [x] Zero bare `AnimationController` or Flutter ticker mixins\n'
          '- [x] `CoilMarkdown` backed by `turns/markdown.dart` (`MarkdownSession`)\n'
          '- [ ] Web WASM build green in `apps/example`\n\n'
          'Run locally with:\n'
          '```sh\n'
          'cd apps/example && flutter build web --release --wasm\n'
          '```',
      reactions: [
        const _SlackReaction(
          kind: _ReactionKind.clipboard,
          count: 5,
          reactedByMe: true,
        ),
        const _SlackReaction(kind: _ReactionKind.rocket, count: 4),
      ],
      lastReplyLabel: '4h ago',
      threadReplies: const [
        _ThreadReply(
          author: _SlackAuthor.releaseBot,
          timestamp: '10:39 AM',
          body: 'Analyzer gate passed with 0 infos, 0 warnings.',
        ),
        _ThreadReply(
          author: _SlackAuthor.maya,
          timestamp: '10:44 AM',
          body: 'Only WASM verification left once all demos land.',
        ),
        _ThreadReply(
          author: _SlackAuthor.amir,
          timestamp: '11:01 AM',
          body:
              'Confirmed `CoilScrollArea` pairs cleanly with '
              'TurnScrollController.',
        ),
      ],
    ),
    _SlackMessage(
      id: _SlackDemoState._firstUnreadId,
      day: may14,
      author: _SlackAuthor.amir,
      timestamp: '11:50 AM',
      bookmarkTag: 'First unread',
      markdown:
          'Also verified `CoilInputMessage` handles `Enter` to send on '
          'desktop pointer and `Shift+Enter` for multiline markdown blocks, '
          'while keeping Return as newline on touch.',
      reactions: [
        const _SlackReaction(kind: _ReactionKind.keyboard, count: 2),
      ],
    ),
    _SlackMessage(
      id: 'msg-14-4',
      day: may14,
      author: _SlackAuthor.maya,
      timestamp: '1:28 PM',
      markdown:
          'Prepending earlier archive pages above the viewport keeps every '
          'visible message locked to `0.0px` shift because `TurnScrollView` '
          'anchors on `Viewport(center:)`.',
      reactions: [const _SlackReaction(kind: _ReactionKind.pin, count: 3)],
    ),
    _SlackMessage(
      id: 'msg-14-5',
      day: may14,
      author: _SlackAuthor.sara,
      timestamp: '3:04 PM',
      markdown:
          'Added tappable reaction counters and expandable inline threads so '
          'you can feel dynamic item height updates inside '
          '`TurnScrollView.sectioned`.',
    ),
    _SlackMessage(
      id: 'msg-14-6',
      day: may14,
      author: _SlackAuthor.devon,
      timestamp: '4:19 PM',
      markdown:
          'One more check: make sure `isAwayFromBottom` only surfaces the '
          'jump-to-latest pill once scrolled past `jumpThreshold` (`160px`).',
      reactions: [
        const _SlackReaction(kind: _ReactionKind.thumbsUp, count: 2),
      ],
    ),
    _SlackMessage(
      id: 'msg-14-7',
      day: may14,
      author: _SlackAuthor.releaseBot,
      timestamp: '5:30 PM',
      markdown:
          'Scheduled nightly WASM smoke check for `apps/example` at `02:00 UTC`.',
    ),

    // --- Today (5 messages -> 10 unread total from _firstUnreadId) ---
    _SlackMessage(
      id: 'msg-today-1',
      day: today,
      author: _SlackAuthor.maya,
      timestamp: '9:02 AM',
      markdown:
          'Good morning! Notice how the pinned `Today` date pill floats '
          'cleanly over scrolled messages without a hairline — tap '
          '**10 new messages** or any bookmark above to jump across 3,000 '
          'messages.',
      reactions: [
        const _SlackReaction(kind: _ReactionKind.sparkles, count: 4),
        const _SlackReaction(
          kind: _ReactionKind.flame,
          count: 2,
          reactedByMe: true,
        ),
      ],
    ),
    _SlackMessage(
      id: 'msg-today-2',
      day: today,
      author: _SlackAuthor.amir,
      timestamp: '9:18 AM',
      markdown:
          'Tested jumping from Today straight up to **RFC #42** on May 13 '
          'or all the way back to **Kickoff · #420** in February. Long '
          'jumps recenter next to the target and glide the last screen, so '
          'they cost the same as short ones.',
      reactions: [const _SlackReaction(kind: _ReactionKind.target, count: 3)],
    ),
    _SlackMessage(
      id: 'msg-today-3',
      day: today,
      author: _SlackAuthor.sara,
      timestamp: '9:45 AM',
      markdown:
          'Quick tip: tap the **code icon** in the composer below to drop a '
          'fenced Dart snippet, or type your own markdown (`**bold**`, '
          '`` `inline code` ``, lists) and press Enter.',
    ),
    _SlackMessage(
      id: 'msg-today-4',
      day: today,
      author: _SlackAuthor.devon,
      timestamp: '10:11 AM',
      markdown:
          'Here’s the stack powering this 3,000-message channel:\n'
          '1. Fixed bookmarks bar right below the channel header\n'
          '2. `TurnScrollView<DateTime>.sectioned` on O(1) '
          '`Viewport(center:)`\n'
          '3. `isPinned` date headers (hairline inline vs floating pill)\n'
          '4. `leadingSlivers` welcome banner + `0.0px`-shift top pagination\n'
          '5. Inline red `"New"` marker + floating `"10 new messages"` pill',
      reactions: [
        const _SlackReaction(kind: _ReactionKind.layers, count: 5),
        const _SlackReaction(kind: _ReactionKind.party, count: 3),
      ],
      lastReplyLabel: '14m ago',
      threadReplies: const [
        _ThreadReply(
          author: _SlackAuthor.maya,
          timestamp: '10:16 AM',
          body:
              'And every message body uses CoilMarkdown backed by turns’s '
              'incremental MarkdownSession.',
        ),
        _ThreadReply(
          author: _SlackAuthor.sara,
          timestamp: '10:22 AM',
          body: 'Looks awesome in both light and dark modes!',
        ),
      ],
    ),
    _SlackMessage(
      id: 'msg-today-5',
      day: today,
      author: _SlackAuthor.releaseBot,
      timestamp: '10:29 AM',
      markdown:
          '**Preview ready:** Tap **10 new messages** or any bookmark above, '
          'scroll up to watch `Today` push off `Thursday, May 14`, or post a '
          'new message below.',
      reactions: [const _SlackReaction(kind: _ReactionKind.rocket, count: 2)],
    ),
  ];
}
