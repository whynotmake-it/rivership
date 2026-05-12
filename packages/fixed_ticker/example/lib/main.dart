import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/cupertino.dart';

/// Launches the example app.
void main() => runApp(const FixedTickerExample());

/// Demonstrates [FixedTicker] with [TickerRateScope]-driven tick rates.
///
/// Two independent animations live under a single [TickerRateScope].
/// Changing the rate in the parent automatically syncs both — no
/// `updateTickerInterval()` needed.
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
            ],
          ),
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
    _controller.addListener(() {
      debugPrint('ball value: ${_controller.value}');
    });
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
