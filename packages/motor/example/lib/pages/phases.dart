import 'package:auto_route/auto_route.dart';
import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:motor/motor.dart';
import 'package:motor_example/pages/card_stack.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

enum _Panel { compact, expanded }

/// Names complete UI states and lets each track settle at phase boundaries.
class PhasesPage extends StatefulWidget {
  const PhasesPage({super.key});

  static const routeName = 'Phases';

  @override
  State<PhasesPage> createState() => _PhasesPageState();
}

class _PhasesPageState extends State<PhasesPage>
    with TickerProviderStateMixin {
  final _size = Track<double>(.single, initial: 0, motion: .smoothSpring());
  final _lift = Track<Offset>(
    .offset,
    initial: Offset.zero,
    motion: .bouncySpring(),
  );
  final _tint = Track<Color>(
    .colorRgb,
    initial: CupertinoColors.systemGrey,
    motion: .smoothSpring(),
  );

  // Timelines compare by value: "building an equal timeline on rebuild will
  // not restart playback in TrackBuilder", so hoisting this value is safe.
  // Phase boundaries are automatic sync barriers: every track settles before
  // the next named state begins.
  late final _timeline = TrackPhaseTimeline<_Panel>(
    {
      _Panel.compact: [
        _size.to(0),
        _lift.to(Offset.zero),
        _tint.to(CupertinoColors.systemGrey),
      ],
      _Panel.expanded: [
        _size.to(1),
        _lift.to(const Offset(0, -18)),
        _tint.to(ExampleTheme.spectrumRed),
      ],
    },
    phaseLoop: LoopMode.loop,
    from: [
      _size.value(0),
      _lift.value(Offset.zero),
      _tint.value(CupertinoColors.systemGrey),
    ],
  );

  final _freePosition = Track<double>(.single, initial: 0);
  final _scrubProgress = Track<double>(.single, initial: 0);
  late final _controller = PhaseTrackController<_Panel>(vsync: this);
  late final _scrubTimeline = TrackPhaseTimeline<_Panel>(
    {
      _Panel.compact: [
        _scrubProgress.to(
          0,
          motion: .linear(Duration(milliseconds: 500)),
        ),
      ],
      _Panel.expanded: [
        _scrubProgress.to(
          1,
          motion: .linear(Duration(milliseconds: 500)),
        ),
      ],
    },
    phaseLoop: LoopMode.loop,
  );

  _Panel _phase = _Panel.compact;
  bool _playing = false;
  String _status = 'waiting for a transition';
  double _scrubValue = 0;

  @override
  void initState() {
    super.initState();
    _controller.playPhases(_scrubTimeline);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePhase() {
    if (_playing) return;
    setState(() {
      _phase = _phase == _Panel.compact
          ? _Panel.expanded
          : _Panel.compact;
    });
  }

  void _onTransition(PhaseTransition<_Panel> transition) {
    final status = switch (transition) {
      PhaseTransitioning(:final from, :final to) =>
        'PhaseTransitioning(${from.name} → ${to.name})',
      PhaseSettled(:final phase) => 'PhaseSettled(${phase.name})',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _status = status);
    });
  }

  void _onPanStart(DragStartDetails _) {
    _controller.stop(tracks: [_freePosition], canceled: true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final next = (_controller.value<double>(_freePosition) + details.delta.dx)
        .clamp(-120.0, 120.0);
    _controller.set([_freePosition.value(next)]);
  }

  void _onPanEnd(DragEndDetails details) {
    _controller.animate([
      _freePosition(
        [
          .free(
            motion: const FrictionMotion(
              drag: 0.01,
              constantDeceleration: 900,
            ),
          ),
          .to(0, motion: .bouncySpring()),
        ],
        withVelocity: details.velocity.pixelsPerSecond.dx,
      ),
    ]);
  }

  void _scrub(double value) {
    setState(() => _scrubValue = value);
    // scrubTo seeks currently live tracks. After a canceled stop there are no
    // active tracks to seek, so it is intentionally a no-op.
    _controller.scrubTo(
      Duration(milliseconds: (value * 500).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ExampleTheme.of(context);
    return ExamplePage(
      title: PhasesPage.routeName,
      next: (label: 'Toggle', routeName: 'Toggle'),
      description:
          'Barriers coordinate steps inside one plan; phases name whole UI '
          'states and choose the plan for each transition.',
      action: Row(
        children: [
          CupertinoSwitch(
            key: const ValueKey('auto-play'),
            value: _playing,
            activeTrackColor: theme.textPrimary,
            onChanged: (value) => setState(() => _playing = value),
          ),
          const SizedBox(width: 10),
          const Text('play automatically'),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            key: const ValueKey('phase-card'),
            onTap: _togglePhase,
            child: PhaseTrackBuilder<_Panel>(
              currentPhase: _phase,
              playing: _playing,
              timeline: _timeline,
              onTransition: _onTransition,
              builder: (context, value, phase, _) {
                final expansion = value<double>(_size);
                return Transform.translate(
                  offset: value<Offset>(_lift),
                  child: Container(
                    width: 190 + expansion * 90,
                    height: 112 + expansion * 48,
                    decoration: BoxDecoration(
                      color: value<Color>(_tint),
                      borderRadius: BorderRadius.circular(20 + expansion * 8),
                      boxShadow: theme.softShadow,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(
                          CupertinoIcons.rectangle_expand_vertical,
                          color: CupertinoColors.white,
                        ),
                        Text(
                          phase.name,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            key: const ValueKey('phase-status'),
            style: TextStyle(
              color: theme.textTertiary,
              fontSize: 11,
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: const ['monospace', 'Menlo'],
            ),
          ),
          const SizedBox(height: 28),
          Surface(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'let go of the wheel',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fling the dot: friction coasts, then a spring brings it home.',
                  style: TextStyle(color: theme.textSecondary),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: SizedBox(
                    height: 44,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => Center(
                        child: Transform.translate(
                          offset: Offset(
                            _controller.value<double>(_freePosition),
                            0,
                          ),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: theme.textPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => LinearProgressIndicator(
                    value: _controller
                        .value<double>(_scrubProgress)
                        .clamp(0, 1),
                    color: theme.textPrimary,
                    backgroundColor: theme.border,
                    minHeight: 3,
                  ),
                ),
                CupertinoSlider(
                  value: _scrubValue,
                  onChanged: _scrub,
                  onChangeEnd: (_) => _controller.resume(),
                ),
                Text(
                  'scrub live phase playback',
                  style: TextStyle(
                    color: theme.textTertiary,
                    fontSize: 11,
                    fontFamily: 'JetBrains Mono',
                    fontFamilyFallback: const ['monospace', 'Menlo'],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'see it composed →',
                style: TextStyle(color: theme.textSecondary),
              ),
              const SizedBox(width: 12),
              NeutralButton(
                onPressed: () => context.navigateTo(
                  NamedRoute(CardStackPage.routeName),
                ),
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
