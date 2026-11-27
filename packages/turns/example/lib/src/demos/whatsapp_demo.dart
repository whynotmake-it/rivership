import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

/// Interactive WhatsApp-style group chat demo showcasing
/// `TurnScrollView<DateTime>.sectioned` with sticky push-up date pills,
/// `0.0px`-shift prepend pagination with preserved widget `State`,
/// offscreen jump-to-quoted-reply, O(1) `initialItemId` deep-link opening,
/// unread jump-to-bottom pill, and a live-measured `CoilInputMessage` composer.
class WhatsAppDemo extends StatefulWidget {
  /// Creates the WhatsApp-style messaging demo.
  const WhatsAppDemo({super.key});

  @override
  State<WhatsAppDemo> createState() => _WhatsAppDemoState();
}

class _WhatsAppDemoState extends State<WhatsAppDemo> {
  static const _brandSeed = Color(0xFF00A884);
  static const _quoteTargetId = 'wa-m10';
  static const _deepLinkTargetId = 'wa-h0642';
  static const _deepLinkDisplayDay = 'Feb 11';
  static final _today = DateTime(2025, 5, 14);

  late TurnScrollController _controller;
  late List<_WaMessage> _messages;
  late Set<String> _loadedMessageIds;
  late List<List<_WaMessage>> _olderPages;
  final TextEditingController _inputController = TextEditingController();

  var _viewEpoch = 0;
  var _deepLinkActive = false;
  var _isAutoLoadingOlder = false;
  var _unreadCount = 0;
  var _incomingCursor = 0;
  var _sentCounter = 0;
  double _composerHeight = 84;

  String? _highlightedId;
  Timer? _highlightTimer;
  Timer? _autoLoadTimer;

  @override
  void initState() {
    super.initState();
    _messages = _buildInitialMessages();
    _loadedMessageIds = {for (final m in _messages) m.id};
    _olderPages = _buildOlderPages();
    _controller = _createController();
  }

  TurnScrollController _createController() {
    final controller = TurnScrollController(debugLabel: 'WhatsAppDemo');
    controller.isAwayFromBottom.addListener(_onAwayFromBottomChanged);
    return controller;
  }

  void _replaceController() {
    final previous = _controller;
    previous.isAwayFromBottom.removeListener(_onAwayFromBottomChanged);
    _controller = _createController();
    // Dispose after the frame so the outgoing CustomScrollView detaches first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previous.dispose();
    });
  }

  void _onAwayFromBottomChanged() {
    if (!_controller.isAwayFromBottom.value && _unreadCount != 0) {
      setState(() => _unreadCount = 0);
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _autoLoadTimer?.cancel();
    _controller.isAwayFromBottom.removeListener(_onAwayFromBottomChanged);
    _controller.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _highlightMessage(String id) {
    _highlightTimer?.cancel();
    setState(() => _highlightedId = id);
    _highlightTimer = Timer(const Duration(milliseconds: 1450), () {
      if (!mounted) return;
      if (_highlightedId == id) {
        setState(() => _highlightedId = null);
      }
    });
  }

  void _prependNextPage({bool fromAutoScroll = false}) {
    if (_olderPages.isEmpty) {
      if (_isAutoLoadingOlder) {
        setState(() => _isAutoLoadingOlder = false);
      }
      return;
    }
    if (!fromAutoScroll) {
      _autoLoadTimer?.cancel();
    }
    setState(() {
      final page = _olderPages.removeAt(0);
      _messages = [...page, ..._messages];
      _loadedMessageIds.addAll(page.map((m) => m.id));
      _isAutoLoadingOlder = false;
    });
  }

  bool _onTurnScroll(TurnScrollNotification notification) {
    if (notification.isProgrammatic) return false;
    if (_olderPages.isEmpty || _isAutoLoadingOlder) return false;
    if (notification.leadingExtent > 160) return false;

    setState(() => _isAutoLoadingOlder = true);
    _autoLoadTimer?.cancel();
    _autoLoadTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _prependNextPage(fromAutoScroll: true);
    });
    return false;
  }

  Future<void> _jumpToQuoted(String targetId) async {
    while (!_loadedMessageIds.contains(targetId) && _olderPages.isNotEmpty) {
      _prependNextPage();
    }
    if (await _controller.scrollTo(targetId, alignment: 0.25) && mounted) {
      _highlightMessage(targetId);
    }
  }

  void _toggleDeepLink() {
    _autoLoadTimer?.cancel();
    _isAutoLoadingOlder = false;
    final nextDeepLink = !_deepLinkActive;
    _replaceController();
    setState(() {
      _deepLinkActive = nextDeepLink;
      _viewEpoch++;
      _unreadCount = 0;
    });
    if (nextDeepLink) {
      _highlightMessage(_deepLinkTargetId);
    } else {
      _highlightTimer?.cancel();
      _highlightedId = null;
    }
  }

  void _returnToLatest() {
    if (!_deepLinkActive) return;
    _toggleDeepLink();
  }

  void _simulateIncoming() {
    final sample = _incomingPool[_incomingCursor % _incomingPool.length];
    _incomingCursor++;
    final wasAway = _controller.isAwayFromBottom.value;
    final id = 'wa-live-$_incomingCursor';
    final minute = 42 + (_incomingCursor % 17);
    final next = _WaMessage(
      id: id,
      sender: sample.sender,
      text: sample.text,
      day: _today,
      time: '15:${minute.toString().padLeft(2, '0')}',
      isMe: false,
      voiceNote: sample.voiceNote,
    );

    setState(() {
      _messages = [..._messages, next];
      _loadedMessageIds.add(next.id);
      if (wasAway) {
        _unreadCount++;
      }
    });

    if (!wasAway) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_controller.jumpToBottom());
        }
      });
    }
  }

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _sentCounter++;
    final minute = 45 + (_sentCounter % 14);
    final next = _WaMessage(
      id: 'wa-sent-$_sentCounter',
      sender: 'You',
      text: trimmed,
      day: _today,
      time: '15:${minute.toString().padLeft(2, '0')}',
      isMe: true,
      delivered: true,
    );

    setState(() {
      _messages = [..._messages, next];
      _loadedMessageIds.add(next.id);
      _unreadCount = 0;
      if (_deepLinkActive) {
        _deepLinkActive = false;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_controller.jumpToBottom());
      }
    });
  }

  Future<void> _jumpToBottom() async {
    setState(() => _unreadCount = 0);
    await _controller.jumpToBottom();
  }

  void _onComposerSizeChanged(Size size) {
    if ((size.height - _composerHeight).abs() > 1) {
      setState(() => _composerHeight = size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CoilTheme.override(
      transform: (parent) {
        final isDark = parent.colors.brightness == Brightness.dark;
        return parent.copyWith(
          brandSelection: true,
          colors: CoilColors.fromSeed(
            brightness: parent.colors.brightness,
            brand: _brandSeed,
            neutralHue: isDark ? 210 : 88,
            neutralChroma: isDark ? 0.014 : 0.008,
          ),
        );
      },
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final text = CoilTheme.textOf(context);
    final isDark = colors.brightness == Brightness.dark;

    final canvasColor = isDark
        ? CoilColorMix.oklab(colors.background, const Color(0xFF0B141A), 0.35)
        : CoilColorMix.oklab(colors.background, const Color(0xFFEAE2D6), 0.25);
    final wallpaperMarkColor = colors.foreground.withValues(
      alpha: isDark ? 0.032 : 0.045,
    );

    return ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          _buildHeader(context, colors, text),
          if (_deepLinkActive) _buildDeepLinkBanner(context, colors, text),
          Expanded(
            child: ColoredBox(
              color: canvasColor,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _ChatWallpaperPainter(
                        color: wallpaperMarkColor,
                      ),
                    ),
                  ),
                  NotificationListener<TurnScrollNotification>(
                    onNotification: _onTurnScroll,
                    child: TurnScrollView<DateTime>.sectioned(
                      key: ValueKey('whatsapp.thread.$_viewEpoch'),
                      controller: _controller,
                      itemCount: _messages.length,
                      itemId: (i) => _messages[i].id,
                      sectionId: (i) => _messages[i].day,
                      sectionHeaderSpacing: 8,
                      itemSpacing: 4,
                      applyTopPadding: false,
                      applyBottomPadding: false,
                      initialItemId: _deepLinkActive ? _deepLinkTargetId : null,
                      initialAlignment: _deepLinkActive ? 0.25 : 0,
                      initialAtBottom: !_deepLinkActive,
                      padding: EdgeInsets.fromLTRB(
                        12,
                        10,
                        12,
                        _composerHeight + 16,
                      ),
                      leadingSlivers: [
                        SliverToBoxAdapter(
                          child: _buildLeadingHistoryBanner(
                            context,
                            colors,
                            text,
                          ),
                        ),
                      ],
                      sectionHeaderBuilder: (context, day) =>
                          _DatePillHeader(label: _formatDay(day)),
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final prev = index > 0 ? _messages[index - 1] : null;
                        final sameSenderAsPrev =
                            prev != null &&
                            prev.sender == message.sender &&
                            prev.day == message.day;
                        final isHighlighted = _highlightedId == message.id;

                        return _WhatsAppMessageBubble(
                          message: message,
                          showSenderName: !message.isMe && !sameSenderAsPrev,
                          extraTopSpacing: index > 0 && !sameSenderAsPrev
                              ? 8
                              : 0,
                          highlighted: isHighlighted,
                          onTapQuote: message.quoted == null
                              ? null
                              : () => unawaited(
                                  _jumpToQuoted(message.quoted!.id),
                                ),
                          quotedExists:
                              message.quoted != null &&
                              (_loadedMessageIds.contains(message.quoted!.id) ||
                                  _olderPages.isNotEmpty),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: _composerHeight + 14,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _controller.isAwayFromBottom,
                      builder: (context, isAway, _) => _JumpToBottomPill(
                        visible: isAway,
                        unreadCount: _unreadCount,
                        onPressed: () => unawaited(_jumpToBottom()),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _MeasureSize(
                      onChange: _onComposerSizeChanged,
                      child: _buildComposerBar(context, colors),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    CoilColors colors,
    CoilTextTheme text,
  ) {
    final topInset = MediaQuery.paddingOf(context).top;
    final pagesLeft = _olderPages.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaces[1],
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.brandFill,
                    shape: const CircleBorder(),
                  ),
                  child: SizedBox.square(
                    dimension: 36,
                    child: Center(
                      child: Icon(
                        LucideIcons.mountain,
                        size: 18,
                        color: colors.onBrandFill,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Dolomites Hut Trip',
                              style: text.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CoilBadge(
                            color: CoilBadgeColor.brand,
                            shape: CoilBadgeShape.pill,
                            size: CoilSize.compact,
                            child: Text(
                              '${_formatCount(_messages.length)} msgs',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Elena, Marcus, Priya, Tomas, You · '
                        '${_formatCount(_messages.length)} messages',
                        style: text.muted.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  CoilButton(
                    key: const Key('whatsapp.load_older'),
                    size: CoilSize.compact,
                    variant: CoilButtonVariant.secondary,
                    leading: const Icon(LucideIcons.history, size: 14),
                    onPressed: pagesLeft > 0 ? _prependNextPage : null,
                    child: Text(
                      pagesLeft > 0
                          ? 'Load older ($pagesLeft)'
                          : 'All history loaded',
                    ),
                  ),
                  CoilButton(
                    key: const Key('whatsapp.open_deeplink'),
                    size: CoilSize.compact,
                    variant: _deepLinkActive
                        ? CoilButtonVariant.brand
                        : CoilButtonVariant.secondary,
                    leading: Icon(
                      _deepLinkActive
                          ? LucideIcons.arrowDownToLine
                          : LucideIcons.link2,
                      size: 14,
                    ),
                    onPressed: _toggleDeepLink,
                    child: Text(
                      _deepLinkActive ? 'Back to latest' : 'Deep link · #642',
                    ),
                  ),
                  CoilButton(
                    key: const Key('whatsapp.simulate_incoming'),
                    size: CoilSize.compact,
                    variant: CoilButtonVariant.secondary,
                    leading: const Icon(
                      LucideIcons.messageSquarePlus,
                      size: 14,
                    ),
                    onPressed: _simulateIncoming,
                    child: const Text('Simulate incoming'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeepLinkBanner(
    BuildContext context,
    CoilColors colors,
    CoilTextTheme text,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.brandWash,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(LucideIcons.sparkles, size: 14, color: colors.brandInk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Opened O(1) at #642 of ${_formatCount(_messages.length)} '
                '($_deepLinkDisplayDay) via initialItemId · '
                'sticky date on frame 1',
                style: text.caption.copyWith(color: colors.brandInk),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            CoilButton(
              key: const Key('whatsapp.return_latest'),
              size: CoilSize.compact,
              variant: CoilButtonVariant.tertiary,
              onPressed: _returnToLatest,
              child: const Text('Latest'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingHistoryBanner(
    BuildContext context,
    CoilColors colors,
    CoilTextTheme text,
  ) {
    final pagesLeft = _olderPages.length;
    final remainingMessages = _olderPages.fold<int>(
      0,
      (sum, page) => sum + page.length,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.surfaces[2].withValues(alpha: 0.92),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.border),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pagesLeft > 0
                        ? LucideIcons.arrowUpCircle
                        : LucideIcons.lock,
                    size: 14,
                    color: pagesLeft > 0
                        ? colors.brandInk
                        : colors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      pagesLeft > 0
                          ? (_isAutoLoadingOlder
                                ? 'Loading older messages…'
                                : '$remainingMessages earlier messages · '
                                      'scroll up or tap Load older')
                          : 'End-to-end encrypted · '
                                'beginning of Dolomites Hut Trip',
                      style: text.muted.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposerBar(BuildContext context, CoilColors colors) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaces[1],
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, math.max(10, bottomInset + 6)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CoilInputMessage(
              controller: _inputController,
              placeholder: const Text('Message Dolomites Hut Trip…'),
              onSend: _sendMessage,
              maxLines: 4,
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDay(DateTime day) {
    final diff = _today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
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
    if (day.year < _today.year) {
      return '${months[day.month - 1]} ${day.day}, ${day.year}';
    }
    return '${months[day.month - 1]} ${day.day}';
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

class _DatePillHeader extends StatelessWidget {
  const _DatePillHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final isDark = colors.brightness == Brightness.dark;
    final pillFill = isDark
        ? const Color(0xFF182229)
        : colors.surfaces[2].withValues(alpha: 0.96);

    // Vertical padding keeps the soft shadow inside ClipRect during push-up.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: pillFill,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: colors.border),
            ),
            shadows: [
              BoxShadow(
                color: colors.shadowColor,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              label,
              style: text.muted.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _JumpToBottomPill extends StatelessWidget {
  const _JumpToBottomPill({
    required this.visible,
    required this.unreadCount,
    required this.onPressed,
  });

  final bool visible;
  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final motion = CoilTheme.motionOf(context);
    final text = CoilTheme.textOf(context);

    return SingleMotionBuilder(
      value: visible ? 1.0 : 0.0,
      motion: visible ? motion.standard : motion.standardExit,
      debugLabel: 'WhatsApp.jumpToBottom',
      builder: (context, progress, _) {
        if (!visible && progress <= 0.01) {
          return const SizedBox.shrink();
        }
        final clamped = progress.clamp(0.0, 1.0);
        final scale = 0.85 + 0.15 * progress;
        final dy = (1 - progress) * 14;
        return IgnorePointer(
          ignoring: !visible,
          child: Opacity(
            opacity: clamped,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(
                scale: scale,
                child: Semantics(
                  button: true,
                  label: unreadCount > 0
                      ? 'Jump to bottom, $unreadCount unread messages'
                      : 'Jump to bottom',
                  child: CoilInteraction(
                    key: visible ? const Key('whatsapp.jump_bottom') : null,
                    onPressed: visible ? onPressed : null,
                    builder: (context, states, _) {
                      final hovered = states.contains(WidgetState.hovered);
                      final pressed = states.contains(WidgetState.pressed);
                      final focused = states.contains(WidgetState.focused);
                      final fill = pressed
                          ? CoilColorMix.oklab(
                              colors.surfaces[2],
                              colors.foreground,
                              0.9,
                            )
                          : hovered
                          ? CoilColorMix.oklab(
                              colors.surfaces[2],
                              colors.foreground,
                              0.95,
                            )
                          : colors.surfaces[2];
                      return CoilFocusRing(
                        visible: focused,
                        borderRadius: BorderRadius.circular(999),
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: fill,
                            shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(color: colors.border),
                            ),
                            shadows: [
                              BoxShadow(
                                color: colors.shadowColor.withValues(
                                  alpha: colors.shadowColor.a * 2,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: unreadCount > 0 ? 12 : 10,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (unreadCount > 0) ...[
                                  CoilBadge(
                                    color: CoilBadgeColor.brand,
                                    shape: CoilBadgeShape.pill,
                                    size: CoilSize.compact,
                                    child: Text('$unreadCount'),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'new',
                                    style: text.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Icon(
                                  LucideIcons.chevronDown,
                                  size: 18,
                                  color: colors.foreground,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WhatsAppMessageBubble extends StatefulWidget {
  const _WhatsAppMessageBubble({
    required this.message,
    required this.showSenderName,
    required this.extraTopSpacing,
    required this.highlighted,
    required this.quotedExists,
    this.onTapQuote,
  });

  final _WaMessage message;
  final bool showSenderName;
  final double extraTopSpacing;
  final bool highlighted;
  final bool quotedExists;
  final VoidCallback? onTapQuote;

  @override
  State<_WhatsAppMessageBubble> createState() => _WhatsAppMessageBubbleState();
}

class _WhatsAppMessageBubbleState extends State<_WhatsAppMessageBubble> {
  // Local state inside each message item proves TurnScrollView preserves
  // element State across 0.0px-shift prepend pagination!
  var _userReacted = false;
  var _transcriptExpanded = false;
  var _isPlaying = false;
  double _playProgress = 0;
  Timer? _playTimer;

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _playTimer?.cancel();
      setState(() => _isPlaying = false);
      return;
    }
    if (_playProgress >= 0.99) {
      _playProgress = 0;
    }
    setState(() => _isPlaying = true);
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _playProgress + 0.015;
      if (next >= 1.0) {
        timer.cancel();
        setState(() {
          _playProgress = 1.0;
          _isPlaying = false;
        });
      } else {
        setState(() => _playProgress = next);
      }
    });
  }

  void _toggleTranscript() {
    setState(() => _transcriptExpanded = !_transcriptExpanded);
  }

  void _toggleReaction() {
    setState(() => _userReacted = !_userReacted);
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final motion = CoilTheme.motionOf(context);
    final isDark = colors.brightness == Brightness.dark;
    final message = widget.message;

    final bubbleFill = message.isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
        : (isDark ? const Color(0xFF202C33) : colors.surfaces[2]);
    final bubbleInk = message.isMe
        ? (isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21))
        : colors.foreground;
    final metaInk = bubbleInk.withValues(alpha: 0.62);
    final senderColor = _senderColor(message.sender, isDark: isDark);

    final radius = BorderRadius.only(
      topLeft: Radius.circular(message.isMe || !widget.showSenderName ? 14 : 4),
      topRight: Radius.circular(
        !message.isMe || !widget.showSenderName ? 14 : 4,
      ),
      bottomLeft: const Radius.circular(14),
      bottomRight: const Radius.circular(14),
    );

    final reactionCount = message.baseReactions + (_userReacted ? 1 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = math.min(constraints.maxWidth * 0.80, 460);

        return SingleMotionBuilder(
          value: widget.highlighted ? 1.0 : 0.0,
          motion: widget.highlighted ? motion.standard : motion.gentleExit,
          debugLabel: 'WhatsApp.highlight.${message.id}',
          builder: (context, glow, child) {
            final wash = glow.clamp(0.0, 1.0);
            final highlightAlpha = (isDark ? 0.24 : 0.18) * wash;
            return DecoratedBox(
              decoration: ShapeDecoration(
                color: wash > 0.005
                    ? colors.brand.withValues(alpha: highlightAlpha)
                    : const Color(0x00000000),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  2,
                  widget.extraTopSpacing + 2,
                  2,
                  2,
                ),
                child: Align(
                  alignment: message.isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxBubbleWidth.toDouble(),
                    ),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: bubbleFill,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: radius,
                          side: BorderSide(
                            color: wash > 0.05
                                ? Color.lerp(colors.border, colors.brand, wash)!
                                : colors.border.withValues(
                                    alpha: isDark ? 0.10 : 0.08,
                                  ),
                            width: 1 + 0.8 * wash,
                          ),
                        ),
                        shadows: [
                          BoxShadow(
                            color: colors.shadowColor.withValues(
                              alpha:
                                  colors.shadowColor.a * (isDark ? 1.1 : 0.8),
                            ),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(11, 8, 11, 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.showSenderName) ...[
                              Text(
                                message.sender,
                                style: text.caption.copyWith(
                                  color: senderColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            if (message.quoted case final quoted?) ...[
                              _QuotedReplyCard(
                                key: message.quoteCardKey,
                                quoted: quoted,
                                accentColor: _senderColor(
                                  quoted.sender,
                                  isDark: isDark,
                                ),
                                isOutgoingBubble: message.isMe,
                                onPressed: widget.quotedExists
                                    ? widget.onTapQuote
                                    : null,
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (message.voiceNote case final voice?) ...[
                              _VoiceNotePlayer(
                                voiceNote: voice,
                                isPlaying: _isPlaying,
                                progress: _playProgress,
                                transcriptExpanded: _transcriptExpanded,
                                inkColor: bubbleInk,
                                metaColor: metaInk,
                                onTogglePlay: _togglePlay,
                                onToggleTranscript: _toggleTranscript,
                              ),
                            ] else
                              Text(
                                message.text,
                                style: text.body.copyWith(color: bubbleInk),
                              ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ReactionChip(
                                  icon: message.reactionIcon,
                                  label: message.reactionLabel,
                                  count: reactionCount,
                                  active: _userReacted,
                                  onPressed: _toggleReaction,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  message.time,
                                  style: text.micro.copyWith(color: metaInk),
                                ),
                                if (message.isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    message.delivered
                                        ? LucideIcons.checkCheck
                                        : LucideIcons.check,
                                    size: 13,
                                    color: message.delivered
                                        ? (isDark
                                              ? const Color(0xFF53BDEB)
                                              : const Color(0xFF027EB5))
                                        : metaInk,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuotedReplyCard extends StatelessWidget {
  const _QuotedReplyCard({
    required this.quoted,
    required this.accentColor,
    required this.isOutgoingBubble,
    required this.onPressed,
    super.key,
  });

  final _WaQuote quoted;
  final Color accentColor;
  final bool isOutgoingBubble;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final isDark = colors.brightness == Brightness.dark;

    final baseFill = isDark
        ? colors.overlay.withValues(alpha: isOutgoingBubble ? 0.10 : 0.06)
        : colors.overlay.withValues(alpha: isOutgoingBubble ? 0.055 : 0.045);

    return Semantics(
      button: true,
      label: 'Jump to quoted message from ${quoted.sender}',
      child: CoilInteraction(
        onPressed: onPressed,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          final focused = states.contains(WidgetState.focused);
          final fill = pressed
              ? colors.brandWash
              : hovered
              ? CoilColorMix.oklab(baseFill, colors.brand, 0.85)
              : baseFill;
          return CoilFocusRing(
            visible: focused,
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(color: fill),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ColoredBox(
                        color: accentColor,
                        child: const SizedBox(width: 3.5),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      quoted.sender,
                                      style: text.caption.copyWith(
                                        color: accentColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    LucideIcons.cornerUpLeft,
                                    size: 11,
                                    color: colors.mutedForeground,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                quoted.preview,
                                style: text.muted.caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VoiceNotePlayer extends StatelessWidget {
  const _VoiceNotePlayer({
    required this.voiceNote,
    required this.isPlaying,
    required this.progress,
    required this.transcriptExpanded,
    required this.inkColor,
    required this.metaColor,
    required this.onTogglePlay,
    required this.onToggleTranscript,
  });

  final _WaVoiceNote voiceNote;
  final bool isPlaying;
  final double progress;
  final bool transcriptExpanded;
  final Color inkColor;
  final Color metaColor;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleTranscript;

  static const _bars = <double>[
    0.35,
    0.62,
    0.88,
    0.50,
    0.95,
    0.72,
    0.42,
    0.80,
    1,
    0.66,
    0.48,
    0.84,
    0.58,
    0.76,
    0.38,
    0.68,
    0.90,
    0.52,
    0.44,
    0.30,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final motion = CoilTheme.motionOf(context);

    final elapsedSeconds = (voiceNote.durationSeconds * progress).round();
    final shownSeconds = isPlaying || progress > 0
        ? elapsedSeconds
        : voiceNote.durationSeconds;
    final timeLabel = '0:${shownSeconds.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: isPlaying ? 'Pause voice note' : 'Play voice note',
              child: CoilInteraction(
                onPressed: onTogglePlay,
                builder: (context, states, _) {
                  final pressed = states.contains(WidgetState.pressed);
                  final focused = states.contains(WidgetState.focused);
                  return CoilFocusRing(
                    visible: focused,
                    borderRadius: BorderRadius.circular(999),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: pressed ? colors.brandInk : colors.brandFill,
                        shape: const CircleBorder(),
                      ),
                      child: SizedBox.square(
                        dimension: 34,
                        child: Center(
                          child: Icon(
                            isPlaying ? LucideIcons.pause : LucideIcons.play,
                            size: 15,
                            color: colors.onBrandFill,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2.5,
                      children: [
                        for (var i = 0; i < _bars.length; i++)
                          _WaveformBar(
                            heightFactor: _bars[i],
                            active: (i / _bars.length) <= progress,
                            activeColor: colors.brandFill,
                            inactiveColor: metaColor.withValues(alpha: 0.35),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.mic, size: 11, color: metaColor),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel,
                        style: text.micro.copyWith(color: metaColor),
                      ),
                      const SizedBox(width: 10),
                      CoilInteraction(
                        onPressed: onToggleTranscript,
                        builder: (context, states, _) {
                          final hovered = states.contains(WidgetState.hovered);
                          final focused = states.contains(WidgetState.focused);
                          return CoilFocusRing(
                            visible: focused,
                            borderRadius: BorderRadius.circular(6),
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: hovered
                                    ? colors.hover
                                    : const Color(0x00000000),
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      transcriptExpanded
                                          ? 'Hide transcript'
                                          : 'Transcript',
                                      style: text.micro.copyWith(
                                        color: colors.brandInk,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      transcriptExpanded
                                          ? LucideIcons.chevronUp
                                          : LucideIcons.chevronDown,
                                      size: 11,
                                      color: colors.brandInk,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SingleMotionBuilder(
          value: transcriptExpanded ? 1.0 : 0.0,
          motion: transcriptExpanded ? motion.standard : motion.standardExit,
          debugLabel: 'WhatsApp.transcript',
          builder: (context, factor, child) {
            if (!transcriptExpanded && factor <= 0.01) {
              return const SizedBox.shrink();
            }
            return ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                heightFactor: factor.clamp(0.0, 1.0),
                child: Opacity(
                  opacity: factor.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.overlay.withValues(alpha: 0.045),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  voiceNote.transcript,
                  style: text.caption.copyWith(color: inkColor),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WaveformBar extends StatelessWidget {
  const _WaveformBar({
    required this.heightFactor,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double heightFactor;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: SizedBox(width: 2.5, height: 6 + 16 * heightFactor),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final motion = CoilTheme.motionOf(context);

    return SingleMotionBuilder(
      value: active ? 1.0 : 0.0,
      motion: active ? motion.quick : motion.quickExit,
      debugLabel: 'WhatsApp.reaction',
      builder: (context, t, _) {
        final scale = 1.0 + 0.08 * math.sin(t.clamp(0.0, 1.0) * math.pi);
        return Transform.scale(
          scale: scale,
          child: Semantics(
            button: true,
            toggled: active,
            label: active ? 'Remove $label reaction' : 'React with $label',
            child: CoilInteraction(
              onPressed: onPressed,
              builder: (context, states, _) {
                final hovered = states.contains(WidgetState.hovered);
                final focused = states.contains(WidgetState.focused);
                final fill = active
                    ? colors.brandWash
                    : hovered
                    ? colors.hover
                    : colors.overlay.withValues(alpha: 0.04);
                final iconColor = active
                    ? colors.brandInk
                    : colors.mutedForeground;
                return CoilFocusRing(
                  visible: focused,
                  borderRadius: BorderRadius.circular(999),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: fill,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(
                          color: active ? colors.brandMark : colors.border,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 3,
                        children: [
                          Icon(icon, size: 11, color: iconColor),
                          if (count > 0)
                            Text(
                              '$count',
                              style: text.micro.copyWith(
                                color: iconColor,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ChatWallpaperPainter extends CustomPainter {
  const _ChatWallpaperPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    const spacing = 44.0;
    for (var y = 16.0; y < size.height; y += spacing) {
      final rowIndex = (y / spacing).floor();
      final xOffset = rowIndex.isOdd ? spacing * 0.5 : 0.0;
      for (var x = 16.0 + xOffset; x < size.width; x += spacing) {
        if ((rowIndex + (x ~/ spacing)).isEven) {
          canvas.drawCircle(Offset(x, y), 3.2, paint);
        } else {
          final path = Path()
            ..moveTo(x - 3.2, y + 2.4)
            ..lineTo(x, y - 3.2)
            ..lineTo(x + 3.2, y + 2.4)
            ..close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ChatWallpaperPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange: onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize({required this.onChange});

  ValueChanged<Size> onChange;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final next = size;
    if (_lastSize == next) return;
    _lastSize = next;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(next));
  }
}

Color _senderColor(String sender, {required bool isDark}) => switch (sender) {
  'Elena' => isDark ? const Color(0xFF53BDEB) : const Color(0xFF027EB5),
  'Marcus' => isDark ? const Color(0xFFFFB057) : const Color(0xFFB45309),
  'Priya' => isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
  'Tomas' => isDark ? const Color(0xFFFB7185) : const Color(0xFFBE123C),
  _ => isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
};

@immutable
class _WaQuote {
  const _WaQuote({
    required this.id,
    required this.sender,
    required this.preview,
  });

  final String id;
  final String sender;
  final String preview;
}

@immutable
class _WaVoiceNote {
  const _WaVoiceNote({
    required this.durationSeconds,
    required this.transcript,
  });

  final int durationSeconds;
  final String transcript;
}

@immutable
class _WaMessage {
  const _WaMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.day,
    required this.time,
    required this.isMe,
    this.quoted,
    this.quoteCardKey,
    this.voiceNote,
    this.delivered = false,
    this.reactionIcon = LucideIcons.thumbsUp,
    this.reactionLabel = 'like',
    this.baseReactions = 0,
  });

  final String id;
  final String sender;
  final String text;
  final DateTime day;
  final String time;
  final bool isMe;
  final _WaQuote? quoted;
  final Key? quoteCardKey;
  final _WaVoiceNote? voiceNote;
  final bool delivered;
  final IconData reactionIcon;
  final String reactionLabel;
  final int baseReactions;
}

@immutable
class _IncomingTemplate {
  const _IncomingTemplate({
    required this.sender,
    required this.text,
    this.voiceNote,
  });

  final String sender;
  final String text;
  final _WaVoiceNote? voiceNote;
}

const _incomingPool = <_IncomingTemplate>[
  _IncomingTemplate(
    sender: 'Marcus',
    text:
        'Just re-checked the Rifugio Lagazuoi email — yes, '
        'half-board dinner and breakfast are both confirmed!',
  ),
  _IncomingTemplate(
    sender: 'Priya',
    text:
        'Also packed an extra 20,000 mAh battery bank so nobody '
        'runs out of offline GPX maps on day 3.',
  ),
  _IncomingTemplate(
    sender: 'Tomas',
    text: 'Voice note',
    voiceNote: _WaVoiceNote(
      durationSeconds: 11,
      transcript:
          'Heads up from Cortina bus desk: the 07:35 shuttle to '
          'Lago di Braies sells out early, so let us grab seats '
          'ten minutes ahead.',
    ),
  ),
  _IncomingTemplate(
    sender: 'Elena',
    text:
        'Weather radar just flipped to clear skies for sunrise '
        'at Lagazuoi! Bringing the wide lens.',
  ),
];

const _archiveSenders = <String>['Elena', 'Marcus', 'Priya', 'Tomas', 'You'];

const _archiveTopics = <String>[
  'Checked Alta Via 1 elevation profiles — Forcella del Lago looks wild.',
  'Anyone have a favorite ultralight rain shell that packs super small?',
  'Did a 14 km training loop this morning with 650m gain and an 8 kg pack.',
  'Comparing trail runners vs mid-cut boots for Dolomites scree descents.',
  'Spotted a solid deal on silk sleeping bag liners — want me to grab 5?',
  'Hut etiquette note: dinner is at 19:00 sharp and quiet hours at 22:00.',
  'Mapped water refill fountains along Stage 2 so 2L capacity is plenty.',
  'Download offline TopoItaly tiles before we leave — signal drops early.',
  'Snowpack looks clear on south-facing switchbacks below Lagazuoi.',
  'Who else is packing a collapsible coffee dripper for early starts?',
  'Found a great pastry shop right by Venice Mestre station for transfer.',
  'Tested headlamp battery on low beam — lasted 18 hours easily.',
  'Made a shared gear weight sheet so we skip duplicate first-aid kits.',
  'Cortina Express takes hiking poles strapped tight to packs in luggage.',
  'Booked a weekend shakedown hike to test Merino socks and pack straps.',
  'Anyone bringing rubber pole tips for the paved stretches near Cortina?',
  'Sunrise is around 05:35 up on the ridge — totally worth an early alarm.',
  'Double-checked passport expiry and alpine rescue coverage to 3,000m.',
];

const _archiveVoiceTranscripts = <String>[
  'Quick trail report: the pack harness feels way better loaded low.',
  'Cortina guide desk suggests starting by 08:30 to beat midday clouds.',
  'Heads up: bring cash for hut drinks since card readers drop in storms.',
];

const _archiveReactionIcons = <(IconData, String)>[
  (LucideIcons.thumbsUp, 'like'),
  (LucideIcons.mountain, 'mountain'),
  (LucideIcons.flame, 'fire'),
  (LucideIcons.heart, 'love'),
  (LucideIcons.sparkles, 'celebrate'),
  (LucideIcons.map, 'map'),
];

List<_WaMessage> _generateArchiveRange({
  required String idPrefix,
  required int startNumber,
  required int count,
  required DateTime startDay,
  required int daySpan,
  int? deepLinkOneBasedNumber,
}) {
  return List<_WaMessage>.generate(count, (i) {
    final number = startNumber + i;
    final dayOffset = (i * daySpan) ~/ count;
    final day = startDay.add(Duration(days: dayOffset));

    if (deepLinkOneBasedNumber != null && number == deepLinkOneBasedNumber) {
      return _WaMessage(
        id: _WhatsAppDemoState._deepLinkTargetId,
        sender: 'Priya',
        text:
            'Pinned Milestone (#$number of 2,400 · Feb 11): Full Alta Via 1 '
            'permit timeline, rifugio deposit schedule, and Lago di Braies '
            'trailhead coordinates (46.6943° N, 12.0854° E).',
        day: day,
        time: '13:42',
        isMe: false,
        reactionIcon: LucideIcons.pin,
        reactionLabel: 'pinned',
        baseReactions: 5,
      );
    }

    final senderIndex = (number * 7 + dayOffset * 3) % _archiveSenders.length;
    final sender = _archiveSenders[senderIndex];
    final isMe = sender == 'You';

    final sameDaySlot = i % 20;
    final hour = 8 + (sameDaySlot * 12) ~/ 20;
    final minute = (number * 13 + sameDaySlot * 7) % 60;
    final time =
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';

    final isVoiceNote = !isMe && number % 29 == 0;
    final topic =
        _archiveTopics[(number * 5 + dayOffset) % _archiveTopics.length];
    final reaction =
        _archiveReactionIcons[number % _archiveReactionIcons.length];
    final baseReactions = number % 5 == 0 ? (number % 4) + 1 : 0;

    return _WaMessage(
      id: '$idPrefix${number.toString().padLeft(4, '0')}',
      sender: sender,
      text: isVoiceNote ? 'Voice note' : topic,
      day: day,
      time: time,
      isMe: isMe,
      delivered: isMe,
      voiceNote: isVoiceNote
          ? _WaVoiceNote(
              durationSeconds: 8 + (number % 9),
              transcript:
                  _archiveVoiceTranscripts[number %
                      _archiveVoiceTranscripts.length],
            )
          : null,
      reactionIcon: reaction.$1,
      reactionLabel: reaction.$2,
      baseReactions: baseReactions,
    );
  });
}

List<_WaMessage> _buildInitialMessages() {
  final may11 = DateTime(2025, 5, 11);
  final may12 = DateTime(2025, 5, 12);
  final yesterday = DateTime(2025, 5, 13);
  final today = DateTime(2025, 5, 14);

  // 2,364 historical messages (Jan 10 – May 10) + 36 recent = 2,400 total.
  final earlier = _generateArchiveRange(
    idPrefix: 'wa-h',
    startNumber: 1,
    count: 2364,
    startDay: DateTime(2025, 1, 10),
    daySpan: 121,
    deepLinkOneBasedNumber: 642,
  );

  return [
    ...earlier,
    // --- May 11 (8 messages) ---
    _WaMessage(
      id: 'wa-m01',
      sender: 'Elena',
      text: 'Okay team, Alta Via 1 hut window just opened for our dates!',
      day: may11,
      time: '09:12',
      isMe: false,
      reactionIcon: LucideIcons.mountain,
      reactionLabel: 'mountain',
      baseReactions: 3,
    ),
    _WaMessage(
      id: 'wa-m02',
      sender: 'Marcus',
      text:
          'Starting at Lago di Braies and finishing at Passo Giau '
          'gives us 4 solid stages with zero brutal descents.',
      day: may11,
      time: '09:15',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m03',
      sender: 'You',
      text: 'Love that route. Are we aiming for Biella or Sennes on night 1?',
      day: may11,
      time: '09:18',
      isMe: true,
      delivered: true,
    ),
    _WaMessage(
      id: 'wa-m04',
      sender: 'Elena',
      text: 'Voice note',
      day: may11,
      time: '09:22',
      isMe: false,
      reactionIcon: LucideIcons.headphones,
      reactionLabel: 'audio',
      baseReactions: 1,
      voiceNote: const _WaVoiceNote(
        durationSeconds: 14,
        transcript:
            'Sennes has a much quieter terrace at sunset and only adds '
            'forty minutes past Biella. Tap Transcript anytime — widget '
            'state stays alive even after loading older days.',
      ),
    ),
    _WaMessage(
      id: 'wa-m05',
      sender: 'Priya',
      text: 'Sennes gets my vote! Their strudel is legendary.',
      day: may11,
      time: '09:26',
      isMe: false,
      reactionIcon: LucideIcons.heart,
      reactionLabel: 'love',
      baseReactions: 2,
    ),
    _WaMessage(
      id: 'wa-m06',
      sender: 'Tomas',
      text: 'I can grab Rifugio Fanes for night 2 right now before bunks go.',
      day: may11,
      time: '10:04',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m07',
      sender: 'You',
      text: 'Go for it! Put us down for a 5-bed dorm if they still have one.',
      day: may11,
      time: '10:06',
      isMe: true,
      delivered: true,
    ),
    _WaMessage(
      id: 'wa-m08',
      sender: 'Tomas',
      text: 'Locked in Fanes — 5 bunks confirmed.',
      day: may11,
      time: '10:19',
      isMe: false,
      reactionIcon: LucideIcons.flame,
      reactionLabel: 'fire',
      baseReactions: 4,
    ),

    // --- May 12 (11 messages: quote target wa-m10 & deep link wa-m14) ---
    _WaMessage(
      id: 'wa-m09',
      sender: 'Marcus',
      text: 'Morning! Just got off the phone with Rifugio Lagazuoi.',
      day: may12,
      time: '08:40',
      isMe: false,
    ),
    _WaMessage(
      id: _WhatsAppDemoState._quoteTargetId,
      sender: 'Marcus',
      text:
          'Booked Rifugio Lagazuoi for 5 people — confirmation #LGZ-4819. '
          'Half-board dinner + breakfast included, and the last cable car '
          'runs at 17:00 sharp so we want to clear Passo Falzarego by 16:15.',
      day: may12,
      time: '08:42',
      isMe: false,
      reactionIcon: LucideIcons.sparkles,
      reactionLabel: 'celebrate',
      baseReactions: 4,
    ),
    _WaMessage(
      id: 'wa-m11',
      sender: 'You',
      text: '2,752m sunset views!! Thank you for pulling that off Marcus.',
      day: may12,
      time: '08:45',
      isMe: true,
      delivered: true,
    ),
    _WaMessage(
      id: 'wa-m12',
      sender: 'Elena',
      text: 'Did they ask for sleeping bag liners?',
      day: may12,
      time: '09:02',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m13',
      sender: 'Marcus',
      text: 'Yep — silk liner mandatory at every rifugio, plus hut slippers.',
      day: may12,
      time: '09:04',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m14',
      sender: 'Priya',
      text:
          'Trailhead & Packing Pin (May 12): Lago di Braies trailhead '
          '46.6943° N, 12.0854° E. Bring 2L water, silk liner, rain shell, '
          'headlamp for the Lagazuoi tunnels, and €60 cash for huts.',
      day: may12,
      time: '11:30',
      isMe: false,
      reactionIcon: LucideIcons.pin,
      reactionLabel: 'pinned',
      baseReactions: 5,
    ),
    _WaMessage(
      id: 'wa-m15',
      sender: 'Tomas',
      text: 'Voice note',
      day: may12,
      time: '12:15',
      isMe: false,
      voiceNote: const _WaVoiceNote(
        durationSeconds: 12,
        transcript:
            'If anyone wants to hike down through the WWI Galleria del '
            'Lagazuoi tunnel on day 4, definitely pack a bright headlamp '
            'and light gloves — the cable inside stays icy.',
      ),
    ),
    _WaMessage(
      id: 'wa-m16',
      sender: 'You',
      text: 'Count me in for the tunnel descent, headlamp is already packed.',
      day: may12,
      time: '12:21',
      isMe: true,
      delivered: true,
    ),
    _WaMessage(
      id: 'wa-m17',
      sender: 'Elena',
      text: 'Same! Bringing my spare Petzl just in case.',
      day: may12,
      time: '14:08',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m18',
      sender: 'Priya',
      text:
          'Uploaded the offline GPX tracks for all four stages to the folder.',
      day: may12,
      time: '18:19',
      isMe: false,
      reactionIcon: LucideIcons.map,
      reactionLabel: 'map',
      baseReactions: 3,
    ),
    _WaMessage(
      id: 'wa-m19',
      sender: 'You',
      text: 'Downloaded on watch + phone. Ready to roll.',
      day: may12,
      time: '18:24',
      isMe: true,
      delivered: true,
    ),

    // --- Yesterday (9 messages) ---
    _WaMessage(
      id: 'wa-m20',
      sender: 'Tomas',
      text: 'Train from Venice Mestre to Dobbiaco is booked — departs 08:12.',
      day: yesterday,
      time: '10:05',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m21',
      sender: 'Elena',
      text: 'We can grab focaccia near the station before boarding.',
      day: yesterday,
      time: '10:11',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m22',
      sender: 'Priya',
      text: 'Voice note',
      day: yesterday,
      time: '13:44',
      isMe: false,
      voiceNote: const _WaVoiceNote(
        durationSeconds: 9,
        transcript:
            'Quick tip from a friend who hiked last week: Rifugio Nuvolau '
            'opens for espresso at 07:30 and the balcony looks straight '
            'across Cinque Torri.',
      ),
    ),
    _WaMessage(
      id: 'wa-m23',
      sender: 'You',
      text: 'Espresso at 2,575m sounds unbeatable.',
      day: yesterday,
      time: '13:49',
      isMe: true,
      delivered: true,
    ),
    _WaMessage(
      id: 'wa-m24',
      sender: 'Marcus',
      text: 'Just weighed my pack: 7.4 kg without water. Aiming under 9 kg.',
      day: yesterday,
      time: '17:20',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m25',
      sender: 'Tomas',
      text: 'Impressive. Mine is sitting at 8.1 kg with camera gear.',
      day: yesterday,
      time: '17:24',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m26',
      sender: 'Elena',
      text: 'Leaving the extra fleece behind — forecasts look mild at night.',
      day: yesterday,
      time: '19:02',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m27',
      sender: 'Priya',
      text: 'Keep a light puffy though, Lagazuoi drops to 2°C after sunset.',
      day: yesterday,
      time: '19:07',
      isMe: false,
      reactionIcon: LucideIcons.heart,
      reactionLabel: 'love',
      baseReactions: 2,
    ),
    _WaMessage(
      id: 'wa-m28',
      sender: 'You',
      text: 'Good call — puffy stays in the dry bag.',
      day: yesterday,
      time: '19:14',
      isMe: true,
      delivered: true,
    ),

    // --- Today (8 messages — voice note + hero quote jump near bottom!) ---
    _WaMessage(
      id: 'wa-m29',
      sender: 'Marcus',
      text:
          'Final alpine weather check: crisp mornings, zero afternoon storms.',
      day: today,
      time: '09:30',
      isMe: false,
      reactionIcon: LucideIcons.sun,
      reactionLabel: 'sunny',
      baseReactions: 4,
    ),
    _WaMessage(
      id: 'wa-m30',
      sender: 'Priya',
      text: 'Checked in for the flight! Seat 14A.',
      day: today,
      time: '11:04',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m31',
      sender: 'Tomas',
      text: 'Just picked up electrolyte tabs and blister tape for the group.',
      day: today,
      time: '12:18',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m32',
      sender: 'You',
      text: 'Legend. I brought a mini first-aid kit and spare shoelaces.',
      day: today,
      time: '12:25',
      isMe: true,
      delivered: true,
    ),
    _WaMessage(
      id: 'wa-m33',
      sender: 'Priya',
      text: 'Voice note',
      day: today,
      time: '14:10',
      isMe: false,
      voiceNote: const _WaVoiceNote(
        durationSeconds: 10,
        transcript:
            'Try expanding this transcript or pressing play, then tap '
            'Load older above — scroll stays locked at 0.0px shift and '
            'this widget State survives.',
      ),
    ),
    _WaMessage(
      id: 'wa-m34',
      sender: 'Tomas',
      text: 'Meet at Platform 4 by 07:55 sharp tomorrow morning!',
      day: today,
      time: '15:18',
      isMe: false,
    ),
    _WaMessage(
      id: 'wa-m35',
      sender: 'Elena',
      text:
          'Wait — did our Lagazuoi booking include half-board dinner '
          'or just bunks?',
      day: today,
      time: '15:36',
      isMe: false,
      quoted: const _WaQuote(
        id: _WhatsAppDemoState._quoteTargetId,
        sender: 'Marcus',
        preview:
            'Booked Rifugio Lagazuoi for 5 people — confirmation '
            '#LGZ-4819. Half-board dinner + breakfast included…',
      ),
      quoteCardKey: const Key('whatsapp.quote_jump'),
    ),
    _WaMessage(
      id: 'wa-m36',
      sender: 'You',
      text:
          'Tap Marcus’s quoted booking above — it springs straight '
          'back to May 12!',
      day: today,
      time: '15:38',
      isMe: true,
      delivered: true,
    ),
  ];
}

List<List<_WaMessage>> _buildOlderPages() {
  return [
    // Page 1 (closest older: Jan 1 – Jan 9, 2025; 50 messages)
    _generateArchiveRange(
      idPrefix: 'wa-p1-',
      startNumber: 1,
      count: 50,
      startDay: DateTime(2025),
      daySpan: 9,
    ),
    // Page 2 (Dec 20 – Dec 31, 2024; 50 messages)
    _generateArchiveRange(
      idPrefix: 'wa-p2-',
      startNumber: 51,
      count: 50,
      startDay: DateTime(2024, 12, 20),
      daySpan: 12,
    ),
    // Page 3 (earliest: Dec 8 – Dec 19, 2024; 50 messages)
    _generateArchiveRange(
      idPrefix: 'wa-p3-',
      startNumber: 101,
      count: 50,
      startDay: DateTime(2024, 12, 8),
      daySpan: 12,
    ),
  ];
}
