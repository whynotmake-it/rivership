import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';

void main() {
  runApp(const CupertinoApp(
    home: VelocityTrackingExample(),
  ));
}

class VelocityTrackingExample extends StatelessWidget {
  const VelocityTrackingExample({super.key});

  static const name = 'Velocity Tracking';
  static const path = 'velocity-tracking';

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Velocity Tracking'),
      ),
      child: SafeArea(
        child: SliderControlledAnimation(),
      ),
    );
  }
}

class SliderControlledAnimation extends StatefulWidget {
  const SliderControlledAnimation({super.key});

  @override
  State<SliderControlledAnimation> createState() =>
      _SliderControlledAnimationState();
}

class _SliderControlledAnimationState extends State<SliderControlledAnimation>
    with SingleTickerProviderStateMixin {
  late final MotionController<double> _controller = MotionController<double>(
    motion: const CupertinoMotion.bouncy(),
    vsync: this,
    converter: MotionConverter.single,
    initialValue: 0.5,
    // Velocity tracking is on by default - perfect for sliders!
    // Sliders provide value changes but no velocity data
  );

  bool _isSliding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSliderChanged(double value) {
    // Slider onChange doesn't provide velocity
    // Velocity tracking records these value changes automatically
    _controller.value = value.clamp(0.0, 1.0);
  }

  void _onSliderEnd() {
    setState(() => _isSliding = false);
    // Animate to center using the tracked velocity from slider movement
    // Fast slider swipes create high velocity, slow adjustments create low
    _controller.animateTo(0.5);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content with slider centered
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            // Instructions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Drag the slider quickly and release',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 17,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text(
                'It bounces back to center with momentum',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 15,
                      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            // The slider in the center
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, child) {
                  return CupertinoSlider(
                    value: _controller.value.clamp(0.0, 1.0),
                    onChanged: (value) {
                      if (!_isSliding) {
                        setState(() => _isSliding = true);
                      }
                      _onSliderChanged(value);
                    },
                    onChangeEnd: (_) => _onSliderEnd(),
                  );
                },
              ),
            ),
            const Spacer(),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              final velocity = _controller.velocity;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _controller.isAnimating
                        ? 'Animating'
                        : _isSliding
                            ? 'Tracking'
                            : 'Idle',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                  ),
                  Text(
                    'Velocity: ${velocity.toStringAsFixed(1)}/s',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                  ),
                  const SizedBox(height: 4),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
