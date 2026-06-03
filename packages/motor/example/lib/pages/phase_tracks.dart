import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

const _routeName = 'Phase Tracks';

enum _PanelPhase { compact, expanded, focus }

final _panelAlignment = Track<Alignment>(
  .alignment,
  zero: Alignment.topLeft,
  motion: .smoothSpring(duration: Duration(milliseconds: 520)),
);
final _panelSize = Track<Size>(
  .size,
  zero: Size(172, 128),
  motion: .bouncySpring(
    duration: Duration(milliseconds: 580),
    extraBounce: .03,
  ),
);
final _panelRadius = Track<double>(
  .single,
  zero: 24,
  motion: .smoothSpring(duration: Duration(milliseconds: 520)),
);
final _panelGlow = Track<double>(
  .single,
  zero: .2,
  motion: .smoothSpring(duration: Duration(milliseconds: 520)),
);
final _panelTint = Track<Color>(
  .colorRgb,
  zero: Color(0xFF0A84FF),
  motion: .smoothSpring(duration: Duration(milliseconds: 420)),
);

class PhaseTracksPage extends StatefulWidget {
  const PhaseTracksPage({super.key});
  static const routeName = _routeName;

  @override
  State<PhaseTracksPage> createState() => _PhaseTracksPageState();
}

class _PhaseTracksPageState extends State<PhaseTracksPage>
    with SingleTickerProviderStateMixin {
  static const Map<_PanelPhase, Widget> _segments = {
    .compact: Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Text('Compact'),
    ),
    .expanded: Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Text('Expanded'),
    ),
    .focus: Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Text('Focus'),
    ),
  };

  late final PhaseTrackController<_PanelPhase> _controller;
  var _phase = _PanelPhase.compact;
  var _autoplay = false;

  @override
  void initState() {
    super.initState();
    _controller = PhaseTrackController<_PanelPhase>(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TrackPhaseTimeline<_PanelPhase> _buildTimeline(ExampleTheme t) {
    return TrackPhaseTimeline({
      _PanelPhase.compact: [
        _panelAlignment.to(Alignment.topLeft),
        _panelSize.to(const Size(172, 128)),
        _panelRadius.to(24.0),
        _panelGlow.to(.2),
        _panelTint.to(t.accentBlue),
      ],
      _PanelPhase.expanded: [
        _panelAlignment.to(Alignment.center),
        _panelSize.to(const Size(292, 180)),
        _panelGlow.to(.55),
        _panelTint.to(t.accentPurple),
      ],
      _PanelPhase.focus: [
        _panelAlignment.to(Alignment.bottomRight),
        _panelSize.to(const Size(224, 256)),
        _panelRadius.to(0.0),
        _panelGlow.to(.9),
        _panelTint.to(t.accentGreen),
      ],
    }, phaseLoop: _autoplay ? LoopMode.loop : LoopMode.none);
  }

  void _onPhaseSelected(_PanelPhase? phase) {
    if (phase == null) return;
    setState(() {
      _autoplay = false;
      _phase = phase;
    });
    final t = ExampleTheme.of(context);
    _controller.setTimeline(_buildTimeline(t));
    _controller.goToPhase(phase);
  }

  void _toggleAutoplay() {
    setState(() => _autoplay = !_autoplay);
    final t = ExampleTheme.of(context);
    final timeline = _buildTimeline(t);
    if (_autoplay) {
      _controller.playPhases(
        timeline,
        atPhase: _phase,
        onTransition: (transition) => setState(() {
          _phase = switch (transition) {
            PhaseTransitioning(:final to) => to,
            PhaseSettled(:final phase) => phase,
          };
        }),
      );
    } else {
      _controller.setTimeline(timeline);
      _controller.goToPhase(_phase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);

    // Kick off initial playback on first build
    if (!_controller.isAnimating && _controller.activeTimeline == null) {
      _controller.setTimeline(_buildTimeline(t));
      _controller.goToPhase(_phase);
    }

    return ExamplePage(
      title: _routeName,
      description:
          'PhaseTrackController plays phases imperatively. '
          'Toggle autoplay to loop through all phases, or pick one manually. '
          'Tapping a segment interrupts autoplay.',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            onPressed: _toggleAutoplay,
            padding: EdgeInsets.zero,
            child: Icon(
              _autoplay
                  ? CupertinoIcons.pause_circle_fill
                  : CupertinoIcons.play_circle_fill,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSlidingSegmentedControl<_PanelPhase>(
            groupValue: _phase,
            children: _segments,
            onValueChanged: _onPhaseSelected,
          ),
        ],
      ),
      child: SizedBox(
        height: 360,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, child) {
            final value = _controller.value;
            final alignment = value<Alignment>(_panelAlignment);
            final size = value<Size>(_panelSize);
            final radius = value<double>(_panelRadius);
            final glow = value<double>(_panelGlow);
            final tint = value<Color>(_panelTint);

            return Stage(
              child: Align(
                alignment: alignment,
                child: _PhasePanel(
                  size: size,
                  radius: radius,
                  glow: glow,
                  tint: tint,
                  phase: _phase,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PhasePanel extends StatelessWidget {
  const _PhasePanel({
    required this.size,
    required this.radius,
    required this.glow,
    required this.tint,
    required this.phase,
  });

  final Size size;
  final double radius;
  final double glow;
  final Color tint;
  final _PanelPhase phase;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: tint.withValues(alpha: .55)),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: glow * .34),
              blurRadius: 44 * glow,
              spreadRadius: 8 * glow,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(CupertinoIcons.rectangle_stack_fill, color: tint, size: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phase.name,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Alignment, size, radius, glow, and tint are independent '
                    'tracks.',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
