import 'dart:async';

import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

/// Launches the example app.
void main() => runApp(const FixedTickerExample());

/// Demonstrates [FixedTicker] with [TickerRateScope]-driven tick rates.
///
/// Two independent animations live under a single [TickerRateScope].
/// Changing the rate in the parent automatically syncs both — no
/// `updateTickerRate()` needed.
class FixedTickerExample extends StatelessWidget {
  /// Creates the example app.
  const FixedTickerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _fps = 30;
  bool _useFixedRate = true;

  static const _options = [2, 5, 10, 30, 60];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Fixed Ticker'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            const Text(
              'Two independent animations under one '
              'TickerRateScope. Both auto-sync when the '
              'rate changes.',
            ),
            const SizedBox(height: 32),
            TickerRateScope(
              rate: _useFixedRate
                  ? TickerRate.fps(_fps.toDouble())
                  : const TickerRate.vsync(),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RateLabel(),
                  SizedBox(height: 16),
                  _BlinkingCursor(),
                  SizedBox(height: 24),
                  _BouncingBall(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fixed frame rate'),
                CupertinoSwitch(
                  value: _useFixedRate,
                  onChanged: (v) => setState(() => _useFixedRate = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            IgnorePointer(
              ignoring: !_useFixedRate,
              child: AnimatedOpacity(
                opacity: _useFixedRate ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _fps,
                    onValueChanged: (v) => setState(() => _fps = v!),
                    children: {
                      for (final fps in _options) fps: Text('$fps fps'),
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const _SharedTickDemo(),
          ],
        ),
      ),
    );
  }
}

/// Reads the current [TickerRate] from the scope and displays it using
/// pattern matching.
class _RateLabel extends StatelessWidget {
  const _RateLabel();

  @override
  Widget build(BuildContext context) {
    final rate = TickerRateScope.of(context);
    final label = switch (rate) {
      VsyncTickerRate() => 'vsync',
      FixedTickerRate(:final interval) =>
        '${(1000000 / interval.inMicroseconds).round()} fps '
            '(${interval.inMilliseconds}ms)',
    };
    return Text(
      'Current rate: $label',
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}

/// A blinking text cursor driven by [AnimationController].
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleFixedTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Hello, world',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            Opacity(
              opacity: _controller.value,
              child: Container(
                width: 2,
                height: 34,
                margin: const EdgeInsets.only(left: 1, bottom: 2),
                color: CupertinoColors.activeBlue.resolveFrom(context),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A ball bouncing left-to-right, independently animated but sharing the
/// same [TickerRateScope] as [_BlinkingCursor].
class _BouncingBall extends StatefulWidget {
  const _BouncingBall();

  @override
  State<_BouncingBall> createState() => _BouncingBallState();
}

class _BouncingBallState extends State<_BouncingBall>
    with SingleFixedTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment(-1 + 2 * _controller.value, 0),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.activeOrange.resolveFrom(context),
            ),
          ),
        );
      },
    );
  }
}

/// Shows two equal-rate tickers converging on the same shared frame even when
/// the second ticker starts later.
class _SharedTickDemo extends StatefulWidget {
  const _SharedTickDemo();

  @override
  State<_SharedTickDemo> createState() => _SharedTickDemoState();
}

class _SharedTickDemoState extends State<_SharedTickDemo>
    with FixedTickerProviderStateMixin {
  late final Ticker _firstTicker;
  late final Ticker _secondTicker;
  Timer? _delayedStart;
  int _firstTicks = 0;
  int _secondTicks = 0;
  Duration? _firstFrame;
  Duration? _secondFrame;

  @override
  TickerRate get tickerRate => TickerRate.fps(2);

  bool get _isAligned =>
      _firstFrame != null &&
      _secondFrame != null &&
      _firstFrame == _secondFrame;

  @override
  void initState() {
    super.initState();
    _firstTicker = createTicker((_) => _recordTick(first: true));
    _secondTicker = createTicker((_) => _recordTick(first: false));
    unawaited(_firstTicker.start());
    _delayedStart = Timer(
      const Duration(milliseconds: 750),
      _startSecondTicker,
    );
  }

  void _recordTick({required bool first}) {
    if (!mounted) return;
    setState(() {
      final frame = SchedulerBinding.instance.currentFrameTimeStamp;
      if (first) {
        _firstTicks++;
        _firstFrame = frame;
      } else {
        _secondTicks++;
        _secondFrame = frame;
      }
    });
  }

  void _startSecondTicker() {
    if (!mounted) return;
    unawaited(_secondTicker.start());
  }

  void _restartSecondTickerLate() {
    _delayedStart?.cancel();
    if (_secondTicker.isActive) _secondTicker.stop();
    setState(() => _secondFrame = null);
    _delayedStart = Timer(
      const Duration(milliseconds: 750),
      _startSecondTicker,
    );
  }

  @override
  void dispose() {
    _delayedStart?.cancel();
    _firstTicker.dispose();
    _secondTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);
    final statusColor = _isAligned
        ? CupertinoColors.activeGreen.resolveFrom(context)
        : CupertinoColors.activeOrange.resolveFrom(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shared tick scheduling',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Ticker B starts 750ms late. Both run at 2 fps, then land on the '
            'same frame without maintaining separate timer phases.',
            style: TextStyle(fontSize: 13, color: secondaryLabel),
          ),
          const SizedBox(height: 16),
          _TickRow(label: 'Ticker A', ticks: _firstTicks),
          const SizedBox(height: 8),
          _TickRow(label: 'Ticker B', ticks: _secondTicks),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                _isAligned
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.clock,
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isAligned
                      ? 'Callbacks aligned on the same frame'
                      : 'Ticker B is joining the shared phase…',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _restartSecondTickerLate,
            child: const Text('Restart ticker B late'),
          ),
        ],
      ),
    );
  }
}

class _TickRow extends StatelessWidget {
  const _TickRow({required this.label, required this.ticks});

  final String label;
  final int ticks;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CupertinoColors.activeBlue.resolveFrom(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(
          '$ticks ticks',
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}
