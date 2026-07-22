import 'package:auto_route/auto_route.dart';
import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/pages/payment_success.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/timeline_lanes.dart';

/// Contrasts independent arrivals with tracks meeting at a sync barrier.
class SyncBarriersPage extends StatefulWidget {
  const SyncBarriersPage({super.key});

  static const routeName = 'Sync Barriers';

  @override
  State<SyncBarriersPage> createState() => _SyncBarriersPageState();
}

class _SyncBarriersPageState extends State<SyncBarriersPage>
    with SingleTickerProviderStateMixin {
  final _runner = Track<double>(.single, initial: 0);
  final _walker = Track<double>(.single, initial: 0);
  final _playhead = ValueNotifier(Duration.zero);

  late final TrackTimeline _withoutBarrier = TrackTimeline([
    _runner([
      .to(1, motion: .linear(Duration(milliseconds: 350))),
      .to(1.25, motion: .smoothSpring(duration: Duration(milliseconds: 200))),
    ]),
    _walker([
      .to(1, motion: .linear(Duration(milliseconds: 900))),
      .to(1.25, motion: .smoothSpring(duration: Duration(milliseconds: 200))),
    ]),
  ]);

  late final TrackTimeline _withBarrier = TrackTimeline([
    _runner([
      .to(1, motion: .linear(Duration(milliseconds: 350))),
      .sync(token: #meet),
      .to(1.25, motion: .smoothSpring(duration: Duration(milliseconds: 200))),
    ]),
    _walker([
      .to(1, motion: .linear(Duration(milliseconds: 900))),
      .sync(token: #meet),
      .to(1.25, motion: .smoothSpring(duration: Duration(milliseconds: 200))),
    ]),
  ]);

  late final Ticker _ticker;
  bool _barrier = true;
  int _replay = 0;

  TrackTimeline get _timeline => _barrier ? _withBarrier : _withoutBarrier;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _playhead.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    const duration = Duration(milliseconds: 1100);
    _playhead.value = elapsed > duration ? duration : elapsed;
  }

  void _restartClock() {
    _ticker
      ..stop()
      ..start();
    _playhead.value = Duration.zero;
  }

  void _setBarrier(bool value) {
    setState(() {
      _barrier = value;
      _replay++;
    });
    _restartClock();
  }

  void _replayTimeline() {
    setState(() => _replay++);
    _restartClock();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ExampleTheme.of(context);
    return ExamplePage(
      title: SyncBarriersPage.routeName,
      next: (label: 'Phases', routeName: 'Phases'),
      description:
          'Two tracks keep independent clocks until .sync(token:) makes them '
          'meet. Turn the barrier off to see each dot pop as soon as it arrives.',
      action: Row(
        children: [
          CupertinoSwitch(
            value: _barrier,
            activeTrackColor: theme.textPrimary,
            onChanged: _setBarrier,
          ),
          const SizedBox(width: 10),
          const Text('sync barrier'),
          const Spacer(),
          NeutralButton(
            onPressed: _replayTimeline,
            child: const Text('Replay'),
          ),
        ],
      ),
      child: Column(
        children: [
          Surface(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
            child: TrackBuilder(
              animations: _timeline.animations,
              restartTrigger: _replay,
              builder: (context, value, _) => Column(
                children: [
                  _RaceLane(
                    label: 'runner',
                    value: value(_runner),
                    color: ExampleTheme.spectrumRed,
                    valueKey: const ValueKey('runner-value'),
                  ),
                  const SizedBox(height: 24),
                  _RaceLane(
                    label: 'walker',
                    value: value(_walker),
                    color: theme.textPrimary,
                    valueKey: const ValueKey('walker-value'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TimelineLanes(
              timeline: _timeline,
              playhead: _playhead,
              laneLabels: {_runner: 'runner', _walker: 'walker'},
              laneColors: {
                _runner: ExampleTheme.spectrumRed,
                _walker: theme.textPrimary,
              },
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
                  NamedRoute(PaymentSuccessPage.routeName),
                ),
                child: const Text('Payment Success'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const TakeawayText(
            '.sync(token:) makes independent clocks meet; Payment Success is '
            'eight tracks converging through one barrier.',
          ),
        ],
      ),
    );
  }
}

class _RaceLane extends StatelessWidget {
  const _RaceLane({
    required this.label,
    required this.value,
    required this.color,
    required this.valueKey,
  });

  final String label;
  final double value;
  final Color color;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0, 1);
    final pop = 1 + (value - 1).clamp(0, 0.25) * 1.4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label),
            const Spacer(),
            Text(
              value.toStringAsFixed(3),
              key: valueKey,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: ['monospace', 'Menlo'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 2, color: ExampleTheme.of(context).border),
                Positioned(
                  left: progress * (constraints.maxWidth - 24),
                  child: Transform.scale(
                    scale: pop,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
