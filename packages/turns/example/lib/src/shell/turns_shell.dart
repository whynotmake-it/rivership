import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';
import 'package:turns_example/src/shell/turns_environment.dart';

/// Route names for the turns gallery, prefixed to avoid collisions when
/// mounted inside the aggregate example app.
const turnsShellRouteName = 'turns:shell';
const turnsOverviewRouteName = 'turns:overview';
const turnsAiRouteName = 'turns:ai';
const turnsWhatsAppRouteName = 'turns:whatsapp';
const turnsSlackRouteName = 'turns:slack';
const turnsIMessageRouteName = 'turns:imessage';
const turnsOnboardingRouteName = 'turns:onboarding';
const turnsPinningRouteName = 'turns:concept-pinning';
const turnsPrependRouteName = 'turns:concept-prepend';
const turnsPaginationRouteName = 'turns:concept-pagination';
const turnsJumpsRouteName = 'turns:concept-jumps';
const turnsStreamingRouteName = 'turns:concept-streaming';

/// A Lucide glyph paired across stroke weights so Coil controls can emphasize
/// icons on hover and selection while remaining tree-shakeable.
@immutable
class TurnsGlyph {
  const TurnsGlyph(this.rest, this.emphasis);

  final IconData rest;
  final IconData emphasis;

  static const home = TurnsGlyph(LucideIcons300.house, LucideIcons400.house);
  static const panelLeft = TurnsGlyph(
    LucideIcons300.panelLeft,
    LucideIcons400.panelLeft,
  );
  static const sparkles = TurnsGlyph(
    LucideIcons300.sparkles,
    LucideIcons400.sparkles,
  );
  static const messagesSquare = TurnsGlyph(
    LucideIcons300.messagesSquare,
    LucideIcons400.messagesSquare,
  );
  static const hash = TurnsGlyph(LucideIcons300.hash, LucideIcons400.hash);
  static const messageCircle = TurnsGlyph(
    LucideIcons300.messageCircle,
    LucideIcons400.messageCircle,
  );
  static const compass = TurnsGlyph(
    LucideIcons300.compass,
    LucideIcons400.compass,
  );
  static const sun = TurnsGlyph(LucideIcons300.sun, LucideIcons400.sun);
  static const moon = TurnsGlyph(LucideIcons300.moon, LucideIcons400.moon);
  static const smartphone = TurnsGlyph(
    LucideIcons300.smartphone,
    LucideIcons400.smartphone,
  );
  static const monitor = TurnsGlyph(
    LucideIcons300.monitor,
    LucideIcons400.monitor,
  );
  static const arrowUpToLine = TurnsGlyph(
    LucideIcons300.arrowUpToLine,
    LucideIcons400.arrowUpToLine,
  );
  static const layers = TurnsGlyph(
    LucideIcons300.layers,
    LucideIcons400.layers,
  );
  static const zap = TurnsGlyph(LucideIcons300.zap, LucideIcons400.zap);
  static const pin = TurnsGlyph(LucideIcons300.pin, LucideIcons400.pin);
  static const textCursor = TurnsGlyph(
    LucideIcons300.textCursorInput,
    LucideIcons400.textCursorInput,
  );
}

/// Renders a [TurnsGlyph] matching the ambient [IconTheme]'s weight.
class TurnsGlyphIcon extends StatelessWidget {
  const TurnsGlyphIcon(
    this.glyph, {
    super.key,
    this.size,
    this.semanticLabel,
  });

  final TurnsGlyph glyph;
  final double? size;
  final String? semanticLabel;

  static const _emphasisFrom = 466.0;

  @override
  Widget build(BuildContext context) {
    final weight = IconTheme.of(context).weight ?? 400;
    return Icon(
      weight >= _emphasisFrom ? glyph.emphasis : glyph.rest,
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}

/// Metadata for one interactive demo in the turns gallery.
@immutable
class TurnsDemoEntry {
  const TurnsDemoEntry({
    required this.routeName,
    required this.path,
    required this.title,
    required this.primitive,
    required this.description,
    required this.glyph,
  });

  final String routeName;
  final String path;
  final String title;
  final String primitive;
  final String description;
  final TurnsGlyph glyph;
}

/// All interactive demos shown in the sidebar and overview page.
const turnsDemos = <TurnsDemoEntry>[
  TurnsDemoEntry(
    routeName: turnsAiRouteName,
    path: '',
    title: 'AI Assistant',
    primitive: 'TurnScrollView + SliverTurnStage',
    description:
        'Pins newly sent prompts to the top of a viewport stage while '
        'streaming multi-block GFM markdown without layout jumps.',
    glyph: TurnsGlyph.sparkles,
  ),
  TurnsDemoEntry(
    routeName: turnsWhatsAppRouteName,
    path: 'whatsapp',
    title: 'WhatsApp',
    primitive: 'TurnScrollView.sectioned',
    description:
        'Bidirectional O(1) timeline opening at message #3,421 with floating '
        'sticky date pills, jump-to-reply, and prepend pagination.',
    glyph: TurnsGlyph.messagesSquare,
  ),
  TurnsDemoEntry(
    routeName: turnsSlackRouteName,
    path: 'slack',
    title: 'Slack',
    primitive: 'TurnScrollView.sectioned (3,000 msgs)',
    description:
        '3,000-message O(1) channel with inline date dividers vs transparent '
        'floating pinned pills via isPinned, 0px-shift prepend pagination, and '
        'unread divider jumps.',
    glyph: TurnsGlyph.hash,
  ),
  TurnsDemoEntry(
    routeName: turnsIMessageRouteName,
    path: 'imessage',
    title: 'iMessage',
    primitive: 'TurnScrollView.sectioned (inline)',
    description:
        'Find in conversation across two years of history: pages in the '
        'whole archive with a 0px-shift prepend, then steps through matches '
        'months apart with scrollTo. Inline timestamps and a typing tail.',
    glyph: TurnsGlyph.messageCircle,
  ),
  TurnsDemoEntry(
    routeName: turnsOnboardingRouteName,
    path: 'onboarding',
    title: 'Onboarding',
    primitive: 'CustomTurnScrollView',
    description:
        'Three steps in one scroll view, each a different sliver: a '
        'collapsing hero, sticky step headers, a grid, a carousel, a list '
        'and a chat. "Show slivers" outlines them.',
    glyph: TurnsGlyph.compass,
  ),
];

/// Concept pages: one idea each, drawn live, like motor's chapters.
const turnsConcepts = <TurnsDemoEntry>[
  TurnsDemoEntry(
    routeName: turnsPinningRouteName,
    path: 'concepts/pinning',
    title: 'Pinning a turn',
    primitive: 'SliverTurnStage',
    description:
        'Scrub a reply as it grows under a pinned prompt, with the whole '
        'scroll extent and the reserved space drawn to scale.',
    glyph: TurnsGlyph.pin,
  ),
  TurnsDemoEntry(
    routeName: turnsPrependRouteName,
    path: 'concepts/prepend',
    title: 'Prepend without a jump',
    primitive: 'Viewport(center:)',
    description:
        'Load older messages into a ListView and a TurnScrollView side by '
        'side, and watch what you were reading.',
    glyph: TurnsGlyph.arrowUpToLine,
  ),
  TurnsDemoEntry(
    routeName: turnsPaginationRouteName,
    path: 'concepts/pagination',
    title: 'Paginated history',
    primitive: 'TurnScrollNotification',
    description:
        'Open in the middle of 400 messages and page in both directions, '
        'with the loaded range drawn beside the chat.',
    glyph: TurnsGlyph.layers,
  ),
  TurnsDemoEntry(
    routeName: turnsJumpsRouteName,
    path: 'concepts/jumps',
    title: 'Long jumps',
    primitive: 'scrollTo · scrollToBottom',
    description:
        'Jump across 10,000 messages and count the rows each jump builds.',
    glyph: TurnsGlyph.zap,
  ),
  TurnsDemoEntry(
    routeName: turnsStreamingRouteName,
    path: 'concepts/streaming-markdown',
    title: 'Streaming markdown',
    primitive: 'MarkdownSession',
    description:
        'See which blocks freeze and which tail is parsed again on every '
        'token, and how completeMarkdown repairs it.',
    glyph: TurnsGlyph.textCursor,
  ),
];

/// Navigates to [routeName] inside the gallery shell without stacking pages.
Future<void> openTurnsRoute(StackRouter router, String routeName) async {
  final stack = router.stackData;
  if (stack.length == 1 && stack.single.name == routeName) return;
  await router.replaceAll([NamedRoute(routeName)]);
}

/// The turns gallery shell: Coil theme environment, sidebar navigation,
/// top chrome bar with theme/viewport controls, and the active demo.
class TurnsShell extends StatefulWidget {
  const TurnsShell({super.key, this.onHome});

  /// Leads back to the aggregate rivership app when mounted inside it.
  /// Null leaves the sidebar brand header inert.
  final VoidCallback? onHome;

  @override
  State<TurnsShell> createState() => _TurnsShellState();
}

class _TurnsShellState extends State<TurnsShell> {
  Brightness? _brightnessOverride;
  var _mobileFrame = false;

  void _toggleBrightness(Brightness current) {
    setState(() {
      _brightnessOverride = current == Brightness.dark
          ? Brightness.light
          : Brightness.dark;
    });
  }

  void _toggleMobileFrame() {
    setState(() => _mobileFrame = !_mobileFrame);
  }

  @override
  Widget build(BuildContext context) => TurnsEnvironment(
    brightnessOverride: _brightnessOverride,
    child: AutoRouter(
      builder: (context, navigator) => _TurnsNavigation(
        router: AutoRouter.of(context),
        onHome: widget.onHome,
        mobileFrame: _mobileFrame,
        onToggleMobileFrame: _toggleMobileFrame,
        onToggleBrightness: () =>
            _toggleBrightness(CoilTheme.of(context).brightness),
        child: navigator,
      ),
    ),
  );
}

class _TurnsNavigation extends StatefulWidget {
  const _TurnsNavigation({
    required this.router,
    required this.child,
    required this.mobileFrame,
    required this.onToggleMobileFrame,
    required this.onToggleBrightness,
    this.onHome,
  });

  final StackRouter router;
  final Widget child;
  final VoidCallback? onHome;
  final bool mobileFrame;
  final VoidCallback onToggleMobileFrame;
  final VoidCallback onToggleBrightness;

  @override
  State<_TurnsNavigation> createState() => _TurnsNavigationState();
}

class _TurnsNavigationState extends State<_TurnsNavigation> {
  final _sidebar = CoilSidebarController(width: 244);
  final _bodyKey = GlobalKey(debugLabel: 'TurnsShell.body');

  @override
  void dispose() {
    _sidebar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.router,
    builder: (context, _) {
      final current =
          widget.router.stackData.lastOrNull?.name ?? turnsAiRouteName;
      return CoilSidebarScaffold(
        controller: _sidebar,
        sidebar: _sidebarFor(context, current),
        body: _bodyFor(context, current),
      );
    },
  );

  Widget _sidebarFor(BuildContext context, String current) => CoilSidebar(
    semanticLabel: 'Turns examples',
    header: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Brand(onHome: widget.onHome),
        const SizedBox(height: 8),
        CoilSidebarMenu(
          items: [
            CoilSidebarItem(
              label: const Text('Overview'),
              leading: const TurnsGlyphIcon(TurnsGlyph.home),
              selected: current == turnsOverviewRouteName,
              onPressed: () => unawaited(
                openTurnsRoute(widget.router, turnsOverviewRouteName),
              ),
            ),
          ],
        ),
      ],
    ),
    children: [
      CoilSidebarGroup(
        label: const Text('Concepts'),
        child: CoilSidebarMenu(
          items: [
            for (final concept in turnsConcepts)
              CoilSidebarItem(
                label: Text(concept.title),
                leading: TurnsGlyphIcon(concept.glyph),
                selected: concept.routeName == current,
                onPressed: () => unawaited(
                  openTurnsRoute(widget.router, concept.routeName),
                ),
              ),
          ],
        ),
      ),
      CoilSidebarGroup(
        label: const Text('Demos'),
        child: CoilSidebarMenu(
          items: [
            for (final demo in turnsDemos)
              CoilSidebarItem(
                label: Text(demo.title),
                leading: TurnsGlyphIcon(demo.glyph),
                selected: demo.routeName == current,
                onPressed: () =>
                    unawaited(openTurnsRoute(widget.router, demo.routeName)),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _bodyFor(BuildContext context, String current) {
    final demo = [
      ...turnsDemos,
      ...turnsConcepts,
    ].where((d) => d.routeName == current).firstOrNull;
    final title = demo?.title ?? 'Overview';
    final primitive = demo?.primitive;
    final isOverview = current == turnsOverviewRouteName;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canFrame = !isOverview && constraints.maxWidth >= 560;
        final framed = canFrame && widget.mobileFrame;
        final colors = CoilTheme.of(context).colors;
        final body = KeyedSubtree(key: _bodyKey, child: widget.child);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ShellTopBar(
              title: title,
              primitive: constraints.maxWidth >= 520 ? primitive : null,
              showViewportToggle: canFrame,
              mobileFrame: widget.mobileFrame,
              onToggleMobileFrame: widget.onToggleMobileFrame,
              onToggleBrightness: widget.onToggleBrightness,
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: framed
                    ? _PhonePreviewFrame(background: colors.muted, child: body)
                    : body,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar({
    required this.title,
    required this.showViewportToggle,
    required this.mobileFrame,
    required this.onToggleMobileFrame,
    required this.onToggleBrightness,
    this.primitive,
  });

  final String title;
  final String? primitive;
  final bool showViewportToggle;
  final bool mobileFrame;
  final VoidCallback onToggleMobileFrame;
  final VoidCallback onToggleBrightness;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final text = CoilTheme.textOf(context);
    final padding = MediaQuery.paddingOf(context);
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          8 + padding.left,
          padding.top + 6,
          10 + padding.right,
          6,
        ),
        child: Row(
          children: [
            const CoilSidebarTrigger(
              icon: TurnsGlyphIcon(TurnsGlyph.panelLeft),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.body.copyWith(fontWeight: text.emphasis),
                      ),
                    ),
                  ),
                  if (primitive case final primitive?) ...[
                    const SizedBox(width: 10),
                    CoilBadge(
                      size: CoilSize.compact,
                      child: Text(primitive),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showViewportToggle) ...[
              CoilTooltip(
                message: Text(
                  mobileFrame ? 'Full width' : 'Phone width (412 px)',
                ),
                child: CoilButton.icon(
                  key: const Key('turns.toggle_viewport'),
                  variant: CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  selected: mobileFrame,
                  semanticLabel: mobileFrame
                      ? 'Switch to full width'
                      : 'Switch to phone preview width',
                  icon: TurnsGlyphIcon(
                    mobileFrame ? TurnsGlyph.monitor : TurnsGlyph.smartphone,
                  ),
                  onPressed: onToggleMobileFrame,
                ),
              ),
              const SizedBox(width: 4),
            ],
            CoilTooltip(
              message: Text(dark ? 'Light theme' : 'Dark theme'),
              child: CoilButton.icon(
                key: const Key('turns.toggle_brightness'),
                variant: CoilButtonVariant.ghost,
                size: CoilSize.compact,
                semanticLabel: dark
                    ? 'Switch to light theme'
                    : 'Switch to dark theme',
                icon: TurnsGlyphIcon(dark ? TurnsGlyph.sun : TurnsGlyph.moon),
                onPressed: onToggleBrightness,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhonePreviewFrame extends StatelessWidget {
  const _PhonePreviewFrame({required this.background, required this.child});

  final Color background;
  final Widget child;

  static const _phoneWidth = 412.0;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    return ColoredBox(
      color: background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: SizedBox(
            width: _phoneWidth,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(color: colors.border),
                ),
              ),
              child: ClipRSuperellipse(
                borderRadius: radius,
                child: CoilAdaptiveScope(tier: CoilTier.touch, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The logo, "turns", and version badge at the top of the sidebar.
///
/// With [onHome], links back to the aggregate rivership overview with Coil's
/// hover, active, and focus states; without it, renders inert.
class _Brand extends StatelessWidget {
  const _Brand({this.onHome});

  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final metrics = CoilTheme.metricsOf(context);
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).item);
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.controlHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: metrics.itemPaddingX,
        ),
        child: Row(
          children: [
            TurnsLogo(size: metrics.iconSize + 4),
            SizedBox(width: metrics.gap),
            Flexible(
              child: Text(
                'turns',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.title,
              ),
            ),
            const SizedBox(width: 8),
            const CoilBadge(child: Text('0.1')),
          ],
        ),
      ),
    );
    final onHome = this.onHome;
    if (onHome == null) {
      return Semantics(label: 'turns 0.1', excludeSemantics: true, child: row);
    }
    return Semantics(
      button: true,
      label: 'Back to all packages',
      onTap: onHome,
      excludeSemantics: true,
      child: CoilInteraction(
        onPressed: onHome,
        excludeFromSemantics: true,
        child: row,
        builder: (context, states, child) => CoilFocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: radius,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: states.contains(WidgetState.pressed)
                  ? colors.active
                  : states.contains(WidgetState.hovered)
                  ? colors.hover
                  : null,
              shape: RoundedSuperellipseBorder(borderRadius: radius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Minimal geometric mark for `turns`: two staggered conversational turn bars.
class TurnsLogo extends StatelessWidget {
  const TurnsLogo({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TurnsLogoPainter(
          primary: colors.foreground,
          accent: colors.brand,
        ),
      ),
    );
  }
}

class _TurnsLogoPainter extends CustomPainter {
  const _TurnsLogoPainter({required this.primary, required this.accent});

  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height * 0.28;
    final r = Radius.circular(h * 0.5);
    final topBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.16,
        size.width * 0.72,
        h,
      ),
      r,
    );
    final bottomBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.04,
        size.height * 0.56,
        size.width * 0.72,
        h,
      ),
      r,
    );
    canvas
      ..drawRRect(topBar, Paint()..color = accent)
      ..drawRRect(bottomBar, Paint()..color = primary);
  }

  @override
  bool shouldRepaint(_TurnsLogoPainter old) =>
      old.primary != primary || old.accent != accent;
}
