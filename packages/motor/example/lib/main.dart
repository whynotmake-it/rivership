import 'package:auto_route/auto_route.dart';
import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor_example/pages/card_stack.dart';
import 'package:motor_example/pages/drag_reorder_list.dart';
import 'package:motor_example/pages/draggable_icons.dart';
import 'package:motor_example/pages/flip_card.dart';
import 'package:motor_example/pages/loop_modes.dart';
import 'package:motor_example/pages/motion_padding.dart';
import 'package:motor_example/pages/phase_tracks.dart';
import 'package:motor_example/pages/picture_in_picture.dart';
import 'package:motor_example/pages/tap_playground.dart';
import 'package:motor_example/pages/timeline_choreography.dart';
import 'package:motor_example/pages/title_slide.dart';
import 'package:motor_example/pages/two_d_redirection.dart';
import 'package:motor_example/pages/velocity_tracking.dart';
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

final motorRoutes = [
  NamedRouteDef(
    name: 'Motor 2.0',
    path: '',
    type: RouteType.cupertino(),
    builder: (context, state) => const _HomePage(),
  ),
  NamedRouteDef(
    name: TimelineChoreographyPage.routeName,
    path: 'timeline',
    type: RouteType.cupertino(),
    builder: (context, state) => const TimelineChoreographyPage(),
  ),
  NamedRouteDef(
    name: PhaseTracksPage.routeName,
    path: 'phase-tracks',
    type: RouteType.cupertino(),
    builder: (context, state) => const PhaseTracksPage(),
  ),
  NamedRouteDef(
    name: TapPlaygroundPage.routeName,
    path: 'tap-playground',
    type: RouteType.cupertino(),
    builder: (context, state) => const TapPlaygroundPage(),
  ),
  NamedRouteDef(
    name: CardStackPage.routeName,
    path: 'card-stack',
    type: RouteType.cupertino(),
    builder: (context, state) => const CardStackPage(),
  ),
  NamedRouteDef(
    name: LoopModesPage.routeName,
    path: 'loop-modes',
    type: RouteType.cupertino(),
    builder: (context, state) => const LoopModesPage(),
  ),
  NamedRouteDef(
    name: VelocityTrackingPage.routeName,
    path: 'velocity-tracking',
    type: RouteType.cupertino(),
    builder: (context, state) => const VelocityTrackingPage(),
  ),
  NamedRouteDef(
    name: FlipCardPage.routeName,
    path: 'flip-card',
    type: RouteType.cupertino(),
    builder: (context, state) => const FlipCardPage(),
  ),
  NamedRouteDef(
    name: DraggableIconsPage.routeName,
    path: 'draggable-icons',
    type: RouteType.cupertino(),
    builder: (context, state) => const DraggableIconsPage(),
  ),
  NamedRouteDef(
    name: PictureInPicturePage.routeName,
    path: 'picture-in-picture',
    type: RouteType.cupertino(),
    builder: (context, state) => const PictureInPicturePage(),
  ),
  NamedRouteDef(
    name: TitleSlidePage.routeName,
    path: 'title-slide',
    type: RouteType.cupertino(),
    builder: (context, state) => const TitleSlidePage(),
  ),
  NamedRouteDef(
    name: DragReorderListPage.routeName,
    path: 'drag-reorder',
    type: RouteType.cupertino(),
    builder: (context, state) => const DragReorderListPage(),
  ),
  NamedRouteDef(
    name: TwoDRedirectionPage.routeName,
    path: '2d-redirection',
    type: RouteType.cupertino(),
    builder: (context, state) => const TwoDRedirectionPage(),
  ),
  NamedRouteDef(
    name: MotionPaddingPage.routeName,
    path: 'motion-padding',
    type: RouteType.cupertino(),
    builder: (context, state) => const MotionPaddingPage(),
  ),
];

final router = RootStackRouter.build(
  routes: [
    NamedRouteDef.shell(
      name: 'Home',
      path: '/',
      type: RouteType.cupertino(),
      children: motorRoutes,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Home page
// ---------------------------------------------------------------------------

const _cardMaxWidth = 340.0;
const _cardSpacing = 36.0;

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: t.canvas,
      child: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SectionHeader(
                        logo: const MotorLogo(),
                        title: 'Motor',
                        subtitle:
                            'One animation model for real product motion.',
                        hint: '(tap a card to explore)',
                      ),
                    ),
                  ),
                  _cardSection(
                    label: 'TRACKS + TIMELINES',
                    prefix: 'TRK',
                    cards: _trackCards(context, t),
                  ),
                  _cardSection(
                    label: 'MOTION BASICS',
                    prefix: 'BAS',
                    cards: _basicCards(context, t),
                  ),
                  _cardSection(
                    label: 'GESTURES + DRAG',
                    prefix: 'DRG',
                    cards: _gestureCards(context, t),
                  ),
                  _cardSection(
                    label: 'ADVANCED',
                    prefix: 'ADV',
                    cards: _advancedCards(context, t),
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
          child: CardSection(
            prefix: prefix,
            child: _CardGrid(children: cards),
          ),
        ),
      ],
    );
  }

  List<Widget> _trackCards(BuildContext context, ExampleTheme t) => [
        ExampleCard(
          index: 0,
          pillLabel: 'TrackTimeline',
          pillIcon: CupertinoIcons.play_circle_fill,
          pillColor: t.accentBlue,
          codeHint: 'MultiTrackMotionBuilder(timeline: ...)',
          preview: _TimelinePreview(t: t),
          title: 'Timeline Choreography',
          description:
              'Replay a reusable TrackTimeline with staggered steps.',
          onTap: () => context.navigateTo(
            NamedRoute(TimelineChoreographyPage.routeName),
          ),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'PhaseTrackBuilder',
          pillIcon: CupertinoIcons.slider_horizontal_3,
          pillColor: t.accentPurple,
          codeHint: 'PhaseTrackBuilder(currentPhase: ...)',
          preview: _PhasePreview(t: t),
          title: 'Phase Tracks',
          description:
              'Switch named phases and let every track redirect.',
          onTap: () => context.navigateTo(
            NamedRoute(PhaseTracksPage.routeName),
          ),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'TrackController',
          pillIcon: CupertinoIcons.sparkles,
          pillColor: t.accentGreen,
          codeHint: 'controller.play(timeline)',
          preview: _TapPreview(t: t),
          title: 'Tap Playground',
          description:
              'Tap to launch a timeline, drag to redirect one track.',
          onTap: () => context.navigateTo(
            NamedRoute(TapPlaygroundPage.routeName),
          ),
        ),
      ];

  List<Widget> _basicCards(BuildContext context, ExampleTheme t) => [
        ExampleCard(
          index: 0,
          pillLabel: 'MotionController',
          pillIcon: CupertinoIcons.arrow_2_squarepath,
          pillColor: t.accentOrange,
          codeHint: 'MotionController + Matrix4.rotationX',
          preview: _FlipPreview(t: t),
          title: 'Flip Card',
          description: 'Spring-based vs curve-based 3D card flip.',
          onTap: () => context.navigateTo(
            NamedRoute(FlipCardPage.routeName),
          ),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'Velocity Tracking',
          pillIcon: CupertinoIcons.speedometer,
          pillColor: t.accentBlue,
          codeHint: 'controller.animateTo(0.5)',
          preview: _SliderPreview(t: t),
          title: 'Velocity Tracking',
          description:
              'Drag a slider fast and watch the spring momentum.',
          onTap: () => context.navigateTo(
            NamedRoute(VelocityTrackingPage.routeName),
          ),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'FontMotionConverter',
          pillIcon: CupertinoIcons.textformat_alt,
          pillColor: t.accentGold,
          codeHint: 'MotionBuilder<TextStyle>(converter: ...)',
          preview: _TitlePreview(t: t),
          title: 'Title Slide',
          description:
              'Staggered font weight + width animation per letter.',
          onTap: () => context.navigateTo(
            NamedRoute(TitleSlidePage.routeName),
          ),
        ),
        ExampleCard(
          index: 3,
          pillLabel: 'MotionPadding',
          pillIcon: CupertinoIcons.square_arrow_right,
          pillColor: t.accentIndigo,
          codeHint: 'MotionPadding(padding: ...)',
          preview: _PaddingPreview(t: t),
          title: 'Motion Padding',
          description: 'Implicit spring-animated padding changes.',
          onTap: () => context.navigateTo(
            NamedRoute(MotionPaddingPage.routeName),
          ),
        ),
      ];

  List<Widget> _gestureCards(BuildContext context, ExampleTheme t) => [
        ExampleCard(
          index: 0,
          pillLabel: 'SequenceMotionController',
          pillIcon: CupertinoIcons.square_stack_3d_up_fill,
          pillColor: t.accentPurple,
          codeHint: 'MotionSequence.statesWithMotions({...})',
          preview: _StackPreview(t: t),
          title: 'Card Stack',
          description:
              'Swipe cards with physics-based fly-out and return.',
          onTap: () => context.navigateTo(
            NamedRoute(CardStackPage.routeName),
          ),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'MotionDraggable',
          pillIcon: CupertinoIcons.hand_draw_fill,
          pillColor: t.accentGreen,
          codeHint: 'MotionDraggable<IconData>(motion: ...)',
          preview: _DragPreview(t: t),
          title: 'Draggable Icons',
          description: 'Spring-backed drag-and-drop with MotionDraggable.',
          onTap: () => context.navigateTo(
            NamedRoute(DraggableIconsPage.routeName),
          ),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'Snap to Corner',
          pillIcon: CupertinoIcons.rectangle_on_rectangle,
          pillColor: t.accentOrange,
          codeHint: 'MotionDraggable + DragTarget',
          preview: _PipPreview(t: t),
          title: 'Picture in Picture',
          description: 'Drag a floating card and snap to corners.',
          onTap: () => context.navigateTo(
            NamedRoute(PictureInPicturePage.routeName),
          ),
        ),
        ExampleCard(
          index: 3,
          pillLabel: 'MotionDraggable',
          pillIcon: CupertinoIcons.line_horizontal_3,
          pillColor: t.accentBlue,
          codeHint: 'MotionDraggable(axis: Axis.vertical)',
          preview: _ListPreview(t: t),
          title: 'Drag Reorder',
          description: 'Vertical drag-to-reorder with animated gaps.',
          onTap: () => context.navigateTo(
            NamedRoute(DragReorderListPage.routeName),
          ),
        ),
      ];

  List<Widget> _advancedCards(BuildContext context, ExampleTheme t) => [
        ExampleCard(
          index: 0,
          pillLabel: 'LoopMode',
          pillIcon: CupertinoIcons.arrow_2_circlepath,
          pillColor: t.accentGreen,
          codeHint: 'LoopMode.seamless / .pingPong / .loop',
          preview: _LoopPreview(t: t),
          title: 'Loop Modes',
          description:
              'Compare none, loop, pingPong, and seamless side by side.',
          onTap: () => context.navigateTo(
            NamedRoute(LoopModesPage.routeName),
          ),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'VelocityMotionBuilder',
          pillIcon: CupertinoIcons.scope,
          pillColor: t.accentPurple,
          codeHint: 'VelocityMotionBuilder(value: offset)',
          preview: _TwoDPreview(t: t),
          title: '2D Redirection',
          description:
              'Velocity-driven squash and stretch on a 2D plane.',
          onTap: () => context.navigateTo(
            NamedRoute(TwoDRedirectionPage.routeName),
          ),
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
      padding: const EdgeInsets.only(top: 32, bottom: 20),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
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
        final cardWidth =
            (available - _cardSpacing * (columns - 1)) / columns;

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
// Mini preview widgets
// ---------------------------------------------------------------------------

class _TimelinePreview extends StatelessWidget {
  const _TimelinePreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    final colors = [t.accentBlue, t.accentGreen, t.accentPurple, t.accentOrange];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: EdgeInsets.only(left: i * 20.0 + 24, top: i == 0 ? 0 : 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 6,
                  width: 60.0 - i * 8,
                  decoration: BoxDecoration(
                    color: colors[i].withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhasePreview extends StatelessWidget {
  const _PhasePreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    final colors = [t.accentBlue, t.accentPurple, t.accentGreen];
    const sizes = [32.0, 48.0, 36.0];
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                width: sizes[i],
                height: sizes[i],
                decoration: BoxDecoration(
                  color: colors[i].withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(sizes[i] * 0.3),
                  border: Border.all(color: colors[i].withValues(alpha: .4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TapPreview extends StatelessWidget {
  const _TapPreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: t.accentGreen.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.accentGreen.withValues(alpha: .3)),
        ),
        child: Center(
          child: Icon(CupertinoIcons.sparkles, color: t.accentGreen, size: 24),
        ),
      ),
    );
  }
}

class _FlipPreview extends StatelessWidget {
  const _FlipPreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _miniCard(t.accentBlue, 'S'),
          const SizedBox(width: 16),
          _miniCard(t.accentOrange, 'C'),
        ],
      ),
    );
  }

  Widget _miniCard(Color color, String label) {
    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SliderPreview extends StatelessWidget {
  const _SliderPreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 6,
        decoration: BoxDecoration(
          color: t.borderSubtle,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Align(
          alignment: const Alignment(-0.3, 0),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: t.accentBlue,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _TitlePreview extends StatelessWidget {
  const _TitlePreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Motor',
        style: TextStyle(
          fontFamily: 'Archivo',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: t.textPrimary,
        ),
      ),
    );
  }
}

class _PaddingPreview extends StatelessWidget {
  const _PaddingPreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 80,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: t.borderSubtle),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: t.accentIndigo.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _StackPreview extends StatelessWidget {
  const _StackPreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    final colors = [t.accentBlue, t.accentPurple, t.accentGreen];
    return Center(
      child: SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          children: [
            for (var i = 2; i >= 0; i--)
              Positioned(
                left: 10.0 + i * 4,
                top: 10.0 - i * 6,
                child: Container(
                  width: 52,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors[i].withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors[i].withValues(alpha: .35)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DragPreview extends StatelessWidget {
  const _DragPreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _dot(t.accentGreen),
          const SizedBox(width: 24),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.borderSubtle, width: 2),
            ),
            child: Icon(CupertinoIcons.plus, color: t.textTertiary, size: 16),
          ),
          const SizedBox(width: 24),
          _dot(t.accentPurple),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Icon(CupertinoIcons.heart_fill, color: color, size: 16),
    );
  }
}

class _PipPreview extends StatelessWidget {
  const _PipPreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          width: 64,
          height: 40,
          decoration: BoxDecoration(
            color: t.accentOrange.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.accentOrange.withValues(alpha: .35)),
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.rectangle_on_rectangle,
              color: t.accentOrange,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListPreview extends StatelessWidget {
  const _ListPreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Container(
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: t.borderSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoopPreview extends StatelessWidget {
  const _LoopPreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    final colors = [t.accentBlue, t.accentGreen, t.accentOrange, t.accentPurple];
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final color in colors)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                CupertinoIcons.arrow_2_circlepath,
                color: color.withValues(alpha: .6),
                size: 22,
              ),
            ),
        ],
      ),
    );
  }
}

class _TwoDPreview extends StatelessWidget {
  const _TwoDPreview({required this.t});
  final ExampleTheme t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: t.accentPurple.withValues(alpha: .12),
          shape: BoxShape.circle,
          border: Border.all(color: t.accentPurple.withValues(alpha: .35)),
        ),
        child: Center(
          child: Icon(CupertinoIcons.scope, color: t.accentPurple, size: 20),
        ),
      ),
    );
  }
}
