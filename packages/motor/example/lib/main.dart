import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_example/pages/boarding_pass.dart';
import 'package:motor_example/pages/card_stack.dart';
import 'package:motor_example/pages/curve_trap_escape.dart';
import 'package:motor_example/pages/draggable_icons.dart';
import 'package:motor_example/pages/instant_vs_animated.dart';
import 'package:motor_example/pages/meet_tracks.dart';
import 'package:motor_example/pages/payment_success.dart';
import 'package:motor_example/pages/phases.dart';
import 'package:motor_example/pages/photo_flick.dart';
import 'package:motor_example/pages/picture_in_picture.dart';
import 'package:motor_example/pages/pull_to_refresh.dart';
import 'package:motor_example/pages/snap_carousel.dart';
import 'package:motor_example/pages/spring_character.dart';
import 'package:motor_example/pages/sync_barriers.dart';
import 'package:motor_example/pages/timelines_and_steps.dart';
import 'package:motor_example/pages/toast.dart';
import 'package:motor_example/pages/toggle.dart';
import 'package:motor_example/widgets/motor_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MotorDevTools(
      child: CupertinoApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router.config(),
      ),
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

/// Every page also needs a home card, smoke-test entry, and a place in the
/// `next` chain when it belongs to the teaching arc.
final motorRoutes = [
  NamedRouteDef(
    name: 'Motor 2.0',
    path: '',
    type: const RouteType.cupertino(),
    builder: (context, state) => const _HomePage(),
  ),
  _route(
    InstantVsAnimatedPage.routeName,
    'instant-vs-animated',
    (_) => const InstantVsAnimatedPage(),
  ),
  _route(
    CurveTrapEscapePage.routeName,
    'curve-trap-escape',
    (_) => const CurveTrapEscapePage(),
  ),
  _route(
    SpringCharacterPage.routeName,
    'spring-character',
    (_) => const SpringCharacterPage(),
  ),
  _route(
    PhotoFlickPage.routeName,
    'photo-flick',
    (_) => const PhotoFlickPage(),
  ),
  _route(
    MeetTracksPage.routeName,
    'meet-tracks',
    (_) => const MeetTracksPage(),
  ),
  _route(
    TimelinesAndStepsPage.routeName,
    'timelines-and-steps',
    (_) => const TimelinesAndStepsPage(),
  ),
  _route(
    SyncBarriersPage.routeName,
    'sync-barriers',
    (_) => const SyncBarriersPage(),
  ),
  _route(PhasesPage.routeName, 'phases', (_) => const PhasesPage()),
  _route(TogglePage.routeName, 'toggle', (_) => const TogglePage()),
  _route(
    PullToRefreshPage.routeName,
    'pull-to-refresh',
    (_) => const PullToRefreshPage(),
  ),
  _route(CardStackPage.routeName, 'card-stack', (_) => const CardStackPage()),
  _route(
    PaymentSuccessPage.routeName,
    'payment-success',
    (_) => const PaymentSuccessPage(),
  ),
  _route(
    BoardingPassPage.routeName,
    'boarding-pass',
    (_) => const BoardingPassPage(),
  ),
  _route(
    SnapCarouselPage.routeName,
    'snap-carousel',
    (_) => const SnapCarouselPage(),
  ),
  _route(ToastPage.routeName, 'toast', (_) => const ToastPage()),
  _route(
    PictureInPicturePage.routeName,
    'picture-in-picture',
    (_) => const PictureInPicturePage(),
  ),
  _route(
    DraggableIconsPage.routeName,
    'draggable-icons',
    (_) => const DraggableIconsPage(),
  ),
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
                            hint: '(follow the chapters)',
                          ),
                        ),
                      ),
                      _cardSection(
                        label: 'FEEL THE DIFFERENCE',
                        cards: _feelCards(context),
                      ),
                      _cardSection(
                        label: 'TRACKS',
                        cards: _trackCards(context),
                      ),
                      _cardSection(
                        label: 'GESTURES × TIMELINES',
                        cards: _gestureCards(context),
                      ),
                      _cardSection(
                        label: 'RECIPES',
                        cards: _recipeCards(context),
                      ),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 64)),
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
    required List<Widget> cards,
  }) => SliverMainAxisGroup(
    slivers: [
      SliverToBoxAdapter(child: _SubsectionLabel(label)),
      SliverToBoxAdapter(child: _CardGrid(children: cards)),
    ],
  );

  void _go(BuildContext context, String name) =>
      context.navigateTo(NamedRoute(name));

  ExampleCard _card(
    BuildContext context, {
    required String chapter,
    required String pill,
    required Widget preview,
    required String title,
    required String description,
    required String routeName,
    required IconData icon,
    String? codeHint,
  }) => ExampleCard(
    categoryId: chapter,
    pillLabel: pill,
    pillIcon: icon,
    codeHint: codeHint,
    preview: preview,
    title: title,
    description: description,
    onTap: () => _go(context, routeName),
  );

  List<Widget> _feelCards(BuildContext context) => [
    _card(
      context,
      chapter: '1.1',
      pill: 'set vs animate',
      icon: CupertinoIcons.arrow_right_arrow_left,
      codeHint: 'controller.animate([position.to(target)])',
      preview: const _InstantPreview(),
      title: 'Instant vs. Animated',
      description:
          'See how continuous motion preserves context when values change.',
      routeName: InstantVsAnimatedPage.routeName,
    ),
    _card(
      context,
      chapter: '1.2',
      pill: 'CurvedMotion',
      icon: CupertinoIcons.bolt_horizontal,
      codeHint: 'interrupt → velocity = 0',
      preview: const _CurvePreview(),
      title: 'The Curve Trap',
      description:
          'Learn why time curves kink when an animation is interrupted.',
      routeName: CurveTrapEscapePage.routeName,
    ),
    _card(
      context,
      chapter: '1.3',
      pill: 'CupertinoMotion',
      icon: CupertinoIcons.slider_horizontal_3,
      codeHint: 'duration + bounce',
      preview: const _SpringPreview(),
      title: 'Spring Character',
      description: 'Shape a spring’s personality with duration and bounce.',
      routeName: SpringCharacterPage.routeName,
    ),
    _card(
      context,
      chapter: '1.4',
      pill: 'Track<Offset>',
      icon: CupertinoIcons.move,
      codeHint: 'motionPerDimension',
      preview: const _PhotoPreview(),
      title: 'More Than One Dimension',
      description:
          'Carry gesture velocity independently across both spatial axes.',
      routeName: PhotoFlickPage.routeName,
    ),
  ];

  List<Widget> _trackCards(BuildContext context) => [
    _card(
      context,
      chapter: '2.1',
      pill: 'Track<T>',
      icon: CupertinoIcons.waveform_path,
      codeHint: 'Track(value, motion:)',
      preview: const _TrackPreview(),
      title: 'Meet Tracks',
      description:
          'Use one stateful value that remembers velocity across targets.',
      routeName: MeetTracksPage.routeName,
    ),
    _card(
      context,
      chapter: '2.2',
      pill: 'TrackTimeline',
      icon: CupertinoIcons.time,
      codeHint: 'steps + loop',
      preview: const _TimelinePreview(),
      title: 'Timelines & Steps',
      description: 'Compose ordered motion steps and control how they repeat.',
      routeName: TimelinesAndStepsPage.routeName,
    ),
    _card(
      context,
      chapter: '2.3',
      pill: 'TrackTimeline + sync',
      icon: CupertinoIcons.equal_square,
      codeHint: 'track.sync(token:)',
      preview: const _SyncPreview(),
      title: 'Sync Barriers',
      description:
          'Hold faster tracks at a barrier until every peer catches up.',
      routeName: SyncBarriersPage.routeName,
    ),
    _card(
      context,
      chapter: '2.4',
      pill: 'PhaseTrackController',
      icon: CupertinoIcons.square_stack_3d_up,
      codeHint: 'playPhases(timeline)',
      preview: const _PhasesPreview(),
      title: 'Phases',
      description: 'Model interruptible UI stories as named, settled states.',
      routeName: PhasesPage.routeName,
    ),
  ];

  List<Widget> _gestureCards(BuildContext context) => [
    _card(
      context,
      chapter: '3.1',
      pill: 'Track + drag',
      icon: CupertinoIcons.switch_camera,
      codeHint: 'drag → velocity → settle',
      preview: const _TogglePreview(),
      title: 'Toggle',
      description: 'Hand a drag’s measured velocity to the settling spring.',
      routeName: TogglePage.routeName,
    ),
    _card(
      context,
      chapter: '3.2',
      pill: 'FrictionMotion.project',
      icon: CupertinoIcons.arrow_clockwise,
      codeHint: 'pull → project → commit',
      preview: const _PullPreview(),
      title: 'Pull to Refresh',
      description:
          'Project a release to decide whether a gesture should commit.',
      routeName: PullToRefreshPage.routeName,
    ),
    _card(
      context,
      chapter: '3.3',
      pill: 'PhaseTrackController',
      icon: CupertinoIcons.rectangle_stack,
      codeHint: 'gesture → phase',
      preview: const _StackPreview(),
      title: 'Card Stack',
      description:
          'Turn gesture outcomes into stable, composable motion phases.',
      routeName: CardStackPage.routeName,
    ),
    _card(
      context,
      chapter: '3.4',
      pill: 'TrackTimeline + sync',
      icon: CupertinoIcons.checkmark_seal,
      codeHint: 'track.sync(token:)',
      preview: const _PaymentPreview(),
      title: 'Payment Success',
      description:
          'Coordinate many tracks around a shared narrative checkpoint.',
      routeName: PaymentSuccessPage.routeName,
    ),
    _card(
      context,
      chapter: '3.5',
      pill: 'phases + timelines',
      icon: CupertinoIcons.airplane,
      codeHint: 'interrupt → re-book',
      preview: const _BoardingPreview(),
      title: 'Boarding Pass',
      description:
          'Combine gestures, phases, and timelines in a resilient flow.',
      routeName: BoardingPassPage.routeName,
    ),
  ];

  List<Widget> _recipeCards(BuildContext context) => [
    _card(
      context,
      chapter: '4.1',
      pill: 'FrictionMotion.project',
      icon: CupertinoIcons.rectangle_stack,
      codeHint: 'project → nearest page',
      preview: const _CarouselPreview(),
      title: 'Snap Carousel',
      description:
          'Project fling momentum before selecting the nearest snap point.',
      routeName: SnapCarouselPage.routeName,
    ),
    _card(
      context,
      chapter: '4.2',
      pill: 'SingleMotionController',
      icon: CupertinoIcons.bell,
      codeHint: 'swipe → withVelocity',
      preview: const _ToastPreview(),
      title: 'Toast',
      description: 'Preserve swipe velocity when dismissing transient content.',
      routeName: ToastPage.routeName,
    ),
    _card(
      context,
      chapter: '4.3',
      pill: 'MotionController<Offset>',
      icon: CupertinoIcons.rectangle_on_rectangle,
      codeHint: 'project → nearest corner',
      preview: const _PipPreview(),
      title: 'Picture in Picture',
      description: 'Project two-dimensional velocity toward a stable corner.',
      routeName: PictureInPicturePage.routeName,
    ),
    _card(
      context,
      chapter: '4.4',
      pill: 'MotionDraggable',
      icon: CupertinoIcons.hand_draw,
      codeHint: 'MotionDraggable(motion: ...)',
      preview: const _DragPreview(),
      title: 'Draggable Icons',
      description:
          'Add spring-backed drag and drop without manual controllers.',
      routeName: DraggableIconsPage.routeName,
    ),
  ];
}

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
        final columns = (constraints.maxWidth / _cardMaxWidth).floor().clamp(
          1,
          4,
        );
        final width =
            (constraints.maxWidth - _cardSpacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _cardSpacing,
          runSpacing: _cardSpacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _InstantPreview extends StatelessWidget {
  const _InstantPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    Widget lane(Alignment alignment) => SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(height: 2, color: t.border),
          Align(alignment: alignment, child: _dot(t, size: 18)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          lane(Alignment.centerRight),
          const SizedBox(height: 24),
          lane(Alignment.center),
        ],
      ),
    );
  }
}

class _CurvePreview extends StatelessWidget {
  const _CurvePreview();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: TrajectoryLine(
      points: [
        Offset(.05, .8),
        Offset(.42, .2),
        Offset(.5, .5),
        Offset(.95, .5),
      ],
      gradient: ExampleTheme.spectrum,
      thickness: 3,
      fade: false,
    ),
  );
}

class _SpringPreview extends StatelessWidget {
  const _SpringPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 9; i++) ...[
            Transform.translate(
              offset: Offset(0, math.sin(i * math.pi) * 8),
              child: Container(width: 2, height: 22, color: t.textSecondary),
            ),
            if (i < 8) const SizedBox(width: 6),
          ],
          const SizedBox(width: 12),
          _dot(t, size: 24),
        ],
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Stack(
      children: [
        const Padding(
          padding: EdgeInsets.all(24),
          child: TrajectoryLine(
            points: [
              Offset(.15, .8),
              Offset(.32, .38),
              Offset(.68, .22),
              Offset(.82, .5),
            ],
            gradient: ExampleTheme.spectrum,
            thickness: 3,
            fade: true,
          ),
        ),
        Align(
          alignment: const Alignment(.55, -.2),
          child: Transform.rotate(
            angle: -.14,
            child: Container(
              width: 58,
              height: 72,
              decoration: BoxDecoration(
                color: t.surfaceSolid,
                border: Border.all(color: t.borderStrong),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackPreview extends StatelessWidget {
  const _TrackPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(height: 2, color: t.border),
            Align(alignment: const Alignment(.35, 0), child: _dot(t, size: 20)),
          ],
        ),
      ),
    );
  }
}

class _TimelinePreview extends StatelessWidget {
  const _TimelinePreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final widths in const [(42.0, 76.0), (68.0, 44.0), (28.0, 88.0)])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(width: widths.$1, height: 8, color: t.textPrimary),
                  const SizedBox(width: 5),
                  Container(width: widths.$2, height: 8, color: t.borderStrong),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SyncPreview extends StatelessWidget {
  const _SyncPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Expanded(child: Container(height: 2, color: t.border)),
          Container(width: 2, height: 70, color: t.textPrimary),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [_dot(t, size: 18), const SizedBox(height: 18), _dot(t)],
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 2, color: t.border)),
        ],
      ),
    );
  }
}

class _PhasesPreview extends StatelessWidget {
  const _PhasesPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: SizedBox(
        width: 110,
        height: 90,
        child: Stack(
          children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                left: i * 14,
                top: i * 10,
                child: Container(
                  width: 76,
                  height: 52,
                  decoration: BoxDecoration(
                    color: t.surfaceSolid,
                    border: Border.all(color: t.borderStrong),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoardingPreview extends StatelessWidget {
  const _BoardingPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Container(
        width: 150,
        height: 72,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surfaceSolid,
          border: Border.all(color: t.borderStrong),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.airplane, color: t.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 58, height: 7, color: t.textPrimary),
                  const SizedBox(height: 7),
                  Container(width: 38, height: 5, color: t.borderStrong),
                ],
              ),
            ),
            Container(width: 1, height: 48, color: t.border),
          ],
        ),
      ),
    );
  }
}

class _TogglePreview extends StatelessWidget {
  const _TogglePreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Container(
        width: 58,
        height: 32,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: t.textPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: _dot(t, size: 24, surface: true),
        ),
      ),
    );
  }
}

class _PullPreview extends StatelessWidget {
  const _PullPreview();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.arrow_clockwise,
            size: 24,
            color: t.textSecondary,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(height: 7, color: t.border),
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
                child: Container(
                  width: 80,
                  height: 56,
                  decoration: BoxDecoration(
                    color: t.surfaceSolid,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.border),
                  ),
                ),
              ),
          ],
        ),
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
        width: 50,
        height: 50,
        decoration: BoxDecoration(color: t.textPrimary, shape: BoxShape.circle),
        child: Icon(CupertinoIcons.checkmark, color: t.surfaceSolid, size: 24),
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
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Container(
                width: i == 1 ? 54 : 46,
                height: i == 1 ? 82 : 70,
                decoration: BoxDecoration(
                  color: t.surfaceSolid,
                  border: Border.all(color: i == 1 ? t.borderStrong : t.border),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
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
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: t.surfaceSolid,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _dot(t, size: 24),
              const SizedBox(width: 10),
              Container(width: 64, height: 7, color: t.borderStrong),
            ],
          ),
        ),
      ),
    );
  }
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
          width: 80,
          height: 52,
          decoration: BoxDecoration(
            color: t.textPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            CupertinoIcons.play_fill,
            color: t.surfaceSolid,
            size: 18,
          ),
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
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: t.surfaceSolid,
              shape: BoxShape.circle,
              border: Border.all(color: t.border),
            ),
            child: Icon(
              CupertinoIcons.heart_fill,
              color: t.textPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 24),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.borderStrong),
            ),
            child: Icon(CupertinoIcons.add, color: t.textTertiary, size: 16),
          ),
        ],
      ),
    );
  }
}

Widget _dot(ExampleTheme t, {double size = 14, bool surface = false}) =>
    Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surface ? t.surfaceSolid : t.textPrimary,
        shape: BoxShape.circle,
      ),
    );
