import 'dart:async';

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

/// Slack-style channel demo showcasing [CustomTurnScrollView] composing native
/// Flutter slivers (`SliverPersistentHeader`, `SliverToBoxAdapter`,
/// `SliverMainAxisGroup`) with multiple [SliverTurnList] day sections,
/// cross-sliver offscreen [TurnScrollController.scrollTo], rich [CoilMarkdown]
/// messages, interactive reactions & threads, prepend pagination, and live
/// messaging.
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

  final _controller = TurnScrollController();
  final _composerController = TextEditingController();

  late final List<_DaySection> _days;
  late final List<_DaySection> _archiveQueue;
  final _expandedThreads = <String>{};

  bool _showUnreadPill = true;
  String? _highlightedId;
  Timer? _highlightTimer;
  int _nextMessageNumber = 1;

  @override
  void initState() {
    super.initState();
    _days = _buildInitialDays();
    _archiveQueue = _buildArchiveDays();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _composerController.dispose();
    _controller.dispose();
    super.dispose();
  }

  int get _totalMessageCount =>
      _days.fold(0, (sum, day) => sum + day.messages.length);

  int get _unreadCount {
    var counting = false;
    var count = 0;
    for (final day in _days) {
      for (final message in day.messages) {
        if (message.id == _firstUnreadId) counting = true;
        if (counting) count++;
      }
    }
    return count;
  }

  Future<bool> _jumpToMessage(String id, {double alignment = 0.08}) async {
    _highlightTimer?.cancel();
    if (!await _controller.scrollTo(id, alignment: alignment)) return false;
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

  void _dismissUnread() {
    if (!_showUnreadPill) return;
    setState(() => _showUnreadPill = false);
  }

  void _loadEarlierDays() {
    if (_archiveQueue.isEmpty) return;
    setState(() {
      final earlierDay = _archiveQueue.removeAt(0);
      _days.insert(0, earlierDay);
    });
  }

  void _toggleReaction(String messageId, _ReactionKind kind) {
    setState(() {
      for (final day in _days) {
        for (final message in day.messages) {
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
      _days.last.messages.add(newMessage);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.jumpToBottom());
    });
  }

  void _insertMarkdownSnippet() {
    const snippet =
        'Verified `SliverTurnList` landing offset below stacked headers:\n'
        '```dart\n'
        'await controller.scrollTo(\n'
        "  'msg-rfc-42',\n"
        '  alignment: 0.08,\n'
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
          final text = CoilTheme.textOf(context);
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

          final slivers = <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _BookmarksHeaderDelegate(
                colors: colors,
                text: text,
                onJumpRfc: () => unawaited(_jumpToMessage(_rfcMessageId)),
                onJumpDeploy: () => unawaited(_jumpToMessage(_deployMessageId)),
                onJumpUnread: () => unawaited(_jumpToUnread()),
              ),
            ),
            SliverToBoxAdapter(
              child: _ChannelWelcomeBanner(
                remainingArchiveDays: _archiveQueue.length,
                onLoadEarlier: _loadEarlierDays,
              ),
            ),
            for (final day in _days)
              SliverMainAxisGroup(
                key: ValueKey('day:${day.id}'),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _DayHeaderDelegate(
                      label: day.label,
                      colors: colors,
                      text: text,
                    ),
                  ),
                  SliverTurnList(
                    key: ValueKey('list:${day.id}'),
                    itemCount: day.messages.length,
                    itemId: (i) => day.messages[i].id,
                    itemSpacing: 2,
                    itemBuilder: (context, i) {
                      final message = day.messages[i];
                      return _SlackMessageRow(
                        message: message,
                        markdownStyle: markdownStyle,
                        highlighted: _highlightedId == message.id,
                        showUnreadDivider: message.id == _firstUnreadId,
                        threadExpanded: _expandedThreads.contains(message.id),
                        onToggleReaction: (kind) =>
                            _toggleReaction(message.id, kind),
                        onToggleThread: () => _toggleThread(message.id),
                      );
                    },
                  ),
                ],
              ),
          ];

          return ColoredBox(
            color: colors.background,
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _ChannelHeader(
                    dayCount: _days.length,
                    messageCount: _totalMessageCount,
                  ),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    child: Stack(
                      children: [
                        CoilScrollArea(
                          controller: _controller,
                          edgeFades: CoilEdgeFades.none,
                          semanticLabel: '#engineering-scroll channel messages',
                          child: CustomTurnScrollView(
                            controller: _controller,
                            applyTopPadding: false,
                            padding: const EdgeInsets.only(bottom: 16),
                            slivers: slivers,
                          ),
                        ),
                        Positioned(
                          top: 86,
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
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _controller.isAwayFromBottom,
                            builder: (context, away, _) {
                              return SingleMotionBuilder(
                                value: away ? 1.0 : 0.0,
                                motion: away
                                    ? motion.standard
                                    : motion.fadeExit,
                                builder: (context, t, child) {
                                  final clamped = t.clamp(0.0, 1.0);
                                  if (!away && clamped <= 0.01) {
                                    return const SizedBox.shrink();
                                  }
                                  return IgnorePointer(
                                    ignoring: !away,
                                    child: Opacity(
                                      opacity: clamped,
                                      child: Transform.translate(
                                        offset: Offset(0, (1 - t) * 14),
                                        child: child,
                                      ),
                                    ),
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
                                    onPressed: () =>
                                        unawaited(_controller.jumpToBottom()),
                                    child: const Text('Jump to latest'),
                                  ),
                                ),
                              );
                            },
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
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({required this.dayCount, required this.messageCount});

  final int dayCount;
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
                    'CustomTurnScrollView · SliverMainAxisGroup · '
                    'SliverTurnList',
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
              child: Text('$dayCount days · $messageCount'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarksHeaderDelegate extends SliverPersistentHeaderDelegate {
  _BookmarksHeaderDelegate({
    required this.colors,
    required this.text,
    required this.onJumpRfc,
    required this.onJumpDeploy,
    required this.onJumpUnread,
  });

  static const double _height = 44;

  final CoilColors colors;
  final CoilTextTheme text;
  final VoidCallback onJumpRfc;
  final VoidCallback onJumpDeploy;
  final VoidCallback onJumpUnread;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaces[1],
        border: Border(bottom: BorderSide(color: colors.border)),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: colors.shadowColor.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        height: _height,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                LucideIcons.bookmark,
                size: 13,
                color: colors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Text('Bookmarks', style: text.muted.micro),
              const SizedBox(width: 10),
              _BookmarkChip(
                key: const Key('slack.jump_rfc'),
                icon: LucideIcons.fileText,
                label: 'RFC #42 · May 13',
                onPressed: onJumpRfc,
              ),
              const SizedBox(width: 6),
              _BookmarkChip(
                key: const Key('slack.jump_deploy'),
                icon: LucideIcons.rocket,
                label: 'Deploy checklist · May 14',
                onPressed: onJumpDeploy,
              ),
              const SizedBox(width: 6),
              _BookmarkChip(
                key: const Key('slack.jump_unread'),
                icon: LucideIcons.sparkles,
                label: 'First unread · May 14',
                accent: true,
                onPressed: onJumpUnread,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_BookmarksHeaderDelegate oldDelegate) =>
      colors != oldDelegate.colors || text != oldDelegate.text;
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
    required this.remainingArchiveDays,
    required this.onLoadEarlier,
  });

  final int remainingArchiveDays;
  final VoidCallback onLoadEarlier;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final hasEarlier = remainingArchiveDays > 0;

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
                          'Turn-anchored sliver architecture & release notes',
                          style: text.muted.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Each day below is a native Flutter SliverMainAxisGroup with a '
                'pinned SliverPersistentHeader date pill and its own '
                'SliverTurnList — enabling spring-driven cross-sliver jumps '
                'across offscreen messages.',
                style: text.muted.caption,
              ),
              const SizedBox(height: 12),
              CoilButton(
                key: const Key('slack.load_earlier'),
                variant: hasEarlier
                    ? CoilButtonVariant.secondary
                    : CoilButtonVariant.tertiary,
                size: CoilSize.compact,
                leading: Icon(
                  hasEarlier ? LucideIcons.history : LucideIcons.check,
                  size: 14,
                ),
                onPressed: hasEarlier ? onLoadEarlier : null,
                child: Text(
                  hasEarlier
                      ? 'Load earlier days ($remainingArchiveDays more)'
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

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({
    required this.label,
    required this.colors,
    required this.text,
  });

  static const double _height = 38;

  final String label;
  final CoilColors colors;
  final CoilTextTheme text;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final pill = DecoratedBox(
      decoration: ShapeDecoration(
        color: overlapsContent ? colors.surfaces[2] : colors.surfaces[1],
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: colors.border),
        ),
        shadows: overlapsContent
            ? [
                BoxShadow(
                  color: colors.shadowColor.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
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

    return IgnorePointer(
      child: SizedBox(
        height: _height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: overlapsContent
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
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate oldDelegate) =>
      label != oldDelegate.label ||
      colors != oldDelegate.colors ||
      text != oldDelegate.text;
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
              Text('Last reply $lastReplyLabel', style: text.muted.micro),
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

class _DaySection {
  _DaySection({required this.id, required this.label, required this.messages});

  final String id;
  final String label;
  final List<_SlackMessage> messages;
}

class _SlackMessage {
  _SlackMessage({
    required this.id,
    required this.author,
    required this.timestamp,
    required this.markdown,
    List<_SlackReaction>? reactions,
    this.threadReplies = const [],
    this.lastReplyLabel,
    this.bookmarkTag,
  }) : reactions = reactions ?? [];

  final String id;
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

List<_DaySection> _buildArchiveDays() => [
  _DaySection(
    id: 'may-12',
    label: 'Tuesday, May 12',
    messages: [
      _SlackMessage(
        id: 'msg-arch-12-1',
        author: _SlackAuthor.maya,
        timestamp: '9:18 AM',
        markdown:
            'Kicked off the `packages/turns` extraction branch! Keeping zero '
            'dependency on `coil` so any Flutter app can drop in '
            '`TurnScrollView` or `CustomTurnScrollView` directly.',
        reactions: [
          const _SlackReaction(kind: _ReactionKind.party, count: 5),
          const _SlackReaction(kind: _ReactionKind.flame, count: 3),
        ],
      ),
      _SlackMessage(
        id: 'msg-arch-12-2',
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
        author: _SlackAuthor.sara,
        timestamp: '2:45 PM',
        markdown:
            'Typography & spacing review for the Slack channel demo: keep '
            'date pills centered on a `1px` rule and give pinned headers a '
            'subtle shadow only while `overlapsContent == true`.',
        reactions: [
          const _SlackReaction(kind: _ReactionKind.sparkles, count: 2),
        ],
      ),
      _SlackMessage(
        id: 'msg-arch-12-4',
        author: _SlackAuthor.devon,
        timestamp: '4:52 PM',
        markdown:
            'Verified `MarkdownSession` preserves stable block IDs across '
            'rebuilds — zero re-parsing of settled paragraphs or code fences.',
        reactions: [const _SlackReaction(kind: _ReactionKind.check, count: 3)],
      ),
    ],
  ),
  _DaySection(
    id: 'may-11',
    label: 'Monday, May 11',
    messages: [
      _SlackMessage(
        id: 'msg-arch-11-1',
        author: _SlackAuthor.devon,
        timestamp: '10:02 AM',
        markdown:
            'Opened the tracking issue for **sliver-native chat feeds** — '
            'teams want `SliverMainAxisGroup` + `SliverPersistentHeader` '
            'without losing offscreen `scrollTo(id)`.',
        reactions: [const _SlackReaction(kind: _ReactionKind.eye, count: 4)],
      ),
      _SlackMessage(
        id: 'msg-arch-11-2',
        author: _SlackAuthor.maya,
        timestamp: '1:30 PM',
        markdown:
            'Agreed. Let’s split the scroll API into two focused widgets:\n'
            '- `TurnScrollView` for bidirectional `Viewport(center:)` feeds\n'
            '- `CustomTurnScrollView` + `SliverTurnList` for arbitrary '
            'Flutter sliver trees',
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
        author: _SlackAuthor.sara,
        timestamp: '3:15 PM',
        markdown:
            'Love how clean that mental model is. Anyone coming from '
            '`CustomScrollView` immediately knows where `SliverTurnList` goes.',
      ),
    ],
  ),
];

List<_DaySection> _buildInitialDays() => [
  _DaySection(
    id: 'may-13',
    label: 'Wednesday, May 13',
    messages: [
      _SlackMessage(
        id: 'msg-13-1',
        author: _SlackAuthor.amir,
        timestamp: '9:05 AM',
        markdown:
            'Morning team! Ready to walk through the `CustomTurnScrollView` '
            'obstruction math before we freeze the API.',
      ),
      _SlackMessage(
        id: 'msg-rfc-42',
        author: _SlackAuthor.maya,
        timestamp: '9:24 AM',
        bookmarkTag: 'RFC #42',
        markdown:
            '**RFC #42: Multi-sliver offscreen `scrollTo(id)`**\n\n'
            'Every `SliverTurnList` registers a `TurnListRegistration` with '
            '`TurnScrollScope` so the engine can estimate offscreen offsets '
            'across arbitrary `SliverMainAxisGroup` sections and retarget '
            'seamlessly once the box lays out:\n\n'
            '```dart\n'
            'CustomTurnScrollView(\n'
            '  controller: controller,\n'
            '  slivers: [\n'
            '    SliverPersistentHeader(pinned: true, delegate: bookmarks),\n'
            '    SliverMainAxisGroup(\n'
            '      slivers: [\n'
            '        SliverPersistentHeader(\n'
            '          pinned: true,\n'
            '          delegate: dayHeader,\n'
            '        ),\n'
            '        SliverTurnList(\n'
            '          itemCount: messages.length,\n'
            '          itemId: (i) => messages[i].id,\n'
            '          itemBuilder: buildRow,\n'
            '        ),\n'
            '      ],\n'
            '    ),\n'
            '  ],\n'
            ')\n'
            '```\n\n'
            '- Walks ancestor `RenderSliver` siblings to sum '
            '`maxScrollObstructionExtent`\n'
            '- Keeps Motor spring velocity continuous when virtualized extents '
            'refine mid-flight',
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
                'Tested with stacked bookmarks + day header (82px combined '
                'obstruction) — lands within 1px every time.',
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
        author: _SlackAuthor.amir,
        timestamp: '1:15 PM',
        markdown:
            'Caught a nice subtlety in `jumpToBottom()`: we check '
            '`lastNonEmpty.reachedEnd` and verify the final `RenderBox` is '
            'attached and not `keptAlive` offscreen before freezing the '
            'target.',
      ),
      _SlackMessage(
        id: 'msg-13-6',
        author: _SlackAuthor.releaseBot,
        timestamp: '3:00 PM',
        markdown:
            '**CI green** on `feat/turns` — `18/18` tests passing in '
            '`packages/turns` and `2056/2056` in `packages/coil`.',
        reactions: [const _SlackReaction(kind: _ReactionKind.check, count: 5)],
      ),
      _SlackMessage(
        id: 'msg-13-7',
        author: _SlackAuthor.maya,
        timestamp: '4:42 PM',
        markdown:
            'Wrapping up for today. Tomorrow we’ll wire the release checklist '
            'and test cross-day jumps under both light and dark themes.',
      ),
    ],
  ),
  _DaySection(
    id: 'may-14',
    label: 'Thursday, May 14',
    messages: [
      _SlackMessage(
        id: 'msg-14-1',
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
        id: 'msg-deploy-checklist',
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
            body: 'Only WASM verification left once all four demos land.',
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
        id: 'msg-unread-first',
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
        author: _SlackAuthor.maya,
        timestamp: '1:28 PM',
        markdown:
            'Reminder: keep `SliverMainAxisGroup` keyed with '
            '`ValueKey(day.id)` and `SliverTurnList` keyed with '
            '`ValueKey(list:day.id)` so prepending earlier days preserves '
            'existing render objects.',
        reactions: [const _SlackReaction(kind: _ReactionKind.pin, count: 3)],
      ),
      _SlackMessage(
        id: 'msg-14-5',
        author: _SlackAuthor.sara,
        timestamp: '3:04 PM',
        markdown:
            'Added tappable reaction counters and expandable inline threads so '
            'you can feel dynamic item height updates inside `SliverTurnList`.',
      ),
      _SlackMessage(
        id: 'msg-14-6',
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
        author: _SlackAuthor.releaseBot,
        timestamp: '5:30 PM',
        markdown:
            'Scheduled nightly WASM smoke check for `apps/example` at `02:00 UTC`.',
      ),
    ],
  ),
  _DaySection(
    id: 'today',
    label: 'Today',
    messages: [
      _SlackMessage(
        id: 'msg-today-1',
        author: _SlackAuthor.maya,
        timestamp: '9:02 AM',
        markdown:
            'Good morning! Notice how the pinned `Today` date pill floats '
            'cleanly over scrolled messages without covering them — tap '
            '**10 new messages** or any bookmark above to spring across days.',
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
        author: _SlackAuthor.amir,
        timestamp: '9:18 AM',
        markdown:
            'Tested jumping from Today straight up to **RFC #42** on May 13 '
            'and back to **Deploy checklist** on May 14 — zero jump cut, '
            'smooth Motor spring all the way.',
        reactions: [const _SlackReaction(kind: _ReactionKind.target, count: 3)],
      ),
      _SlackMessage(
        id: 'msg-today-3',
        author: _SlackAuthor.sara,
        timestamp: '9:45 AM',
        markdown:
            'Quick tip: tap the **code icon** in the composer below to drop a '
            'fenced Dart snippet, or type your own markdown (`**bold**`, '
            '`` `inline code` ``, lists) and press Enter.',
      ),
      _SlackMessage(
        id: 'msg-today-4',
        author: _SlackAuthor.devon,
        timestamp: '10:11 AM',
        markdown:
            'Here’s the complete sliver stack powering this channel:\n'
            '1. Pinned `SliverPersistentHeader` (bookmarks bar)\n'
            '2. `SliverToBoxAdapter` (welcome banner + `"Load earlier days"`)\n'
            '3. Multiple `SliverMainAxisGroup` sections (floating pinned date '
            'pill + `SliverTurnList`)\n'
            '4. Inline red `"New"` marker + floating unread jump pill',
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
        author: _SlackAuthor.releaseBot,
        timestamp: '10:29 AM',
        markdown:
            '**Preview ready:** Scroll up to test `"Load earlier days"` and '
            'the floating `"Jump to latest"` pill, or post a new message '
            'below.',
        reactions: [const _SlackReaction(kind: _ReactionKind.rocket, count: 2)],
      ),
    ],
  ),
];
