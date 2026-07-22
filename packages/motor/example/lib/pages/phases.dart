import 'package:auto_route/auto_route.dart';
import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/pages/card_stack.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// The complete, named UI states of the order card. Tapping a name on the
/// phase rail (or auto-playing) transitions the whole card to that state.
enum _OrderPhase { ordered, packed, delivered }

/// Names complete UI states and lets each track settle at phase boundaries.
class PhasesPage extends StatefulWidget {
  const PhasesPage({super.key});

  static const routeName = 'Phases';

  @override
  State<PhasesPage> createState() => _PhasesPageState();
}

class _PhasesPageState extends State<PhasesPage> {
  final _progress = Track<double>(.single, initial: 0, motion: .smoothSpring());
  final _badge = Track<double>(.single, initial: 0, motion: .smoothSpring());
  final _railX = Track<double>(
    .single,
    initial: 0,
    motion: .snappySpring(duration: Duration(milliseconds: 420)),
  );
  final _stamp = Track<double>(.single, initial: 1);

  /// The badge stamps on every phase entry: snap smaller, spring back.
  static const _stampPop = [
    TrackStep<double>.to(.72, motion: Motion.linear(Duration.zero)),
    TrackStep<double>.to(1, motion: Motion.bouncySpring()),
  ];

  // One timeline, three named states. Entering a phase plays that phase's
  // plan from the current values, and every track settles before the phase
  // reports PhaseSettled — phase boundaries are automatic sync barriers.
  late final _timeline = TrackPhaseTimeline<_OrderPhase>({
    _OrderPhase.ordered: [
      _progress.to(0),
      _badge.to(0),
      _railX.to(0),
      _stamp(_stampPop),
    ],
    _OrderPhase.packed: [
      // The controller picks this plan for whichever transition lands here —
      // packed gets a snappier progress push than the smooth default.
      _progress.to(.5, motion: .snappySpring()),
      _badge.to(.55),
      _railX.to(1),
      _stamp(_stampPop),
    ],
    _OrderPhase.delivered: [
      // Delivery is the payoff, so its plan lands with a bounce.
      _progress.to(1, motion: .bouncySpring()),
      _badge.to(1),
      _railX.to(2),
      _stamp(_stampPop),
    ],
  }, phaseLoop: LoopMode.loop);

  /// The manually requested phase (drives PhaseTrackBuilder.currentPhase).
  _OrderPhase _phase = _OrderPhase.ordered;

  /// The phase the controller last reported, mirrored without a rebuild so
  /// turning auto-play off can hand control back where playback left it.
  _OrderPhase _livePhase = _OrderPhase.ordered;

  bool _playing = false;
  String _lastEvent = 'waiting for a transition';

  void _onTransition(PhaseTransition<_OrderPhase> transition) {
    final (phase, label) = switch (transition) {
      PhaseTransitioning(:final from, :final to) => (
        to,
        'PhaseTransitioning(${from.name} → ${to.name})',
      ),
      PhaseSettled(:final phase) => (phase, 'PhaseSettled(${phase.name})'),
    };
    _livePhase = phase;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _lastEvent = label);
    });
  }

  void _selectPhase(_OrderPhase phase) {
    setState(() {
      _playing = false;
      _phase = phase;
    });
  }

  void _setPlaying(bool value) {
    setState(() {
      _playing = value;
      // Sync the manual phase to wherever playback is, so toggling play off
      // settles in place instead of jumping back to a stale phase.
      _phase = _livePhase;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ExampleTheme.of(context);
    return ExamplePage(
      title: PhasesPage.routeName,
      next: (label: 'Toggle', routeName: 'Toggle'),
      description:
          'Barriers coordinate steps inside one plan; phases name whole UI '
          'states and choose the plan for each transition. Tap a phase on '
          'the rail — the whole card settles into that named state.',
      action: Row(
        children: [
          CupertinoSwitch(
            key: const ValueKey('auto-play'),
            value: _playing,
            activeTrackColor: theme.textPrimary,
            onChanged: _setPlaying,
          ),
          const SizedBox(width: 10),
          const Text('play automatically'),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhaseTrackBuilder<_OrderPhase>(
            currentPhase: _phase,
            playing: _playing,
            timeline: _timeline,
            onTransition: _onTransition,
            builder: (context, value, phase, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stage(
                  label: 'tap a phase in the rail',
                  padding: const EdgeInsets.symmetric(vertical: 44),
                  child: Center(
                    child: _OrderCard(
                      phase: phase,
                      progress: value(_progress),
                      badge: value(_badge),
                      stamp: value(_stamp),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PhaseRail(
                  activePhase: phase,
                  position: value(_railX),
                  onSelect: _selectPhase,
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _lastEvent,
                    key: const ValueKey('phase-status'),
                    style: TextStyle(
                      color: theme.textTertiary,
                      fontSize: 11,
                      fontFamily: 'JetBrains Mono',
                      fontFamilyFallback: const ['monospace', 'Menlo'],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'see it composed →',
                style: TextStyle(color: theme.textSecondary),
              ),
              const SizedBox(width: 12),
              NeutralButton(
                onPressed: () =>
                    context.navigateTo(NamedRoute(CardStackPage.routeName)),
                child: const Text('Card Stack'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const TakeawayText(
            'Barriers synchronize within a plan; phases name whole states and '
            'choose between plans.',
          ),
        ],
      ),
    );
  }
}

/// The one artifact on this page: an order-status card whose look is fully
/// described by the phase timeline's tracks.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.phase,
    required this.progress,
    required this.badge,
    required this.stamp,
  });

  final _OrderPhase phase;
  final double progress;
  final double badge;
  final double stamp;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final (icon, subtitle) = switch (phase) {
      _OrderPhase.ordered => (CupertinoIcons.bag, 'Order placed'),
      _OrderPhase.packed => (CupertinoIcons.cube_box, 'Packed & on the way'),
      _OrderPhase.delivered => (CupertinoIcons.checkmark_alt, 'Delivered'),
    };
    final fill = badge.clamp(0.0, 1.0);
    final badgeColor = Color.lerp(t.fog, t.textPrimary, fill)!;
    final iconColor = Color.lerp(t.textPrimary, t.surfaceSolid, fill)!;

    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: ShapeDecoration(
        color: t.surfaceSolid,
        shape: RoundedSuperellipseBorder(
          side: BorderSide(color: t.border),
          borderRadius: BorderRadius.circular(24),
        ),
        shadows: t.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.scale(
                scale: stamp,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 21, color: iconColor),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #1834',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: t.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _RouteLine(progress: progress),
        ],
      ),
    );
  }
}

/// A shipment route: a progress line passing through one node per phase.
class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.progress});

  static const _nodeSize = 10.0;

  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final fraction = progress.clamp(0.0, 1.0);
    return SizedBox(
      height: _nodeSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                height: 3,
                width: fraction * width,
                decoration: BoxDecoration(
                  color: t.textPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              for (final stop in const [0.0, 0.5, 1.0])
                Positioned(
                  left: stop * (width - _nodeSize),
                  child: Container(
                    width: _nodeSize,
                    height: _nodeSize,
                    decoration: BoxDecoration(
                      color: fraction >= stop - .001
                          ? t.textPrimary
                          : t.surfaceSolid,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.borderStrong),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The phase rail: every named state as a tappable chip, with an indicator
/// that travels between them. The traveling indicator IS the transition —
/// it is driven by the same phase timeline as the card.
class _PhaseRail extends StatelessWidget {
  const _PhaseRail({
    required this.activePhase,
    required this.position,
    required this.onSelect,
  });

  final _OrderPhase activePhase;

  /// The indicator's position in cell units (0, 1, 2 at rest).
  final double position;

  final ValueChanged<_OrderPhase> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.fog,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / _OrderPhase.values.length;
          return Stack(
            children: [
              Positioned(
                left: position * cell,
                top: 0,
                bottom: 0,
                width: cell,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.surfaceSolid,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.border),
                    boxShadow: t.hairlineShadow,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final phase in _OrderPhase.values)
                    Expanded(
                      child: GestureDetector(
                        key: ValueKey('phase-chip-${phase.name}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(phase),
                        child: Center(
                          child: Text(
                            phase.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: phase == activePhase
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: phase == activePhase
                                  ? t.textPrimary
                                  : t.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
