import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor_example/pages/accordion.dart';
import 'package:motor_example/pages/card_stack.dart';
import 'package:motor_example/pages/curve_trap.dart';
import 'package:motor_example/pages/curve_trap_escape.dart';
import 'package:motor_example/pages/draggable_icons.dart';
import 'package:motor_example/pages/drawer.dart';
import 'package:motor_example/pages/instant_vs_animated.dart';
import 'package:motor_example/pages/interruptible_motion.dart';
import 'package:motor_example/pages/loaders.dart';
import 'package:motor_example/pages/motion_character.dart';
import 'package:motor_example/pages/now_playing.dart';
import 'package:motor_example/pages/payment_success.dart';
import 'package:motor_example/pages/photo_flick.dart';
import 'package:motor_example/pages/picture_in_picture.dart';
import 'package:motor_example/pages/pull_to_refresh.dart';
import 'package:motor_example/pages/snap_carousel.dart';
import 'package:motor_example/pages/spring_character.dart';
import 'package:motor_example/pages/the_spring.dart';
import 'package:motor_example/pages/thermostat.dart';
import 'package:motor_example/pages/title_slide.dart';
import 'package:motor_example/pages/toast.dart';
import 'package:motor_example/pages/toggle.dart';
import 'package:motor_example/pages/two_dimensions.dart';
import 'package:motor_example/pages/why_motion.dart';
import 'package:motor_example/widgets/motor_logo.dart';
import 'package:motor_example/widgets/spring_visualizer.dart';

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
  // Why physical motion (the explainer arc).
  _route(WhyMotionPage.routeName, 'why-motion', (_) => const WhyMotionPage()),
  _route(CurveTrapPage.routeName, 'curve-trap', (_) => const CurveTrapPage()),
  _route(TheSpringPage.routeName, 'the-spring', (_) => const TheSpringPage()),
  _route(InterruptibleMotionPage.routeName, 'interruptible',
      (_) => const InterruptibleMotionPage()),
  _route(TwoDimensionsPage.routeName, 'two-dimensions',
      (_) => const TwoDimensionsPage()),
  _route(MotionCharacterPage.routeName, 'motion-character',
      (_) => const MotionCharacterPage()),
  _route(InstantVsAnimatedPage.routeName, 'instant-vs-animated',
      (_) => const InstantVsAnimatedPage()),
  _route(CurveTrapEscapePage.routeName, 'curve-trap-escape',
      (_) => const CurveTrapEscapePage()),
  _route(SpringCharacterPage.routeName, 'spring-character',
      (_) => const SpringCharacterPage()),
  _route(PhotoFlickPage.routeName, 'photo-flick',
      (_) => const PhotoFlickPage()),
  // Everyday UI.
  _route(TogglePage.routeName, 'toggle', (_) => const TogglePage()),
  _route(SnapCarouselPage.routeName, 'snap-carousel',
      (_) => const SnapCarouselPage()),
  _route(ToastPage.routeName, 'toast', (_) => const ToastPage()),
  _route(DrawerPage.routeName, 'drawer', (_) => const DrawerPage()),
  _route(AccordionPage.routeName, 'accordion', (_) => const AccordionPage()),
  _route(LoadersPage.routeName, 'loaders', (_) => const LoadersPage()),
  // Compose motion.
  _route(PaymentSuccessPage.routeName, 'payment-success',
      (_) => const PaymentSuccessPage()),
  _route(ThermostatPage.routeName, 'thermostat',
      (_) => const ThermostatPage()),
  _route(CardStackPage.routeName, 'card-stack', (_) => const CardStackPage()),
  _route(NowPlayingPage.routeName, 'now-playing',
      (_) => const NowPlayingPage()),
  _route(TitleSlidePage.routeName, 'title-slide',
      (_) => const TitleSlidePage()),
  // Gestures.
  _route(PictureInPicturePage.routeName, 'picture-in-picture',
      (_) => const PictureInPicturePage()),
  _route(PullToRefreshPage.routeName, 'pull-to-refresh',
      (_) => const PullToRefreshPage()),
  _route(DraggableIconsPage.routeName, 'draggable-icons',
      (_) => const DraggableIconsPage()),
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
                        label: 'WHY PHYSICAL MOTION',
                        prefix: 'WHY',
                        cards: _whyCards(context),
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

  List<Widget> _whyCards(BuildContext context) => [
        ExampleCard(
          index: 0,
          pillLabel: 'set vs animate',
          pillIcon: CupertinoIcons.arrow_right_arrow_left,
          codeHint: 'controller.animate([pos.to(t)])',
          preview: const _WhyMotionPreview(),
          title: 'Why Motion?',
          description:
              'Instant vs animated, side by side. Motion is how a user keeps '
              'their place.',
          onTap: () => _go(context, WhyMotionPage.routeName),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'CurvedMotion',
          pillIcon: CupertinoIcons.bolt_horizontal,
          codeHint: 'interrupt → velocity = 0',
          preview: const _CurvePreview(),
          title: 'The Curve Trap',
          description:
              'A curve restarts from a standstill on every interrupt, kinking '
              'the line.',
          onTap: () => _go(context, CurveTrapPage.routeName),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'CupertinoMotion',
          pillIcon: CupertinoIcons.slider_horizontal_3,
          codeHint: 'duration + bounce',
          preview: const _SpringPreview(),
          title: 'The Spring',
          description:
              'Physics solved each frame. Tune duration and bounce and feel '
              'the character change.',
          onTap: () => _go(context, TheSpringPage.routeName),
        ),
        ExampleCard(
          index: 3,
          pillLabel: 'TrackController',
          pillIcon: CupertinoIcons.graph_square,
          codeHint: 'velocity preserved',
          preview: const _GraphPreview(),
          title: 'Carry the Momentum',
          description:
              'Spring vs curve, graphed live — continuous motion holds its '
              'velocity through every redirect.',
          onTap: () => _go(context, InterruptibleMotionPage.routeName),
        ),
        ExampleCard(
          index: 4,
          pillLabel: 'Track<Offset>',
          pillIcon: CupertinoIcons.move,
          codeHint: 'motionPerDimension',
          preview: const _TwoDPreview(),
          title: 'More Than One Dimension',
          description:
              'One Offset track runs an independent spring per axis, preserving '
              'velocity in both.',
          onTap: () => _go(context, TwoDimensionsPage.routeName),
        ),
        ExampleCard(
          index: 5,
          pillLabel: 'CupertinoMotion presets',
          pillIcon: CupertinoIcons.smiley,
          codeHint: 'smooth · bouncy · snappy',
          preview: const _CharacterPreview(),
          title: 'Motion Character',
          description:
              'One spring, four feelings — two numbers change everything.',
          onTap: () => _go(context, MotionCharacterPage.routeName),
        ),
      ];

  List<Widget> _everydayCards(BuildContext context) => [
        ExampleCard(
          index: 0,
          pillLabel: 'Track + drag',
          pillIcon: CupertinoIcons.switch_camera,
          codeHint: 'drag → velocity → settle',
          preview: const _TogglePreview(),
          title: 'Toggle',
          description: 'Springy switches you can drag, likes, and reveals.',
          onTap: () => _go(context, TogglePage.routeName),
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
          pillLabel: 'SingleMotionController',
          pillIcon: CupertinoIcons.bell,
          codeHint: 'swipe → withVelocity',
          preview: const _ToastPreview(),
          title: 'Toast',
          description: 'A notification that springs in and flicks away.',
          onTap: () => _go(context, ToastPage.routeName),
        ),
        ExampleCard(
          index: 3,
          pillLabel: 'SingleMotionController',
          pillIcon: CupertinoIcons.sidebar_left,
          codeHint: 'animateTo(target, withVelocity: v)',
          preview: const _DrawerPreview(),
          title: 'Drawer',
          description: 'A spring drawer you can swipe and fling open.',
          onTap: () => _go(context, DrawerPage.routeName),
        ),
        ExampleCard(
          index: 4,
          pillLabel: 'SingleMotionController',
          pillIcon: CupertinoIcons.chevron_down,
          codeHint: 'heightFactor: controller.value',
          preview: const _AccordionPreview(),
          title: 'Accordion',
          description: 'Expandable rows that spring open.',
          onTap: () => _go(context, AccordionPage.routeName),
        ),
        ExampleCard(
          index: 5,
          pillLabel: 'array of Tracks',
          pillIcon: CupertinoIcons.circle_grid_3x3,
          codeHint: 'TrackBuilder(loop: ...)',
          preview: const _LoadersPreview(),
          title: 'Loaders',
          description: 'Dot grids and spinners from looping tracks.',
          onTap: () => _go(context, LoadersPage.routeName),
        ),
      ];

  List<Widget> _composeCards(BuildContext context) => [
        ExampleCard(
          index: 0,
          pillLabel: 'TrackTimeline + sync',
          pillIcon: CupertinoIcons.checkmark_seal,
          codeHint: 'track.sync(token:)',
          preview: const _PaymentPreview(),
          title: 'Payment Success',
          description:
              'Eight tracks converge through a sync barrier into a tap → '
              'process → confirm story.',
          onTap: () => _go(context, PaymentSuccessPage.routeName),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'PhaseTrackController',
          pillIcon: CupertinoIcons.thermometer,
          codeHint: '4 phases · per-track timing',
          preview: const _ThermostatPreview(),
          title: 'Thermostat',
          description:
              'Four states where each track settles on its own clock, meeting '
              'at every phase.',
          onTap: () => _go(context, ThermostatPage.routeName),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'PhaseTrackController',
          pillIcon: CupertinoIcons.square_stack_3d_up,
          codeHint: 'playPhases(timeline)',
          preview: const _StackPreview(),
          title: 'Card Stack',
          description: 'Swipe cards with projected, physics-based fly-out.',
          onTap: () => _go(context, CardStackPage.routeName),
        ),
        ExampleCard(
          index: 3,
          pillLabel: 'PhaseTrackBuilder',
          pillIcon: CupertinoIcons.music_note_2,
          codeHint: 'TrackPhaseTimeline({...})',
          preview: const _NowPlayingPreview(),
          title: 'Now Playing',
          description: 'A mini player expands with independent tracks.',
          onTap: () => _go(context, NowPlayingPage.routeName),
        ),
        ExampleCard(
          index: 4,
          pillLabel: 'MotionBuilder<TextStyle>',
          pillIcon: CupertinoIcons.textformat,
          codeHint: 'animated wght + wdth',
          preview: const _TitlePreview(),
          title: 'Title Slide',
          description: 'Per-letter variable font weight and width.',
          onTap: () => _go(context, TitleSlidePage.routeName),
        ),
      ];

  List<Widget> _gestureCards(BuildContext context) => [
        ExampleCard(
          index: 0,
          pillLabel: 'MotionController<Offset>',
          pillIcon: CupertinoIcons.rectangle_on_rectangle,
          codeHint: 'project → nearest corner',
          preview: const _PipPreview(),
          title: 'Picture in Picture',
          description: 'Fling a window and snap to a corner.',
          onTap: () => _go(context, PictureInPicturePage.routeName),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'FrictionMotion.project',
          pillIcon: CupertinoIcons.arrow_clockwise,
          codeHint: 'pull → project → commit',
          preview: const _PullPreview(),
          title: 'Pull to Refresh',
          description: 'Rubber-band a list and let physics decide to refresh.',
          onTap: () => _go(context, PullToRefreshPage.routeName),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'MotionDraggable',
          pillIcon: CupertinoIcons.hand_draw,
          codeHint: 'MotionDraggable(motion: ...)',
          preview: const _DragPreview(),
          title: 'Draggable Icons',
          description: 'Spring-backed drag and drop.',
          onTap: () => _go(context, DraggableIconsPage.routeName),
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

// ---------------------------------------------------------------------------
// Explainer & flagship preview vignettes
// ---------------------------------------------------------------------------

class _WhyMotionPreview extends StatelessWidget {
  const _WhyMotionPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    Widget lane({required Alignment dot}) => SizedBox(
          height: 22,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(height: 2, color: t.border),
              Align(
                alignment: dot,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: t.textPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          lane(dot: Alignment.centerRight),
          const SizedBox(height: 22),
          lane(dot: Alignment.center),
        ],
      ),
    );
  }
}

class _CurvePreview extends StatelessWidget {
  const _CurvePreview();

  @override
  Widget build(BuildContext context) {
    // A line with a sharp kink — the velocity break a curve leaves on redirect.
    const points = [
      Offset(0.04, 0.8),
      Offset(0.4, 0.2),
      Offset(0.5, 0.5),
      Offset(0.96, 0.5),
    ];
    return const Padding(
      padding: EdgeInsets.all(22),
      child: TrajectoryLine(
        points: points,
        gradient: ExampleTheme.spectrum,
        thickness: 3,
        fade: false,
      ),
    );
  }
}

class _SpringPreview extends StatelessWidget {
  const _SpringPreview();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 26),
      child: CustomPaint(
        size: Size.infinite,
        painter: SpringPainter(
          start: Offset(-70, 0),
          end: Offset(70, 0),
          color: ExampleTheme.spectrumRed,
          coils: 12,
          thickness: 26,
          minVisibleLength: 0,
          minFullLength: 80,
        ),
      ),
    );
  }
}

class _TwoDPreview extends StatelessWidget {
  const _TwoDPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    // A curved 2D path returning toward the center.
    const points = [
      Offset(0.18, 0.22),
      Offset(0.34, 0.5),
      Offset(0.4, 0.74),
      Offset(0.52, 0.58),
      Offset(0.5, 0.5),
    ];
    return Stack(
      children: [
        Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: t.borderStrong, shape: BoxShape.circle),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(20),
          child: TrajectoryLine(
            points: points,
            gradient: ExampleTheme.spectrum,
            thickness: 3,
            fade: false,
          ),
        ),
      ],
    );
  }
}

class _CharacterPreview extends StatelessWidget {
  const _CharacterPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    const heights = [0.5, 0.78, 0.32, 0.62];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in heights)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: t.textPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(height: 90 * h),
              ],
            ),
        ],
      ),
    );
  }
}

class _PaymentPreview extends StatelessWidget {
  const _PaymentPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: t.textPrimary,
          shape: BoxShape.circle,
          boxShadow: t.hairlineShadow,
        ),
        child: Icon(CupertinoIcons.checkmark, color: t.surfaceSolid, size: 22),
      ),
    );
  }
}

class _ThermostatPreview extends StatelessWidget {
  const _ThermostatPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: SizedBox(
        width: 96,
        height: 96,
        child: CustomPaint(
          painter: _RingPreviewPainter(t.textPrimary, t.border),
          child: Center(
            child: Icon(CupertinoIcons.flame_fill, size: 22, color: t.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _RingPreviewPainter extends CustomPainter {
  _RingPreviewPainter(this.color, this.track);
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.3,
      false,
      Paint()
        ..color = color
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPreviewPainter oldDelegate) =>
      color != oldDelegate.color || track != oldDelegate.track;
}

class _PullPreview extends StatelessWidget {
  const _PullPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.arrow_clockwise, size: 22, color: t.textSecondary),
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++) ...[
            Container(
              width: double.infinity,
              height: 7,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
