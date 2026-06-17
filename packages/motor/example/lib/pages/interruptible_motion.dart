import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/motion_track.dart';

/// The payoff of the arc: because a spring is recomputed from live velocity,
/// redirecting it mid-flight is seamless. Drag the handle around and the spring
/// stays one continuous line; the curve restarts from a standstill on every
/// redirect, leaving a visible kink.
class InterruptibleMotionPage extends StatefulWidget {
  const InterruptibleMotionPage({super.key});
  static const routeName = 'Carry the Momentum';

  @override
  State<InterruptibleMotionPage> createState() =>
      _InterruptibleMotionPageState();
}

enum _Kind { spring, curve }

class _InterruptibleMotionPageState extends State<InterruptibleMotionPage>
    with TickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);
  final _value = Track(.single, initial: 0.0);

  _Kind _kind = _Kind.spring;

  static const _spring = CupertinoMotion.smooth(
    duration: Duration(milliseconds: 700),
  );
  static const _curve = CurvedMotion(
    Duration(milliseconds: 700),
    Curves.easeInOut,
  );

  Motion get _motion => _kind == _Kind.spring ? _spring : _curve;

  void _setKind(_Kind? kind) {
    if (kind == null) return;
    setState(() => _kind = kind);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final isSpring = _kind == _Kind.spring;
    return ExamplePage(
      title: InterruptibleMotionPage.routeName,
      description:
          'Drag across the track to keep redirecting the handle. A spring '
          'carries its momentum into each new target, so the graph stays one '
          'continuous line. A curve restarts on every redirect, leaving a '
          'sharp velocity break.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: CupertinoSlidingSegmentedControl<_Kind>(
          groupValue: _kind,
          backgroundColor: t.fog,
          thumbColor: t.surfaceSolid,
          onValueChanged: _setKind,
          children: {
            _Kind.spring: _segment('Spring', t),
            _Kind.curve: _segment('Curve', t),
          },
        ),
      ),
      child: Surface(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MotionTrack(
              controller: _controller,
              track: _value,
              motion: _motion,
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final v = _controller.velocity(_value);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isSpring
                          ? 'Spring · velocity preserved across targets'
                          : 'Curve · velocity resets to zero on every redirect',
                      style: _mono(t),
                    ),
                    Text('v ${v.toStringAsFixed(2)}', style: _mono(t)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _mono(ExampleTheme t) => TextStyle(
    color: t.textTertiary,
    fontSize: 12,
    fontFamily: 'JetBrains Mono',
    fontFamilyFallback: const ['monospace', 'Menlo'],
  );

  Widget _segment(String label, ExampleTheme t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: t.textPrimary,
      ),
    ),
  );
}
