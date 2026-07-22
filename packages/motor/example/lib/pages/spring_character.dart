import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/labeled_slider.dart';
import 'package:motor_example/widgets/phone_frame.dart';
import 'package:motor_example/widgets/value_recording_notifier.dart';

/// Lets one draggable sheet express several spring personalities.
class SpringCharacterPage extends StatefulWidget {
  const SpringCharacterPage({super.key});

  static const routeName = 'Spring Character';

  @override
  State<SpringCharacterPage> createState() => _SpringCharacterPageState();
}

class _SpringCharacterPageState extends State<SpringCharacterPage>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);
  final _sheet = Track(.single, initial: 0.0);
  final _trace = ValueRecordingNotifier();

  static const _dragTravel = 273.0;
  double _durationMs = 500;
  double _bounce = 0;
  Motion? _presetMotion;

  Motion get _motion =>
      _presetMotion ??
      CupertinoMotion(
        duration: Duration(milliseconds: _durationMs.round()),
        bounce: _bounce,
      );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_recordFrame);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_recordFrame)
      ..dispose();
    _trace.dispose();
    super.dispose();
  }

  void _recordFrame() => _trace.record(_controller.value(_sheet));

  void _onDragStart(DragStartDetails _) {
    _controller.stop(canceled: true);
    _trace.reset();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // Track the finger 1:1 with `set`, which records live velocity on the
    // controller for the release.
    final next = (_controller.value(_sheet) - details.delta.dy / _dragTravel)
        .clamp(0.0, 1.0);
    _controller.set([_sheet.value(next)]);
  }

  void _onDragEnd(DragEndDetails details) {
    final normalizedVelocity =
        -details.velocity.pixelsPerSecond.dy / _dragTravel;
    final position = _controller.value(_sheet);
    final target = normalizedVelocity.abs() > 1
        ? (normalizedVelocity > 0 ? 1.0 : 0.0)
        : (position > .5 ? 1.0 : 0.0);
    // No explicit withVelocity: the controller carries the velocity it tracked
    // during the drag into this redirect.
    _controller.animate([_sheet.to(target, motion: _motion)]);
  }

  void _setTuning({required double duration, required double bounce}) {
    setState(() {
      _durationMs = duration;
      _bounce = bounce;
      _presetMotion = null;
    });
  }

  void _setPreset({
    required Motion motion,
    required double duration,
    required double bounce,
  }) {
    setState(() {
      _durationMs = duration;
      _bounce = bounce;
      _presetMotion = motion;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: SpringCharacterPage.routeName,
      description:
          'Drag and fling one sheet, then tune its duration and bounce. Every '
          'preset receives the same artifact and the same gesture.',
      child: Surface(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                key: const ValueKey('spring-character-sheet'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => PhoneFrame(
                    width: 180,
                    child: DemoSheet(
                      value: _controller.value(_sheet),
                      grabber: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 86,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.fog,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ValueListenableBuilder<List<double>>(
                    valueListenable: _trace,
                    builder: (context, _, __) => TrajectoryLine(
                      points: _trace.toPoints(minY: -.2, maxY: 1.2),
                      gradient: ExampleTheme.spectrum,
                      thickness: 3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            LabeledSlider(
              label: 'Duration',
              value: _durationMs,
              min: 150,
              max: 1200,
              valueLabel: '${_durationMs.round()}ms',
              onChanged: (value) =>
                  _setTuning(duration: value, bounce: _bounce),
            ),
            const SizedBox(height: 8),
            LabeledSlider(
              label: 'Bounce',
              value: _bounce,
              min: 0,
              max: 1,
              onChanged: (value) =>
                  _setTuning(duration: _durationMs, bounce: value),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetButton(
                  label: '.smooth()',
                  onPressed: () => _setPreset(
                    motion: const CupertinoMotion.smooth(),
                    duration: 500,
                    bounce: 0,
                  ),
                ),
                _PresetButton(
                  label: '.bouncy()',
                  onPressed: () => _setPreset(
                    motion: const CupertinoMotion.bouncy(),
                    duration: 500,
                    bounce: .3,
                  ),
                ),
                _PresetButton(
                  label: 'Material standard',
                  onPressed: () => _setPreset(
                    motion: const MaterialSpringMotion.standardSpatialDefault(),
                    duration: 380,
                    bounce: 0,
                  ),
                ),
                _PresetButton(
                  label: 'Material expressive',
                  onPressed: () => _setPreset(
                    motion:
                        const MaterialSpringMotion.expressiveSpatialDefault(),
                    duration: 500,
                    bounce: .35,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const TakeawayText(
              'Two numbers are a personality — and the spring listens to your '
              'hand: release velocity flows straight into the simulation.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CupertinoButton(
      color: t.pebble,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      minimumSize: const Size(0, 30),
      onPressed: onPressed,
      child: Text(label, style: TextStyle(color: t.textPrimary, fontSize: 11)),
    );
  }
}
