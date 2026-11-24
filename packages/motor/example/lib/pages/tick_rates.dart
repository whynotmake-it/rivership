import 'dart:async';

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/style.dart';

/// The same looping animation at four tick rates, with the builds per second
/// each one actually costs.
class TickRatesPage extends StatefulWidget {
  const TickRatesPage({super.key});

  @override
  State<TickRatesPage> createState() => _TickRatesPageState();
}

const _motion = Motion.cupertino(
  duration: Duration(milliseconds: 900),
  bounce: .2,
);

const _dot = 16.0;

final _position = Track(MotionConverter.single, debugLabel: 'Tick rate dot');

class _Lane {
  const _Lane(this.label, this.rate);

  final String label;
  final TickerRate rate;
}

final _lanes = [
  const _Lane('Every frame', TickerRate.vsync()),
  _Lane('30 fps', TickerRate.fps(30)),
  _Lane('15 fps', TickerRate.fps(15)),
  _Lane('8 fps', TickerRate.fps(8)),
];

const _code =
    'TrackBuilder(\n'
    '  tickerRate: .fps(15),\n'
    '  loop: .pingPong,\n'
    '  animations: [dot([.to(1)])],\n'
    '  builder: …,\n'
    ')\n'
    '\n'
    '// Or set one rate for a whole subtree:\n'
    'TickerRateScope(rate: .fps(30), child: …)';

class _TickRatesPageState extends State<TickRatesPage> {
  final _snippet = ValueNotifier(_code);
  var _playing = true;

  @override
  void dispose() {
    _snippet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gap = CoilTheme.metricsOf(context).gap;
    return ChapterPage(
      chapter: chapterNamed('Tick rates'),
      lead:
          'The same looping animation at different tick rates, with '
          'fixed_ticker. Fewer frames means less work for animations that '
          "don't need every frame.",
      stageHeight: 340,
      code: _snippet,
      stage: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TickerMode(
                enabled: _playing,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [for (final lane in _lanes) _LaneView(lane: lane)],
                ),
              ),
            ),
            SizedBox(height: gap),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CoilSwitch(
                value: _playing,
                onChanged: (value) => setState(() => _playing = value),
                label: const Text('Playing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One lane: a label, the builds per second it measured, and the track.
class _LaneView extends StatefulWidget {
  const _LaneView({required this.lane});

  final _Lane lane;

  @override
  State<_LaneView> createState() => _LaneViewState();
}

class _LaneViewState extends State<_LaneView> {
  final _buildsPerSecond = ValueNotifier(0);
  late final Timer _timer;
  var _builds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _buildsPerSecond.value = _builds;
      _builds = 0;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _buildsPerSecond.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final readout = mono(
      11,
      color: colors.mutedForeground,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.lane.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.muted.caption,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _buildsPerSecond,
              builder: (context, builds, _) =>
                  Text('$builds/s', textAlign: TextAlign.end, style: readout),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TrackBuilder(
          debugLabel: 'Tick rate ${widget.lane.label}',
          tickerRate: widget.lane.rate,
          loop: .pingPong,
          animations: [
            _position([.to(1, motion: _motion)]),
          ],
          builder: (context, value, _) {
            _builds++;
            return _LaneTrack(progress: value(_position));
          },
        ),
      ],
    );
  }
}

class _LaneTrack extends StatelessWidget {
  const _LaneTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return SizedBox(
      height: _dot,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = (constraints.maxWidth - _dot).clamp(0.0, 1e6);
          return Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(
                      color: colors.border,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: travel * progress,
                top: 0,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: const CircleBorder(),
                    color: colors.foreground,
                  ),
                  child: const SizedBox.square(dimension: _dot),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
