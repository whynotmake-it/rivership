import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:motor/motor.dart';
import 'package:turns/turns.dart';

/// iMessage-style messaging demo exercising [TurnScrollView.sectioned] with
/// `stickySectionHeaders: false` (centered inline timestamp headers),
/// Coil blue palette override, `0.0px`-shift prepend pagination with preserved
/// tapback toggle state, offscreen inline-reply `scrollTo` with Motor
/// highlight, and a working [CoilInputMessage] composer with delayed replies.
class IMessageDemo extends StatefulWidget {
  /// Creates the iMessage demo.
  const IMessageDemo({super.key});

  @override
  State<IMessageDemo> createState() => _IMessageDemoState();
}

enum _TapbackKind { heart, thumbsUp, laugh, emphasis }

class _IMessage {
  const _IMessage({
    required this.id,
    required this.fromMe,
    required this.text,
    required this.section,
    required this.sentLabel,
    this.replyToId,
    this.replyToAuthor,
    this.replyToPreview,
    this.initialTapbacks = const {},
    this.statusLabel,
  });

  final String id;
  final bool fromMe;
  final String text;
  final DateTime section;
  final String sentLabel;
  final String? replyToId;
  final String? replyToAuthor;
  final String? replyToPreview;
  final Set<_TapbackKind> initialTapbacks;
  final String? statusLabel;
}

class _IMessageDemoState extends State<IMessageDemo> {
  static const _referencedMessageId = 'im-m-05';
  static const _maxOlderPages = 2;

  final _controller = TurnScrollController();
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  final _highlightNotifier = ValueNotifier<({String id, int nonce})?>(null);

  late List<_IMessage> _messages;
  int _olderPagesLoaded = 0;
  int _nextOutgoingNumber = 1;
  int _highlightNonce = 0;
  bool _loadingOlder = false;
  bool _peerTyping = false;
  double _composerHeight = 92;

  Timer? _highlightResetTimer;
  Timer? _olderLoadTimer;
  Timer? _replyTimer;

  bool get _hasMoreOlder => _olderPagesLoaded < _maxOlderPages;

  @override
  void initState() {
    super.initState();
    _messages = _buildInitialMessages();
  }

  @override
  void dispose() {
    _highlightResetTimer?.cancel();
    _olderLoadTimer?.cancel();
    _replyTimer?.cancel();
    _controller.dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    _highlightNotifier.dispose();
    super.dispose();
  }

  bool _handleTurnScroll(TurnScrollNotification notification) {
    if (!notification.isProgrammatic &&
        !_loadingOlder &&
        _hasMoreOlder &&
        notification.leadingExtent < 56 &&
        notification.metrics.maxScrollExtent -
                notification.metrics.minScrollExtent >=
            120) {
      _loadOlder(immediate: false);
    }
    return false;
  }

  void _loadOlder({required bool immediate}) {
    if (!_hasMoreOlder || _loadingOlder) return;
    if (immediate) {
      _prependNextPage();
      return;
    }
    setState(() => _loadingOlder = true);
    _olderLoadTimer?.cancel();
    _olderLoadTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _prependNextPage();
    });
  }

  void _prependNextPage() {
    if (!_hasMoreOlder) return;
    final page = _olderPagesLoaded + 1;
    final older = _buildOlderPage(page);
    setState(() {
      _messages = [...older, ..._messages];
      _olderPagesLoaded = page;
      _loadingOlder = false;
    });
  }

  Future<void> _jumpToReferencedMessage(String targetId) async {
    final arrived = await _controller.scrollTo(targetId, alignment: 0.35);
    if (!mounted || !arrived) return;
    final nonce = ++_highlightNonce;
    _highlightNotifier.value = (id: targetId, nonce: nonce);
    _highlightResetTimer?.cancel();
    _highlightResetTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      if (_highlightNotifier.value?.nonce == nonce) {
        _highlightNotifier.value = null;
      }
    });
  }

  void _handleSend(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final seq = _nextOutgoingNumber++;
    final section = DateTime(2026, 5, 14, 14, 15);
    final newMsg = _IMessage(
      id: 'im-live-out-$seq',
      fromMe: true,
      text: trimmed,
      section: section,
      sentLabel: 'Just now',
      statusLabel: 'Delivered',
    );
    setState(() {
      _messages = [..._messages, newMsg];
      _peerTyping = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.scrollToBottom());
    });

    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      final reply = _IMessage(
        id: 'im-live-in-$seq',
        fromMe: false,
        text: _pickPeerReply(trimmed, seq),
        section: section,
        sentLabel: 'Just now',
      );
      setState(() {
        _peerTyping = false;
        _messages = [..._messages, reply];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_controller.isAwayFromBottom.value) {
          unawaited(_controller.scrollToBottom());
        }
      });
    });
  }

  void _onComposerHeight(double height) {
    if ((_composerHeight - height).abs() <= 0.5) return;
    setState(() => _composerHeight = height);
  }

  @override
  Widget build(BuildContext context) {
    return CoilTheme.override(
      transform: (t) => t.copyWith(
        colors: CoilColors.fromSeed(
          brightness: t.brightness,
          brand: const Color(0xFF007AFF),
          neutralHue: 230,
          neutralChroma: 0.008,
        ),
      ),
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final remainingPages = _maxOlderPages - _olderPagesLoaded;
    final lastOutgoingIndex = _messages.lastIndexWhere((m) => m.fromMe);

    return ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          _IMessageHeader(
            remainingOlderPages: remainingPages,
            loadingOlder: _loadingOlder,
            onLoadOlder: _hasMoreOlder
                ? () => _loadOlder(immediate: true)
                : null,
            onJumpReferenced: () =>
                unawaited(_jumpToReferencedMessage(_referencedMessageId)),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = math.max<double>(
                  14,
                  (constraints.maxWidth - 680) / 2,
                );
                final contentWidth = math.max<double>(
                  240,
                  constraints.maxWidth - horizontal * 2,
                );
                final maxBubbleWidth = math.min<double>(
                  360,
                  contentWidth * 0.78,
                );
                final safeBottom = MediaQuery.paddingOf(context).bottom;
                final bottomPadding = math.max<double>(
                  12,
                  _composerHeight + 8 - safeBottom,
                );
                return Stack(
                  children: [
                    NotificationListener<TurnScrollNotification>(
                      onNotification: _handleTurnScroll,
                      child: CoilScrollArea(
                        controller: _controller,
                        edgeFades: CoilEdgeFades.none,
                        keyboard: false,
                        child: TurnScrollView<DateTime>.sectioned(
                          controller: _controller,
                          itemCount: _messages.length,
                          itemId: (i) => _messages[i].id,
                          sectionId: (i) => _messages[i].section,
                          stickySectionHeaders: false,
                          sectionHeaderSpacing: 8,
                          itemSpacing: 2,
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            8,
                            horizontal,
                            bottomPadding,
                          ),
                          leadingSlivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  0,
                                  horizontal,
                                  12,
                                ),
                                child: _OlderHistoryBanner(
                                  remainingPages: remainingPages,
                                  loading: _loadingOlder,
                                  onLoadOlder: _hasMoreOlder
                                      ? () => _loadOlder(immediate: true)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                          tailSliver: _peerTyping
                              ? const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: _TypingIndicatorBubble(),
                                  ),
                                )
                              : null,
                          sectionHeaderBuilder: (_, date, _) =>
                              _InlineTimestampHeader(section: date),
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isSectionFirst =
                                index == 0 ||
                                _messages[index - 1].section != message.section;
                            final prevSameSender =
                                !isSectionFirst &&
                                _messages[index - 1].fromMe == message.fromMe;
                            final nextSameSender =
                                index + 1 < _messages.length &&
                                _messages[index + 1].fromMe == message.fromMe &&
                                _messages[index + 1].section == message.section;
                            final isReplyJumpCard =
                                message.replyToId == _referencedMessageId;
                            return _IMessageBubbleItem(
                              key: ValueKey('bubble-${message.id}'),
                              message: message,
                              maxBubbleWidth: maxBubbleWidth,
                              isSectionFirst: isSectionFirst,
                              prevSameSender: prevSameSender,
                              nextSameSender: nextSameSender,
                              showDeliveryStatus: index == lastOutgoingIndex,
                              replyPreviewKey: isReplyJumpCard
                                  ? const Key('imessage.jump_ref')
                                  : null,
                              highlightNotifier: _highlightNotifier,
                              onTapReplyPreview: message.replyToId == null
                                  ? null
                                  : () => unawaited(
                                      _jumpToReferencedMessage(
                                        message.replyToId!,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _composerHeight + 12,
                      child: Center(
                        child: _IMessageJumpPill(
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
                      child: _IMessageHeightObserver(
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
                                    'iMessage',
                                    style: text.muted.field,
                                  ),
                                  onSend: _handleSend,
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
}

class _IMessageHeader extends StatelessWidget {
  const _IMessageHeader({
    required this.remainingOlderPages,
    required this.loadingOlder,
    required this.onLoadOlder,
    required this.onJumpReferenced,
  });

  final int remainingOlderPages;
  final bool loadingOlder;
  final VoidCallback? onLoadOlder;
  final VoidCallback onJumpReferenced;

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
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.brandFill,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 34,
                    child: Center(
                      child: Text(
                        'MK',
                        style: text.caption.copyWith(
                          color: colors.onBrandFill,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Maya Kapoor',
                        style: text.subtitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Inline timestamps · stickySectionHeaders: false',
                        style: text.muted.micro,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                CoilButton(
                  key: const Key('imessage.load_older'),
                  variant: CoilButtonVariant.secondary,
                  size: CoilSize.compact,
                  loading: loadingOlder,
                  leading: const Icon(LucideIcons.history, size: 14),
                  onPressed: onLoadOlder,
                  child: Text(
                    remainingOlderPages > 0
                        ? 'Load older ($remainingOlderPages)'
                        : 'All loaded',
                  ),
                ),
                CoilButton(
                  variant: CoilButtonVariant.tertiary,
                  size: CoilSize.compact,
                  leading: const Icon(LucideIcons.cornerUpLeft, size: 14),
                  onPressed: onJumpReferenced,
                  child: const Text('Find dinner pin'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OlderHistoryBanner extends StatelessWidget {
  const _OlderHistoryBanner({
    required this.remainingPages,
    required this.loading,
    required this.onLoadOlder,
  });

  final int remainingPages;
  final bool loading;
  final VoidCallback? onLoadOlder;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Center(
      child: loading
          ? Text('Loading earlier messages…', style: text.muted.caption)
          : remainingPages > 0
          ? CoilButton(
              variant: CoilButtonVariant.ghost,
              size: CoilSize.compact,
              onPressed: onLoadOlder,
              child: const Text('Scroll up or tap to load earlier messages'),
            )
          : Text('Start of conversation with Maya', style: text.muted.caption),
    );
  }
}

class _InlineTimestampHeader extends StatelessWidget {
  const _InlineTimestampHeader({required this.section});

  final DateTime section;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final (dayPart, timePart) = _formatTimestampParts(section);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$dayPart ',
                style: text.muted.micro.copyWith(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: timePart, style: text.muted.micro),
            ],
          ),
        ),
      ),
    );
  }
}

class _IMessageBubbleItem extends StatefulWidget {
  const _IMessageBubbleItem({
    required this.message,
    required this.maxBubbleWidth,
    required this.isSectionFirst,
    required this.prevSameSender,
    required this.nextSameSender,
    required this.showDeliveryStatus,
    required this.highlightNotifier,
    this.replyPreviewKey,
    this.onTapReplyPreview,
    super.key,
  });

  final _IMessage message;
  final double maxBubbleWidth;
  final bool isSectionFirst;
  final bool prevSameSender;
  final bool nextSameSender;
  final bool showDeliveryStatus;
  final ValueListenable<({String id, int nonce})?> highlightNotifier;
  final Key? replyPreviewKey;
  final VoidCallback? onTapReplyPreview;

  @override
  State<_IMessageBubbleItem> createState() => _IMessageBubbleItemState();
}

class _IMessageBubbleItemState extends State<_IMessageBubbleItem> {
  // Kept in widget State intentionally so 0.0px prepends prove State survival!
  late Set<_TapbackKind> _tapbacks;
  bool _userLoved = false;

  @override
  void initState() {
    super.initState();
    _tapbacks = {...widget.message.initialTapbacks};
  }

  void _toggleTapback(_TapbackKind kind) {
    setState(() {
      if (_tapbacks.contains(kind)) {
        _tapbacks.remove(kind);
        if (kind == _TapbackKind.heart) _userLoved = false;
      } else {
        _tapbacks.add(kind);
        if (kind == _TapbackKind.heart) _userLoved = true;
      }
    });
  }

  void _toggleQuickHeart() {
    setState(() {
      _userLoved = !_userLoved;
      if (_userLoved) {
        _tapbacks.add(_TapbackKind.heart);
      } else if (!widget.message.initialTapbacks.contains(_TapbackKind.heart)) {
        _tapbacks.remove(_TapbackKind.heart);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final motion = CoilTheme.motionOf(context);
    final msg = widget.message;

    final bubbleFill = msg.fromMe
        ? colors.brandFill
        : colors.brightness == Brightness.dark
        ? colors.surfaces[3]
        : colors.muted;
    final bubbleTextColor = msg.fromMe ? colors.onBrandFill : colors.foreground;

    const tight = Radius.circular(6);
    const round = Radius.circular(18);
    final borderRadius = msg.fromMe
        ? BorderRadius.only(
            topLeft: round,
            bottomLeft: round,
            topRight: widget.prevSameSender ? tight : round,
            bottomRight: widget.nextSameSender
                ? tight
                : const Radius.circular(6),
          )
        : BorderRadius.only(
            topRight: round,
            bottomRight: round,
            topLeft: widget.prevSameSender ? tight : round,
            bottomLeft: widget.nextSameSender
                ? tight
                : const Radius.circular(6),
          );

    return ValueListenableBuilder<({String id, int nonce})?>(
      valueListenable: widget.highlightNotifier,
      builder: (context, highlighted, child) {
        final isHighlighted = highlighted?.id == msg.id;
        return SingleMotionBuilder(
          value: isHighlighted ? 1 : 0,
          motion: isHighlighted ? motion.standard : motion.gentle,
          debugLabel: 'IMessageBubble.highlight.${msg.id}',
          child: child,
          builder: (context, glow, child) {
            final g = glow.clamp(0.0, 1.0);
            if (g <= 0.005) return child!;
            return DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.brandWash.withValues(
                  alpha: colors.brandWash.a * g,
                ),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: colors.brandMark.withValues(alpha: 0.75 * g),
                    width: 1.5,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: child,
              ),
            );
          },
        );
      },
      child: Padding(
        padding: EdgeInsets.only(
          top: widget.prevSameSender || widget.isSectionFirst ? 0 : 7,
        ),
        child: Align(
          alignment: msg.fromMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxBubbleWidth),
            child: Column(
              crossAxisAlignment: msg.fromMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.replyToPreview != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: _ReplyPreviewChip(
                      key: widget.replyPreviewKey,
                      author: msg.replyToAuthor ?? 'Maya',
                      preview: msg.replyToPreview!,
                      alignEnd: msg.fromMe,
                      onPressed: widget.onTapReplyPreview,
                    ),
                  ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: _tapbacks.isNotEmpty ? 8 : 0,
                      ),
                      child: Semantics(
                        button: true,
                        hint: 'Tap to toggle heart reaction',
                        child: CoilInteraction(
                          onPressed: _toggleQuickHeart,
                          builder: (context, states, child) {
                            final pressed = states.contains(
                              WidgetState.pressed,
                            );
                            final focused = states.contains(
                              WidgetState.focused,
                            );
                            return CoilFocusRing(
                              visible: focused,
                              borderRadius: borderRadius,
                              child: SingleMotionBuilder(
                                value: pressed ? 0.98 : 1,
                                motion: motion.quick,
                                debugLabel: 'IMessageBubble.press.${msg.id}',
                                child: child,
                                builder: (context, scale, child) =>
                                    Transform.scale(scale: scale, child: child),
                              ),
                            );
                          },
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: bubbleFill,
                              shape: RoundedSuperellipseBorder(
                                borderRadius: borderRadius,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 7.5,
                              ),
                              child: Text(
                                msg.text,
                                style: text.body.copyWith(
                                  fontSize: 15,
                                  height: 1.3,
                                  color: bubbleTextColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_tapbacks.isNotEmpty)
                      Positioned(
                        top: -1,
                        right: msg.fromMe ? null : -4,
                        left: msg.fromMe ? -4 : null,
                        child: _TapbackCluster(
                          tapbacks: _tapbacks,
                          userLoved: _userLoved,
                          onToggle: _toggleTapback,
                        ),
                      ),
                  ],
                ),
                if (widget.showDeliveryStatus && msg.statusLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 4),
                    child: Text(
                      msg.statusLabel!,
                      style: text.muted.micro.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyPreviewChip extends StatelessWidget {
  const _ReplyPreviewChip({
    required this.author,
    required this.preview,
    required this.alignEnd,
    required this.onPressed,
    super.key,
  });

  final String author;
  final String preview;
  final bool alignEnd;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final radius = BorderRadius.circular(14);
    return CoilInteraction(
      onPressed: onPressed,
      builder: (context, states, child) {
        final hovered = states.contains(WidgetState.hovered);
        final focused = states.contains(WidgetState.focused);
        return CoilFocusRing(
          visible: focused,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: hovered ? colors.surfaces[2] : colors.surfaces[1],
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: BorderSide(
                  color: hovered ? colors.brandMark : colors.border,
                ),
              ),
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cornerUpLeft, size: 13, color: colors.brandInk),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: alignEnd
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Replying to $author',
                    style: text.micro.copyWith(
                      color: colors.brandInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    preview,
                    style: text.muted.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TapbackCluster extends StatelessWidget {
  const _TapbackCluster({
    required this.tapbacks,
    required this.userLoved,
    required this.onToggle,
  });

  final Set<_TapbackKind> tapbacks;
  final bool userLoved;
  final ValueChanged<_TapbackKind> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        for (final kind in tapbacks)
          CoilInteraction(
            onPressed: () => onToggle(kind),
            builder: (context, states, child) {
              final focused = states.contains(WidgetState.focused);
              final radius = BorderRadius.circular(12);
              final active = kind == _TapbackKind.heart && userLoved;
              return CoilFocusRing(
                visible: focused,
                borderRadius: radius,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: active ? colors.brandFill : colors.surfaces[2],
                    shape: RoundedSuperellipseBorder(
                      borderRadius: radius,
                      side: BorderSide(
                        color: active ? colors.brandFill : colors.border,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: _tapbackGlyph(
                      kind,
                      color: active ? colors.onBrandFill : colors.foreground,
                      textStyle: text.micro.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active ? colors.onBrandFill : colors.foreground,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _tapbackGlyph(
    _TapbackKind kind, {
    required Color color,
    required TextStyle textStyle,
  }) => switch (kind) {
    _TapbackKind.heart => Icon(LucideIcons.heart, size: 11, color: color),
    _TapbackKind.thumbsUp => Icon(LucideIcons.thumbsUp, size: 11, color: color),
    _TapbackKind.laugh => Text('HA', style: textStyle),
    _TapbackKind.emphasis => Text('!!', style: textStyle),
  };
}

final _typingTrack = Track<double>(
  .single,
  initial: 0,
  debugLabel: 'IMessageDemo.typing',
);

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fill = colors.brightness == Brightness.dark
        ? colors.surfaces[3]
        : colors.muted;

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: 'Maya is typing',
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: reduced
                ? Text('Maya is typing…', style: text.muted.caption)
                : TrackBuilder(
                    debugLabel: 'IMessageDemo.typingDots',
                    animations: [
                      _typingTrack(const [
                        .loop([
                          .to(
                            1,
                            motion: CurvedMotion(Duration(milliseconds: 900)),
                          ),
                          .to(0, motion: .instant()),
                        ]),
                      ], from: 0),
                    ],
                    builder: (context, value, _) {
                      final phase = value(_typingTrack);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 5,
                        children: [
                          for (var i = 0; i < 3; i++)
                            _TypingDot(
                              color: colors.mutedForeground,
                              strength: _dotStrength(phase, i),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  double _dotStrength(double phase, int index) {
    final shifted = (phase - index * 0.22) % 1.0;
    return 0.35 + 0.65 * math.sin(shifted * math.pi).clamp(0.0, 1.0);
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot({required this.color, required this.strength});

  final Color color;
  final double strength;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: color.withValues(alpha: strength),
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(4)),
    ),
    child: const SizedBox.square(dimension: 7),
  );
}

class _IMessageJumpPill extends StatelessWidget {
  const _IMessageJumpPill({
    required this.awayFromBottom,
    required this.autoScrolling,
    required this.onPressed,
  });

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
          debugLabel: 'IMessageDemo.jumpBottom',
          child: child,
          builder: (context, progress, child) => IgnorePointer(
            ignoring: !visible,
            child: Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - progress) * 14),
                child: child,
              ),
            ),
          ),
        );
      },
      child: CoilButton(
        key: const Key('imessage.jump_bottom'),
        variant: CoilButtonVariant.brand,
        size: CoilSize.compact,
        leading: const Icon(LucideIcons.arrowDown, size: 14),
        onPressed: onPressed,
        child: const Text('Back to latest'),
      ),
    );
  }
}

class _IMessageHeightObserver extends SingleChildRenderObjectWidget {
  const _IMessageHeightObserver({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderIMessageHeightObserver(onHeight: onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderIMessageHeightObserver renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderIMessageHeightObserver extends RenderProxyBox {
  _RenderIMessageHeightObserver({required this.onHeight});

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

(String, String) _formatTimestampParts(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final time = '$hour12:$minute $period';

  if (dt.year == 2026 && dt.month == 5 && dt.day == 14) {
    return ('Today', time);
  }
  if (dt.year == 2026 && dt.month == 5 && dt.day == 13) {
    return ('Yesterday', time);
  }
  if (dt.year == 2026 && dt.month == 5 && dt.day == 12) {
    return ('Tuesday', time);
  }
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
  return ('${months[dt.month - 1]} ${dt.day},', time);
}

String _pickPeerReply(String sent, int seq) {
  final lower = sent.toLowerCase();
  if (lower.contains('time') || lower.contains('when')) {
    return 'Still aiming for 7:30! I can grab the corner table if I get there '
        'first.';
  }
  if (lower.contains('where') || lower.contains('address')) {
    return 'Nopa on Divisadero — tap my reply preview above if you need the '
        'cross street again.';
  }
  const replies = [
    'Sounds good! See you there in a bit.',
    'Perfect — bringing the extra film roll too.',
    'Haha deal. Text me when you head out!',
  ];
  return replies[(seq - 1) % replies.length];
}

List<_IMessage> _buildInitialMessages() {
  final tueEvening = DateTime(2026, 5, 12, 19, 18);
  final yestMorning = DateTime(2026, 5, 13, 9, 41);
  final yestEvening = DateTime(2026, 5, 13, 18, 5);
  final todayAfternoon = DateTime(2026, 5, 14, 14, 15);

  return [
    _IMessage(
      id: 'im-m-01',
      fromMe: false,
      section: tueEvening,
      sentLabel: '7:18 PM',
      text: 'Wait did you finish packing for the weekend trip already?',
    ),
    _IMessage(
      id: 'im-m-02',
      fromMe: true,
      section: tueEvening,
      sentLabel: '7:19 PM',
      text: 'Bold of you to assume I started before Thursday night.',
      initialTapbacks: const {_TapbackKind.laugh},
    ),
    _IMessage(
      id: 'im-m-03',
      fromMe: false,
      section: tueEvening,
      sentLabel: '7:20 PM',
      text:
          'Classic. At least we locked down Friday dinner before it fills up.',
    ),
    _IMessage(
      id: 'im-m-04',
      fromMe: true,
      section: tueEvening,
      sentLabel: '7:21 PM',
      text: 'Wait remind me which spot we picked again?',
    ),
    _IMessage(
      id: 'im-m-05',
      fromMe: false,
      section: tueEvening,
      sentLabel: '7:22 PM',
      text:
          'Nopa — 560 Divisadero St at Hayes. Table for 4 under Maya at '
          '7:30 PM!',
      initialTapbacks: const {_TapbackKind.heart},
    ),
    _IMessage(
      id: 'im-m-06',
      fromMe: true,
      section: tueEvening,
      sentLabel: '7:22 PM',
      text: 'Oh right, the wood-fired flatbread place. Incredible call.',
    ),
    _IMessage(
      id: 'im-m-07',
      fromMe: false,
      section: yestMorning,
      sentLabel: '9:41 AM',
      text: 'Morning! Just sent the shared photo album link over.',
    ),
    _IMessage(
      id: 'im-m-08',
      fromMe: false,
      section: yestMorning,
      sentLabel: '9:41 AM',
      text: 'Also grabbed oat milk and cold brew for the drive up.',
      initialTapbacks: const {_TapbackKind.thumbsUp},
    ),
    _IMessage(
      id: 'im-m-09',
      fromMe: true,
      section: yestMorning,
      sentLabel: '9:43 AM',
      text: 'You are carrying the whole logistics department on your back.',
    ),
    _IMessage(
      id: 'im-m-10',
      fromMe: true,
      section: yestMorning,
      sentLabel: '9:44 AM',
      text: 'I will bring the bluetooth speaker and the 35mm camera.',
    ),
    _IMessage(
      id: 'im-m-11',
      fromMe: false,
      section: yestMorning,
      sentLabel: '9:46 AM',
      text: 'Yes!! Bring Portra 400 if you still have a roll left.',
      initialTapbacks: const {_TapbackKind.emphasis},
    ),
    _IMessage(
      id: 'im-m-12',
      fromMe: true,
      section: yestEvening,
      sentLabel: '6:05 PM',
      text: 'Found two rolls in the desk drawer and charged the batteries.',
    ),
    _IMessage(
      id: 'im-m-13',
      fromMe: false,
      section: yestEvening,
      sentLabel: '6:07 PM',
      text:
          'Weather says clear skies at sunset too — golden hour is going to '
          'look unreal.',
    ),
    _IMessage(
      id: 'im-m-14',
      fromMe: true,
      section: yestEvening,
      sentLabel: '6:09 PM',
      text: 'Fingers crossed the coastal fog holds off until after 8.',
    ),
    _IMessage(
      id: 'im-m-15',
      fromMe: false,
      section: yestEvening,
      sentLabel: '6:12 PM',
      text:
          'Should we invite Sam and Priya to meet us straight at the '
          'restaurant?',
    ),
    _IMessage(
      id: 'im-m-16',
      fromMe: true,
      section: yestEvening,
      sentLabel: '6:13 PM',
      text:
          'Yeah they are coming from Oakland so meeting there saves 25 '
          'minutes.',
    ),
    _IMessage(
      id: 'im-m-17',
      fromMe: false,
      section: todayAfternoon,
      sentLabel: '2:15 PM',
      text: 'Wrapping my last design critique around 4:30.',
    ),
    _IMessage(
      id: 'im-m-18',
      fromMe: false,
      section: todayAfternoon,
      sentLabel: '2:16 PM',
      text: 'Sam also asked for the dinner address and time again.',
    ),
    _IMessage(
      id: 'im-m-19',
      fromMe: true,
      section: todayAfternoon,
      sentLabel: '2:18 PM',
      replyToId: 'im-m-05',
      replyToAuthor: 'Maya',
      replyToPreview:
          'Nopa — 560 Divisadero St at Hayes. Table for 4 under Maya at '
          '7:30 PM!',
      text: 'Tap the reply above to jump straight back to that message.',
      initialTapbacks: const {_TapbackKind.thumbsUp},
    ),
    _IMessage(
      id: 'im-m-20',
      fromMe: true,
      section: todayAfternoon,
      sentLabel: '2:18 PM',
      text: 'I can swing by with the car at 5:00.',
    ),
    _IMessage(
      id: 'im-m-21',
      fromMe: false,
      section: todayAfternoon,
      sentLabel: '2:19 PM',
      text: 'Tap any bubble to toggle a tapback — survives Load older!',
    ),
    _IMessage(
      id: 'im-m-22',
      fromMe: true,
      section: todayAfternoon,
      sentLabel: '2:20 PM',
      text: 'See you at 5! Playlist is queued up.',
      statusLabel: 'Read 2:20 PM',
    ),
  ];
}

List<_IMessage> _buildOlderPage(int page) {
  if (page == 1) {
    final may10 = DateTime(2026, 5, 10, 20, 14);
    final may11 = DateTime(2026, 5, 11, 12, 30);
    return [
      _IMessage(
        id: 'im-old-1-1',
        fromMe: false,
        section: may10,
        sentLabel: '8:14 PM',
        text: 'Are we still on for the Point Reyes coastal hike next weekend?',
      ),
      _IMessage(
        id: 'im-old-1-2',
        fromMe: true,
        section: may10,
        sentLabel: '8:16 PM',
        text: '100% yes — Tomales Point trail if the wind is reasonable.',
        initialTapbacks: const {_TapbackKind.heart},
      ),
      _IMessage(
        id: 'im-old-1-3',
        fromMe: false,
        section: may10,
        sentLabel: '8:18 PM',
        text: 'Yes! Last time we spotted elk right along the ridge.',
      ),
      _IMessage(
        id: 'im-old-1-4',
        fromMe: true,
        section: may11,
        sentLabel: '12:30 PM',
        text:
            'Booked the little cabin near Inverness for Friday and Saturday '
            'night.',
      ),
      _IMessage(
        id: 'im-old-1-5',
        fromMe: false,
        section: may11,
        sentLabel: '12:32 PM',
        text:
            'Amazing, let me look up dinner spots in the city before we head '
            'north.',
        initialTapbacks: const {_TapbackKind.thumbsUp},
      ),
    ];
  }

  final may06 = DateTime(2026, 5, 6, 16, 42);
  return [
    _IMessage(
      id: 'im-old-2-1',
      fromMe: true,
      section: may06,
      sentLabel: '4:42 PM',
      text: 'Any chance you want to escape the city for a couple days mid-May?',
    ),
    _IMessage(
      id: 'im-old-2-2',
      fromMe: false,
      section: may06,
      sentLabel: '4:45 PM',
      text: 'Do not even have to ask twice. Coast or mountains?',
      initialTapbacks: const {_TapbackKind.emphasis},
    ),
    _IMessage(
      id: 'im-old-2-3',
      fromMe: true,
      section: may06,
      sentLabel: '4:47 PM',
      text: 'Coast — oysters, fog, and zero laptops.',
    ),
    _IMessage(
      id: 'im-old-2-4',
      fromMe: false,
      section: may06,
      sentLabel: '4:48 PM',
      text: 'Sold. Putting it on the calendar now.',
      initialTapbacks: const {_TapbackKind.heart},
    ),
  ];
}
