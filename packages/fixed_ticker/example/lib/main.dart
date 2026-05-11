import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/cupertino.dart';

/// Launches the example app.
void main() => runApp(const FixedTickerExample());

/// Demonstrates [FixedTicker] by showing a blinking cursor at different fps.
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
                'A blinking cursor driven by AnimationController, '
                'ticking at a fixed frame rate instead of vsync.',
              ),
              const SizedBox(height: 32),
              _BlinkingCursor(key: ValueKey(_fps), fps: _fps),
              const SizedBox(height: 32),
              const Text('Frame rate'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _fps,
                  onValueChanged: (v) => setState(() => _fps = v!),
                  children: {
                    for (final fps in _options)
                      fps: Text('$fps fps'),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({required this.fps, super.key});

  final int fps;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleFixedTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  Duration get tickerInterval =>
      Duration(milliseconds: 1000 ~/ widget.fps);

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
