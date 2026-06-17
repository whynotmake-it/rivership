import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/labeled_slider.dart';
import 'package:motor_example/widgets/motion_track.dart';

/// Arc page 2. A curve is a fixed shape on a fixed clock. It looks great
/// start-to-finish, but interrupt it and it restarts from a standstill —
/// leaving a visible kink in the trajectory.
class CurveTrapPage extends StatefulWidget {
  const CurveTrapPage({super.key});
  static const routeName = 'The Curve Trap';

  @override
  State<CurveTrapPage> createState() => _CurveTrapPageState();
}

class _CurveTrapPageState extends State<CurveTrapPage>
    with TickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);
  final _value = Track(.single, initial: 0.0);

  double _durationMs = 700;

  Motion get _motion =>
      CurvedMotion(Duration(milliseconds: _durationMs.round()), Curves.easeInOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reverse() {
    final target = _controller.value(_value) >= 0.5 ? 0.0 : 1.0;
    _controller.animate([_value.to(target, motion: _motion)]);
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: CurveTrapPage.routeName,
      description:
          'This handle moves on a curve. Drag, then immediately drag the other '
          'way — or hit "Reverse mid-flight" while it is still moving. Every '
          'interruption snaps velocity to zero and starts over, kinking the '
          'line.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: NeutralButton(
          onPressed: _reverse,
          child: const Text('Reverse mid-flight'),
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
            const SizedBox(height: 20),
            LabeledSlider(
              label: 'Duration',
              value: _durationMs,
              min: 150,
              max: 1200,
              valueLabel: '${_durationMs.round()}ms',
              onChanged: (v) => setState(() => _durationMs = v),
            ),
            const SizedBox(height: 14),
            const TakeawayText(
              'The curve does not know you were moving — it always starts '
              'from a standstill.',
            ),
          ],
        ),
      ),
    );
  }
}
