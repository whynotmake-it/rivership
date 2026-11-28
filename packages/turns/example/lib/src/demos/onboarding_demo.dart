import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turns/turns.dart';
import 'package:turns_example/src/shell/turns_action_strip.dart';

/// A three-step onboarding built as one [CustomTurnScrollView], where each
/// step is a different kind of sliver: a collapsing hero
/// ([SliverPersistentHeader]), sticky step headers in [SliverMainAxisGroup]s,
/// a [SliverGrid], a sideways carousel, a [SliverList], and a chat
/// ([SliverTurnList] with a [SliverTurnStage] for the pinned prompt).
///
/// "Show slivers" outlines and names each one.
class OnboardingDemo extends StatefulWidget {
  const OnboardingDemo({super.key});

  @override
  State<OnboardingDemo> createState() => _OnboardingDemoState();
}

@immutable
class _Goal {
  const _Goal(this.id, this.title, this.icon);

  final String id;
  final String title;
  final IconData icon;
}

const _goals = [
  _Goal('assistant', 'AI assistant', LucideIcons.sparkles),
  _Goal('team', 'Team chat', LucideIcons.hash),
  _Goal('support', 'Support inbox', LucideIcons.lifeBuoy),
  _Goal('community', 'Community', LucideIcons.users),
];

const _accents = <(String, Color)>[
  ('Blue', Color(0xFF2563EB)),
  ('Violet', Color(0xFF7C3AED)),
  ('Green', Color(0xFF059669)),
  ('Coral', Color(0xFFE5484D)),
  ('Amber', Color(0xFFD97706)),
  ('Slate', Color(0xFF475569)),
];

const _preferences = [
  ('typing', 'Typing indicators'),
  ('sounds', 'Sounds for new messages'),
  ('digest', 'Daily digest email'),
];

const _suggestions = [
  ("What's next?", 'Invite your team, then send your first message.'),
  ('Invite my team', 'Share relay.app/join/7KQ. They land right here.'),
  ('Finish', 'All set. Welcome to Relay!'),
];

@immutable
class _Message {
  const _Message({
    required this.id,
    required this.mine,
    required this.text,
    this.streaming = false,
  });

  final String id;
  final bool mine;
  final String text;
  final bool streaming;
}

class _OnboardingDemoState extends State<OnboardingDemo> {
  static const _heroMax = 168.0;
  static const _heroMin = 64.0;
  static const _stepHeader = 48.0;

  final _controller = TurnScrollController();
  final _sectionKeys = [GlobalKey(), GlobalKey(), GlobalKey()];

  var _step = 0;
  var _xray = false;
  final _picked = <String>{'assistant'};
  var _accent = 1;
  final _prefs = <String>{'typing'};

  var _messages = <_Message>[];
  String? _pinnedId;
  Timer? _stream;
  var _turn = 0;
  double _bottomBarHeight = 96;

  @override
  void dispose() {
    _stream?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    final next = _step + 1;
    setState(() => _step = next);
    if (next == 2 && _messages.isEmpty) {
      final goal = _goals.firstWhere(
        (g) => _picked.contains(g.id),
        orElse: () => _goals.first,
      );
      _reply(
        'Hi! A ${goal.title.toLowerCase()} in ${_accents[_accent].$1}, '
        'nice. Ask me anything.',
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(next));
  }

  /// Scrolls step [index]'s header to just under the collapsed hero.
  void _reveal(int index) {
    final box = _sectionKeys[index].currentContext?.findRenderObject();
    if (box == null || !_controller.hasClients) return;
    final viewport = RenderAbstractViewport.of(box);
    final pos = _controller.position;
    final target = (viewport.getOffsetToReveal(box, 0).offset - _heroMin).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    unawaited(
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final canned = _suggestions.where((s) => s.$1 == trimmed).firstOrNull;
    final id = 'me-${_turn++}';
    setState(() {
      _messages = [..._messages, _Message(id: id, mine: true, text: trimmed)];
      _pinnedId = id;
    });
    _reply(canned?.$2 ?? "Got it, I'll set that up. Anything else?");
  }

  /// Streams [text] in as the assistant's next message.
  void _reply(String text) {
    _stream?.cancel();
    final id = 'bot-${_turn++}';
    setState(() {
      _messages = [
        ..._messages,
        _Message(id: id, mine: false, text: '', streaming: true),
      ];
    });
    var cursor = 0;
    _stream = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      if (!mounted) return timer.cancel();
      cursor = math.min(text.length, cursor + 3);
      final done = cursor >= text.length;
      setState(() {
        _messages = [
          for (final m in _messages)
            if (m.id == id)
              _Message(
                id: id,
                mine: false,
                text: text.substring(0, cursor),
                streaming: !done,
              )
            else
              m,
        ];
      });
      if (done) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CoilTheme.override(
      transform: (theme) => theme.copyWith(
        colors: CoilColors.fromSeed(
          brightness: theme.brightness,
          brand: _accents[_accent].$2,
        ),
      ),
      child: Builder(builder: _buildPage),
    );
  }

  Widget _buildPage(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return ColoredBox(
      color: colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = math.max<double>(16, (constraints.maxWidth - 640) / 2);
          return Stack(
            children: [
              CoilScrollArea(
                controller: _controller,
                edgeFades: CoilEdgeFades.none,
                keyboard: false,
                child: CustomTurnScrollView(
                  controller: _controller,
                  pinnedId: _pinnedId,
                  initialAtBottom: false,
                  applyTopPadding: false,
                  applyBottomPadding: false,
                  // Pinned prompts clear the collapsed hero and the chat's
                  // sticky step header.
                  padding: EdgeInsets.only(
                    top: _heroMin + _stepHeader + 8,
                    bottom: _bottomBarHeight + 16,
                  ),
                  slivers: _slivers(context, gutter),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _MeasureHeight(
                  onHeight: (h) {
                    if ((h - _bottomBarHeight).abs() > 0.5) {
                      setState(() => _bottomBarHeight = h);
                    }
                  },
                  child: _BottomBar(
                    gutter: gutter,
                    step: _step,
                    canContinue: _step != 0 || _picked.isNotEmpty,
                    onContinue: _continue,
                    onSend: _send,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _slivers(BuildContext context, double gutter) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final pad = EdgeInsets.symmetric(horizontal: gutter);

    Widget section({
      required int index,
      required String title,
      required List<Widget> slivers,
    }) => SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(key: _sectionKeys[index], height: 12),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StepHeaderDelegate(
            number: index + 1,
            title: title,
            done: _step > index,
            active: _step == index,
            gutter: gutter,
            xray: _xray,
            colors: colors,
            text: text,
          ),
        ),
        ...slivers,
      ],
    );

    final pinIndex = _pinnedId == null
        ? -1
        : _messages.indexWhere((m) => m.id == _pinnedId);

    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: _HeroDelegate(
          minExtent: _heroMin,
          maxExtent: _heroMax,
          step: _step,
          xray: _xray,
          gutter: gutter,
          colors: colors,
          text: text,
          onXray: () => setState(() => _xray = !_xray),
        ),
      ),
      section(
        index: 0,
        title: 'What are you building?',
        slivers: [
          _Xray(
            enabled: _xray,
            label: 'SliverGrid',
            sliver: SliverPadding(
              padding: pad.copyWith(top: 12, bottom: 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent:
                      MediaQuery.textScalerOf(context).scale(16) + 72,
                ),
                delegate: SliverChildBuilderDelegate(
                  childCount: _goals.length,
                  (context, i) {
                    final goal = _goals[i];
                    return _GoalCard(
                      key: Key('onboarding.goal.${goal.id}'),
                      goal: goal,
                      selected: _picked.contains(goal.id),
                      onTap: () => setState(() {
                        if (!_picked.remove(goal.id)) _picked.add(goal.id);
                      }),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      section(
        index: 1,
        title: 'Make it yours',
        slivers: [
          _Xray(
            enabled: _xray,
            label: 'SliverToBoxAdapter · sideways ListView',
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 92,
                child: CoilScrollEdgeFade(
                  axis: Axis.horizontal,
                  extent: 24,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: pad.copyWith(top: 12, bottom: 8),
                    itemCount: _accents.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => _Swatch(
                      label: _accents[i].$1,
                      color: _accents[i].$2,
                      selected: i == _accent,
                      onTap: () => setState(() => _accent = i),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _Xray(
            enabled: _xray,
            label: 'SliverList',
            sliver: SliverPadding(
              padding: pad.copyWith(bottom: 8),
              sliver: SliverList.separated(
                itemCount: _preferences.length,
                separatorBuilder: (_, _) => SizedBox(
                  height: 1,
                  child: ColoredBox(color: colors.border),
                ),
                itemBuilder: (context, i) {
                  final (id, label) = _preferences[i];
                  return _PreferenceRow(
                    label: label,
                    value: _prefs.contains(id),
                    onChanged: (on) => setState(
                      () => on ? _prefs.add(id) : _prefs.remove(id),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      section(
        index: 2,
        title: 'Say hi',
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_messages.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: pad.copyWith(top: 8, bottom: 24),
                child: Text(
                  'Your assistant joins here.',
                  style: text.muted.caption,
                ),
              ),
            )
          else if (pinIndex < 0)
            _Xray(
              enabled: _xray,
              label: 'SliverTurnList',
              sliver: SliverPadding(
                padding: pad,
                sliver: _list(0, _messages.length),
              ),
            )
          else ...[
            if (pinIndex > 0)
              _Xray(
                enabled: _xray,
                label: 'SliverTurnList',
                sliver: SliverPadding(
                  padding: pad.copyWith(bottom: 12),
                  sliver: _list(0, pinIndex),
                ),
              ),
            _Xray(
              enabled: _xray,
              // Its start scrolls under the sticky headers, so the tag rides
              // on the pinned prompt instead.
              label: null,
              sliver: SliverTurnStage(
                anchorSliver: SliverPadding(
                  padding: pad,
                  sliver: SliverToBoxAdapter(
                    child: TurnScrollItem(
                      id: _messages[pinIndex].id,
                      child: Stack(
                        children: [
                          _bubble(_messages[pinIndex]),
                          if (_xray)
                            const PositionedDirectional(
                              start: 0,
                              top: 0,
                              child: _XrayTag(
                                'SliverTurnStage · pinned prompt, room below '
                                'for the reply',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                afterSliver: SliverPadding(
                  padding: pad.copyWith(top: 12),
                  sliver: _list(pinIndex + 1, _messages.length),
                ),
              ),
            ),
          ],
        ],
      ),
    ];
  }

  Widget _list(int from, int to) => SliverTurnList(
    itemCount: to - from,
    itemId: (i) => _messages[from + i].id,
    itemSpacing: 12,
    itemBuilder: (context, i) => _bubble(_messages[from + i]),
  );

  Widget _bubble(_Message message) => CoilChatMessage(
    key: ValueKey(message.id),
    sender: message.mine ? CoilChatSender.user : CoilChatSender.assistant,
    child: message.mine
        ? Text(message.text)
        : CoilMarkdown(message.text, streaming: message.streaming),
  );
}

/// Outlines [sliver] and names it while the x-ray is on.
class _Xray extends StatelessWidget {
  const _Xray({
    required this.enabled,
    required this.label,
    required this.sliver,
  });

  final bool enabled;

  /// The tag above the sliver; null outlines it without one.
  final String? label;
  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return sliver;
    final colors = CoilTheme.of(context).colors;
    final label = this.label;
    return DecoratedSliver(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: colors.brandMark, width: 1.5),
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          if (label != null)
            SliverToBoxAdapter(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _XrayTag(label),
              ),
            ),
          sliver,
        ],
      ),
    );
  }
}

class _XrayTag extends StatelessWidget {
  const _XrayTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.brandMark),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: text.micro.copyWith(
            color: colors.onBrandFill,
            fontWeight: text.emphasis,
          ),
        ),
      ),
    );
  }
}

class _HeroDelegate extends SliverPersistentHeaderDelegate {
  const _HeroDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.step,
    required this.xray,
    required this.gutter,
    required this.colors,
    required this.text,
    required this.onXray,
  });

  @override
  final double minExtent;

  @override
  final double maxExtent;

  final int step;
  final bool xray;
  final double gutter;
  final CoilColors colors;
  final CoilTextTheme text;
  final VoidCallback onXray;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final big = (1 - t * 1.8).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(colors.brandWash, colors.surfaces[1], t),
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: colors.border.a * t),
          ),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: gutter,
            right: gutter,
            top: 0,
            height: minExtent,
            child: Row(
              children: [
                Icon(
                  LucideIcons.messagesSquare,
                  size: 18,
                  color: colors.brandInk,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Opacity(
                    opacity: 1 - big,
                    child: Text(
                      'Relay setup',
                      style: text.body.copyWith(fontWeight: text.emphasis),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                CoilButton(
                  key: const Key('onboarding.xray'),
                  variant: xray
                      ? CoilButtonVariant.secondary
                      : CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  selected: xray,
                  leading: const Icon(LucideIcons.scanEye, size: 14),
                  onPressed: onXray,
                  child: Text(xray ? 'Hide slivers' : 'Show slivers'),
                ),
              ],
            ),
          ),
          Positioned(
            left: gutter,
            right: gutter,
            bottom: 18,
            child: Opacity(
              opacity: big,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome to Relay', style: text.display),
                  const SizedBox(height: 2),
                  Text('Three quick steps.', style: text.muted.body),
                ],
              ),
            ),
          ),
          if (xray)
            const Positioned(
              right: 0,
              bottom: 0,
              child: _XrayTag('SliverPersistentHeader · pinned, collapses'),
            ),
          if (xray)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.brandMark, width: 1.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_HeroDelegate old) =>
      old.step != step ||
      old.xray != xray ||
      old.gutter != gutter ||
      old.colors != colors ||
      old.text != text ||
      old.minExtent != minExtent ||
      old.maxExtent != maxExtent;
}

class _StepHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StepHeaderDelegate({
    required this.number,
    required this.title,
    required this.done,
    required this.active,
    required this.gutter,
    required this.xray,
    required this.colors,
    required this.text,
  });

  final int number;
  final String title;
  final bool done;
  final bool active;
  final double gutter;
  final bool xray;
  final CoilColors colors;
  final CoilTextTheme text;

  @override
  double get minExtent => _OnboardingDemoState._stepHeader;

  @override
  double get maxExtent => _OnboardingDemoState._stepHeader;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final badgeFill = done || active ? colors.brandFill : colors.muted;
    final badgeInk = done || active
        ? colors.onBrandFill
        : colors.mutedForeground;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent ? colors.border : const Color(0x00000000),
          ),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: badgeFill,
                    shape: const CircleBorder(),
                  ),
                  child: SizedBox.square(
                    dimension: 22,
                    child: Center(
                      child: done
                          ? Icon(LucideIcons.check, size: 13, color: badgeInk)
                          : Text(
                              '$number',
                              style: text.micro.copyWith(
                                color: badgeInk,
                                fontWeight: text.emphasis,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: text.body.copyWith(fontWeight: text.emphasis),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (xray) ...[
            const Positioned(
              right: 0,
              bottom: 0,
              child: _XrayTag('SliverPersistentHeader · sticky in its group'),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.brandMark, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StepHeaderDelegate old) =>
      old.number != number ||
      old.title != title ||
      old.done != done ||
      old.active != active ||
      old.gutter != gutter ||
      old.xray != xray ||
      old.colors != colors ||
      old.text != text;
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _Goal goal;
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
      label: goal.title,
      child: CoilInteraction(
        onPressed: onTap,
        excludeFromSemantics: true,
        builder: (context, states, child) => CoilFocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: radius,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: selected
                  ? Color.lerp(colors.surfaces[1], colors.brandWash, 0.6)
                  : states.contains(WidgetState.hovered)
                  ? colors.hover
                  : colors.surfaces[1],
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: BorderSide(
                  color: selected ? colors.brandMark : colors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
            ),
            child: child,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    goal.icon,
                    size: 20,
                    color: selected ? colors.brandInk : colors.mutedForeground,
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(
                      LucideIcons.circleCheck,
                      size: 16,
                      color: colors.brandInk,
                    ),
                ],
              ),
              Text(
                goal.title,
                style: text.body.copyWith(fontWeight: text.emphasis),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label accent',
      child: CoilInteraction(
        onPressed: onTap,
        excludeFromSemantics: true,
        builder: (context, states, child) => child!,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: ShapeDecoration(
                shape: CircleBorder(
                  side: BorderSide(
                    color: selected
                        ? colors.foreground
                        : const Color(0x00000000),
                    width: 2,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: color,
                    shape: const CircleBorder(),
                  ),
                  child: const SizedBox.square(dimension: 34),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: selected
                  ? text.micro.copyWith(fontWeight: text.emphasis)
                  : text.muted.micro,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.body)),
          CoilSwitch(value: value, onChanged: onChanged, semanticLabel: label),
        ],
      ),
    );
  }
}

/// "Continue" through the first two steps, then the composer with a few
/// suggestions.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.gutter,
    required this.step,
    required this.canContinue,
    required this.onContinue,
    required this.onSend,
  });

  final double gutter;
  final int step;
  final bool canContinue;
  final VoidCallback onContinue;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final chatting = step >= 2;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: chatting
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TurnsActionStrip(
                    padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 8),
                    children: [
                      for (final (prompt, _) in _suggestions)
                        CoilButton(
                          variant: CoilButtonVariant.secondary,
                          size: CoilSize.compact,
                          style: const CoilButtonStyle(radius: 999),
                          onPressed: () => onSend(prompt),
                          child: Text(prompt),
                        ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    child: CoilInputMessage(
                      placeholder: const Text('Message your assistant'),
                      onSend: onSend,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Step ${step + 1} of 3',
                        style: text.muted.caption.tabular,
                      ),
                    ),
                    CoilButton(
                      key: const Key('onboarding.continue'),
                      trailing: const Icon(LucideIcons.arrowRight, size: 14),
                      onPressed: canContinue ? onContinue : null,
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  _RenderMeasureHeight createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_last == null || (height - _last!).abs() > 0.5) {
      _last = height;
      WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
    }
  }
}
