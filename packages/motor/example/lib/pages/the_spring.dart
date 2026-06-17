import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/labeled_slider.dart';
import 'package:motor_example/widgets/spring_visualizer.dart';
import 'package:motor_example/widgets/value_recording_notifier.dart';

/// Arc page 3. A spring isn't a precomputed shape — it's physics solved every
/// frame from where you are and how fast you're going. Two numbers, duration
/// and bounce, change its entire character; the graph shows the settle shape
/// shift live.
class TheSpringPage extends StatefulWidget {
  const TheSpringPage({super.key});
  static const routeName = 'The Spring';

  @override
  State<TheSpringPage> createState() => _TheSpringPageState();
}

class _TheSpringPageState extends State<TheSpringPage> {
  final _recorder = ValueRecordingNotifier();

  double _durationMs = 500;
  double _bounce = 0.2;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: TheSpringPage.routeName,
      description:
          'Drag or flick the target ring — the ball springs to it, carrying '
          'whatever speed you let go with. Tune duration and bounce and feel '
          'the same spring become calm or playful, with nothing else changed.',
      child: Surface(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: t.fog,
                borderRadius: BorderRadius.circular(ExampleTheme.previewRadius),
                border: Border.all(color: t.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: SpringVisualizer(
                duration: Duration(milliseconds: _durationMs.round()),
                bounce: _bounce,
                recorder: _recorder,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: t.fog,
                borderRadius: BorderRadius.circular(ExampleTheme.previewRadius),
                border: Border.all(color: t.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: ValueListenableBuilder<List<double>>(
                  valueListenable: _recorder,
                  builder: (context, _, __) => TrajectoryLine(
                    points: _recorder.toPoints(minY: 0, maxY: 1),
                    gradient: ExampleTheme.spectrum,
                    thickness: 3.5,
                  ),
                ),
              ),
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
            const SizedBox(height: 8),
            LabeledSlider(
              label: 'Bounce',
              value: _bounce,
              min: 0,
              max: 1,
              onChanged: (v) => setState(() => _bounce = v),
            ),
            const SizedBox(height: 14),
            const TakeawayText(
              'CupertinoMotion(duration, bounce) — same spring, many feels, '
              'always responsive to how you let go.',
            ),
          ],
        ),
      ),
    );
  }
}
