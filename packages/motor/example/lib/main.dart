import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor_example/pages/accordion.dart';
import 'package:motor_example/pages/card_stack.dart';
import 'package:motor_example/pages/drag_reorder_list.dart';
import 'package:motor_example/pages/draggable_icons.dart';
import 'package:motor_example/pages/drawer.dart';
import 'package:motor_example/pages/flip_card.dart';
import 'package:motor_example/pages/interruptible_motion.dart';
import 'package:motor_example/pages/loaders.dart';
import 'package:motor_example/pages/now_playing.dart';
import 'package:motor_example/pages/picture_in_picture.dart';
import 'package:motor_example/pages/segmented_selector.dart';
import 'package:motor_example/pages/snap_carousel.dart';
import 'package:motor_example/pages/staggered_entrance.dart';
import 'package:motor_example/pages/title_slide.dart';
import 'package:motor_example/pages/toast.dart';
import 'package:motor_example/pages/toggle.dart';
import 'package:motor_example/widgets/motor_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CupertinoApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router.config(),
    ),
  );
}

NamedRouteDef _route(String name, String path, WidgetBuilder builder) =>
    NamedRouteDef(
      name: name,
      path: path,
      type: const RouteType.cupertino(),
      builder: (context, state) => builder(context),
    );

final motorRoutes = [
  NamedRouteDef(
    name: 'Motor 2.0',
    path: '',
    type: const RouteType.cupertino(),
    builder: (context, state) => const _HomePage(),
  ),
  _route(InterruptibleMotionPage.routeName, 'interruptible',
      (_) => const InterruptibleMotionPage()),
  _route(DrawerPage.routeName, 'drawer', (_) => const DrawerPage()),
  _route(SnapCarouselPage.routeName, 'snap-carousel',
      (_) => const SnapCarouselPage()),
  _route(TogglePage.routeName, 'toggle', (_) => const TogglePage()),
  _route(ToastPage.routeName, 'toast', (_) => const ToastPage()),
  _route(SegmentedSelectorPage.routeName, 'segmented',
      (_) => const SegmentedSelectorPage()),
  _route(AccordionPage.routeName, 'accordion', (_) => const AccordionPage()),
  _route(LoadersPage.routeName, 'loaders', (_) => const LoadersPage()),
  _route(CardStackPage.routeName, 'card-stack', (_) => const CardStackPage()),
  _route(NowPlayingPage.routeName, 'now-playing',
      (_) => const NowPlayingPage()),
  _route(StaggeredEntrancePage.routeName, 'staggered',
      (_) => const StaggeredEntrancePage()),
  _route(TitleSlidePage.routeName, 'title-slide',
      (_) => const TitleSlidePage()),
  _route(FlipCardPage.routeName, 'flip-card', (_) => const FlipCardPage()),
  _route(DraggableIconsPage.routeName, 'draggable-icons',
      (_) => const DraggableIconsPage()),
  _route(PictureInPicturePage.routeName, 'picture-in-picture',
      (_) => const PictureInPicturePage()),
  _route(DragReorderListPage.routeName, 'drag-reorder',
      (_) => const DragReorderListPage()),
];

final router = RootStackRouter.build(
  routes: [
    NamedRouteDef.shell(
      name: 'Home',
      path: '/',
      type: const RouteType.cupertino(),
      children: motorRoutes,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Home page
// ---------------------------------------------------------------------------

const _cardMaxWidth = 320.0;
const _cardSpacing = 36.0;

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: t.canvas,
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 360,
            child: AmbientGlow(opacity: .2),
          ),
          CustomScrollView(
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: SectionHeader(
                            logo: MotorLogo(),
                            title: 'Motor',
                            subtitle:
                                'One motion model for real product motion.',
                            hint: '(tap a card to explore)',
                          ),
                        ),
                      ),
                      _cardSection(
                        label: 'CONTINUITY',
                        prefix: 'CNT',
                        cards: _continuityCards(context),
                      ),
                      _cardSection(
                        label: 'EVERYDAY UI',
                        prefix: 'EVD',
                        cards: _everydayCards(context),
                      ),
                      _cardSection(
                        label: 'COMPOSE MOTION',
                        prefix: 'CMP',
                        cards: _composeCards(context),
                      ),
                      _cardSection(
                        label: 'GESTURES',
                        prefix: 'GST',
                        cards: _gestureCards(context),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 64),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _cardSection({
    required String label,
    required String prefix,
    required List<Widget> cards,
  }) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _SubsectionLabel(label)),
        SliverToBoxAdapter(
          child: CardSection(prefix: prefix, child: _CardGrid(children: cards)),
        ),
      ],
    );
  }

  void _go(BuildContext context, String name) =>
      context.navigateTo(NamedRoute(name));

  List<Widget> _continuityCards(BuildContext context) => [
        ExampleCard(
          index: 0,
          pillLabel: 'SingleMotionController',
          pillIcon: CupertinoIcons.graph_square,
          codeHint: 'controller.animateTo(target)',
          preview: const _GraphPreview(),
          title: 'Interruptible Motion',
          description:
              'Spring vs curve, graphed live. See why continuous motion holds '
              'its velocity through every redirect.',
          onTap: () => _go(context, InterruptibleMotionPage.routeName),
        ),
      ];

  List<Widget> _everydayCards(BuildContext context) => [
        ExampleCard(
          index: 0,
          pillLabel: 'SingleMotionController',
          pillIcon: CupertinoIcons.sidebar_left,
          codeHint: 'animateTo(target, withVelocity: v)',
          preview: const _DrawerPreview(),
          title: 'Drawer',
          description: 'A spring drawer you can fling open and closed.',
          onTap: () => _go(context, DrawerPage.routeName),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'FrictionMotion.project',
          pillIcon: CupertinoIcons.rectangle_stack,
          codeHint: 'friction.project(from:, velocity:)',
          preview: const _CarouselPreview(),
          title: 'Snap Carousel',
          description: 'Fling and snap to the nearest card via projection.',
          onTap: () => _go(context, SnapCarouselPage.routeName),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'CupertinoMotion.bouncy',
          pillIcon: CupertinoIcons.switch_camera,
          codeHint: 'animateTo(on ? 1 : 0)',
          preview: const _TogglePreview(),
          title: 'Toggle',
          description: 'Springy switches, likes, and reveals.',
          onTap: () => _go(context, TogglePage.routeName),
        ),
        ExampleCard(
          index: 3,
          pillLabel: 'SingleMotionController',
          pillIcon: CupertinoIcons.bell,
          codeHint: 'swipe → withVelocity',
          preview: const _ToastPreview(),
          title: 'Toast',
          description: 'A notification that springs in and flicks away.',
          onTap: () => _go(context, ToastPage.routeName),
        ),
        ExampleCard(
          index: 4,
          pillLabel: 'MotionBuilder<Rect>',
          pillIcon: CupertinoIcons.rectangle_split_3x1,
          codeHint: 'MotionBuilder(value: rect)',
          preview: const _SegmentedPreview(),
          title: 'Segmented Selector',
          description: 'A selection indicator that slides between tabs.',
          onTap: () => _go(context, SegmentedSelectorPage.routeName),
        ),
        ExampleCard(
          index: 5,
          pillLabel: 'SingleMotionController',
          pillIcon: CupertinoIcons.chevron_down,
          codeHint: 'heightFactor: controller.value',
          preview: const _AccordionPreview(),
          title: 'Accordion',
          description: 'Expandable rows that spring open.',
          onTap: () => _go(context, AccordionPage.routeName),
        ),
        ExampleCard(
          index: 6,
          pillLabel: 'array of Tracks',
          pillIcon: CupertinoIcons.circle_grid_3x3,
          codeHint: 'MultiTrackMotionBuilder(loop: ...)',
          preview: const _LoadersPreview(),
          title: 'Loaders',
          description: 'Dot grids and spinners from looping tracks.',
          onTap: () => _go(context, LoadersPage.routeName),
        ),
      ];

  List<Widget> _composeCards(BuildContext context) => [
        ExampleCard(
          index: 0,
          pillLabel: 'PhaseTrackController',
          pillIcon: CupertinoIcons.square_stack_3d_up,
          codeHint: 'playPhases(timeline)',
          preview: const _StackPreview(),
          title: 'Card Stack',
          description: 'Swipe cards with projected, physics-based fly-out.',
          onTap: () => _go(context, CardStackPage.routeName),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'PhaseTrackBuilder',
          pillIcon: CupertinoIcons.music_note_2,
          codeHint: 'TrackPhaseTimeline({...})',
          preview: const _NowPlayingPreview(),
          title: 'Now Playing',
          description: 'A mini player expands with independent tracks.',
          onTap: () => _go(context, NowPlayingPage.routeName),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'MultiTrackMotionBuilder',
          pillIcon: CupertinoIcons.list_bullet,
          codeHint: 'array of staggered tracks',
          preview: const _StaggerPreview(),
          title: 'Staggered Entrance',
          description: 'A list that cascades in on a single clock.',
          onTap: () => _go(context, StaggeredEntrancePage.routeName),
        ),
        ExampleCard(
          index: 3,
          pillLabel: 'MotionBuilder<TextStyle>',
          pillIcon: CupertinoIcons.textformat,
          codeHint: 'animated wght + wdth',
          preview: const _TitlePreview(),
          title: 'Title Slide',
          description: 'Per-letter variable font weight and width.',
          onTap: () => _go(context, TitleSlidePage.routeName),
        ),
        ExampleCard(
          index: 4,
          pillLabel: 'MotionController',
          pillIcon: CupertinoIcons.arrow_2_squarepath,
          codeHint: 'spring vs curve, side by side',
          preview: const _FlipPreview(),
          title: 'Flip Card',
          description: 'Interrupt a 3D flip and feel the difference.',
          onTap: () => _go(context, FlipCardPage.routeName),
        ),
      ];

  List<Widget> _gestureCards(BuildContext context) => [
        ExampleCard(
          index: 0,
          pillLabel: 'MotionDraggable',
          pillIcon: CupertinoIcons.hand_draw,
          codeHint: 'MotionDraggable(motion: ...)',
          preview: const _DragPreview(),
          title: 'Draggable Icons',
          description: 'Spring-backed drag and drop.',
          onTap: () => _go(context, DraggableIconsPage.routeName),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'MotionController<Offset>',
          pillIcon: CupertinoIcons.rectangle_on_rectangle,
          codeHint: 'project → nearest corner',
          preview: const _PipPreview(),
          title: 'Picture in Picture',
          description: 'Fling a window and snap to a corner.',
          onTap: () => _go(context, PictureInPicturePage.routeName),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'MotionDraggable',
          pillIcon: CupertinoIcons.line_horizontal_3,
          codeHint: 'MotionDraggable(axis: vertical)',
          preview: const _ReorderPreview(),
          title: 'Drag Reorder',
          description: 'Vertical reordering with animated gaps.',
          onTap: () => _go(context, DragReorderListPage.routeName),
        ),
      ];
}

// ---------------------------------------------------------------------------
// Shared home widgets
// ---------------------------------------------------------------------------

class _SubsectionLabel extends StatelessWidget {
  const _SubsectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 18),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: t.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final columns = (available / _cardMaxWidth).floor().clamp(1, 4);
        final cardWidth = (available - _cardSpacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _cardSpacing,
          runSpacing: _cardSpacing,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Monochrome preview vignettes
// ---------------------------------------------------------------------------

class _GraphPreview extends StatelessWidget {
  const _GraphPreview();

  @override
  Widget build(BuildContext context) {
    final points = <Offset>[
      for (var i = 0; i <= 48; i++)
        Offset(
          i / 48,
          (0.5 - 0.42 * math.exp(-3.2 * (i / 48)) * math.cos(i / 48 * 9))
              .clamp(0.05, 0.95),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.all(22),
      child: TrajectoryLine(
        points: points,
        gradient: ExampleTheme.spectrum,
        thickness: 3,
        fade: false,
      ),
    );
  }
}

class _DrawerPreview extends StatelessWidget {
  const _DrawerPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Container(
        width: 120,
        height: 110,
        decoration: BoxDecoration(
          color: t.surfaceSolid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 56,
              color: t.fog,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Container(
                          width: i == 0 ? 36 : 28,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == 0 ? t.textPrimary : t.borderStrong,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Icon(CupertinoIcons.line_horizontal_3,
                  color: t.textTertiary, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselPreview extends StatelessWidget {
  const _CarouselPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _miniCard(t, 0.86),
          const SizedBox(width: 10),
          _miniCard(t, 1),
          const SizedBox(width: 10),
          _miniCard(t, 0.86),
        ],
      ),
    );
  }

  Widget _miniCard(ExampleTheme t, double scale) => Transform.scale(
        scale: scale,
        child: Container(
          width: 50,
          height: 78,
          decoration: BoxDecoration(
            color: t.surfaceSolid,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scale == 1 ? t.borderStrong : t.border,
            ),
            boxShadow: scale == 1 ? t.hairlineShadow : null,
          ),
        ),
      );
}

class _TogglePreview extends StatelessWidget {
  const _TogglePreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 32,
            decoration: BoxDecoration(
              color: t.textPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: t.surfaceSolid,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Icon(CupertinoIcons.heart_fill, color: t.textPrimary, size: 24),
        ],
      ),
    );
  }
}

class _ToastPreview extends StatelessWidget {
  const _ToastPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: t.surfaceSolid,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
            boxShadow: t.hairlineShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration:
                    BoxDecoration(color: t.fog, shape: BoxShape.circle),
                child: Icon(CupertinoIcons.bell_fill,
                    size: 12, color: t.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 56, height: 6, color: t.borderStrong),
                    const SizedBox(height: 5),
                    Container(width: 38, height: 5, color: t.border),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedPreview extends StatelessWidget {
  const _SegmentedPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Container(
        width: 150,
        height: 38,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: t.fog,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: t.surfaceSolid,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: t.hairlineShadow,
                ),
              ),
            ),
            const Expanded(child: SizedBox()),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}

class _AccordionPreview extends StatelessWidget {
  const _AccordionPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _row(t, expanded: true),
          Container(height: 1, color: t.border),
          _row(t),
          Container(height: 1, color: t.border),
          _row(t),
        ],
      ),
    );
  }

  Widget _row(ExampleTheme t, {bool expanded = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 70, height: 7, color: t.textPrimary),
                const Spacer(),
                Transform.rotate(
                  angle: expanded ? math.pi / 2 : 0,
                  child: Icon(CupertinoIcons.chevron_right,
                      size: 12, color: t.textTertiary),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              Container(width: double.infinity, height: 5, color: t.border),
              const SizedBox(height: 4),
              Container(width: 90, height: 5, color: t.border),
            ],
          ],
        ),
      );
}

class _LoadersPreview extends StatelessWidget {
  const _LoadersPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: t.textPrimary.withValues(alpha: i == 1 ? 1 : 0.35),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StackPreview extends StatelessWidget {
  const _StackPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: SizedBox(
        width: 100,
        height: 90,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 2; i >= 0; i--)
              Transform.translate(
                offset: Offset(i * 6, -i * 8),
                child: Transform.scale(
                  scale: 1 - i * 0.07,
                  child: Container(
                    width: 80,
                    height: 56,
                    decoration: BoxDecoration(
                      color: t.surfaceSolid,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.border),
                      boxShadow: i == 0 ? t.hairlineShadow : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingPreview extends StatelessWidget {
  const _NowPlayingPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.textPrimary, t.textSecondary],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(CupertinoIcons.music_note_2,
                color: t.surfaceSolid, size: 20),
          ),
          const SizedBox(height: 12),
          Container(width: 60, height: 7, color: t.textPrimary),
          const SizedBox(height: 5),
          Container(width: 40, height: 5, color: t.border),
        ],
      ),
    );
  }
}

class _StaggerPreview extends StatelessWidget {
  const _StaggerPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: EdgeInsets.only(bottom: 12, left: i * 8.0),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration:
                        BoxDecoration(color: t.fog, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 70 - i * 8.0,
                    height: 6,
                    color: t.borderStrong,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TitlePreview extends StatelessWidget {
  const _TitlePreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Text(
        'Aa',
        style: TextStyle(
          fontFamily: 'Archivo',
          fontSize: 64,
          fontWeight: FontWeight.w300,
          letterSpacing: -2,
          color: t.textPrimary,
        ),
      ),
    );
  }
}

class _FlipPreview extends StatelessWidget {
  const _FlipPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _face(t, filled: false),
          const SizedBox(width: 14),
          _face(t, filled: true),
        ],
      ),
    );
  }

  Widget _face(ExampleTheme t, {required bool filled}) => Container(
        width: 50,
        height: 70,
        decoration: BoxDecoration(
          color: filled ? t.textPrimary : t.surfaceSolid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
          boxShadow: t.hairlineShadow,
        ),
      );
}

class _DragPreview extends StatelessWidget {
  const _DragPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _chip(t, CupertinoIcons.heart_fill),
          const SizedBox(width: 22),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.border, width: 1.5),
            ),
            child: Icon(CupertinoIcons.add, color: t.textTertiary, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _chip(ExampleTheme t, IconData icon) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.surfaceSolid,
          border: Border.all(color: t.border),
          boxShadow: t.hairlineShadow,
        ),
        child: Icon(icon, color: t.textPrimary, size: 18),
      );
}

class _PipPreview extends StatelessWidget {
  const _PipPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Container(
          width: 78,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.textPrimary, t.textSecondary],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: t.hairlineShadow,
          ),
          child: Icon(CupertinoIcons.play_fill,
              color: t.surfaceSolid.withValues(alpha: .9), size: 18),
        ),
      ),
    );
  }
}

class _ReorderPreview extends StatelessWidget {
  const _ReorderPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration:
                        BoxDecoration(color: t.fog, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == 1 ? t.textPrimary : t.borderStrong,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(CupertinoIcons.line_horizontal_3,
                      size: 14, color: t.textTertiary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
