import 'dart:async';

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/phone_frame.dart';
import 'package:motor_example/widgets/value_recording_notifier.dart';

/// Shows how a fixed-clock curve and a spring react to the same interruption.
class CurveTrapEscapePage extends StatefulWidget {
  const CurveTrapEscapePage({super.key});

  static const routeName = 'The Curve Trap';

  @override
  State<CurveTrapEscapePage> createState() => _CurveTrapEscapePageState();
}

enum _MotionKind { curve, spring }

class _CurveTrapEscapePageState extends State<CurveTrapEscapePage>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);
  final _sheet = Track(.single, initial: 0.0);
  final _positionTrace = ValueRecordingNotifier();
  final _velocityTrace = ValueRecordingNotifier();

  static const _curve = CurvedMotion(
    Duration(milliseconds: 700),
    Curves.easeInOut,
  );
  static const _spring = CupertinoMotion.smooth(
    duration: Duration(milliseconds: 700),
  );

  _MotionKind _kind = _MotionKind.curve;
  bool _open = false;
  Timer? _reversalTimer;

  Motion get _motion => _kind == _MotionKind.curve ? _curve : _spring;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_recordFrame);
  }

  @override
  void dispose() {
    _reversalTimer?.cancel();
    _controller
      ..removeListener(_recordFrame)
      ..dispose();
    _positionTrace.dispose();
    _velocityTrace.dispose();
    super.dispose();
  }

  void _recordFrame() {
    _positionTrace.record(_controller.value(_sheet));
    _velocityTrace.record(_controller.velocity(_sheet));
  }

  void _setKind(_MotionKind? kind) {
    if (kind == null) return;
    _reversalTimer?.cancel();
    _controller.stop(canceled: true);
    _controller.set([_sheet.value(0)]);
    _positionTrace.reset();
    _velocityTrace.reset();
    setState(() {
      _kind = kind;
      _open = false;
    });
  }

  void _toggle() {
    _reversalTimer?.cancel();
    setState(() => _open = !_open);
    _controller.animate([_sheet.to(_open ? 1 : 0, motion: _motion)]);
  }

  void _reverseAtFortyPercent() {
    _reversalTimer?.cancel();
    _controller
      ..set([_sheet.value(0)])
      ..animate([_sheet.to(1, motion: _motion)]);
    _positionTrace.reset();
    _velocityTrace.reset();
    setState(() => _open = true);
    _reversalTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _open = false);
      _controller.animate([_sheet.to(0, motion: _motion)]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: CurveTrapEscapePage.routeName,
      description:
          'Interrupt the same sheet under a curve and a spring. The curve '
          'restarts its clock; the spring re-solves from live velocity.',
      action: CupertinoSlidingSegmentedControl<_MotionKind>(
        groupValue: _kind,
        backgroundColor: t.fog,
        thumbColor: t.surfaceSolid,
        onValueChanged: _setKind,
        children: {
          _MotionKind.curve: _segment('700ms curve', t),
          _MotionKind.spring: _segment('700ms spring', t),
        },
      ),
      child: Surface(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => PhoneFrame(
                  width: 180,
                  child: DemoSheet(value: _controller.value(_sheet)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                CupertinoButton.filled(
                  onPressed: _toggle,
                  child: Text(_open ? 'Close' : 'Open'),
                ),
                CupertinoButton(
                  color: t.pebble,
                  onPressed: _reverseAtFortyPercent,
                  child: Text(
                    'Reverse at 40%',
                    style: TextStyle(color: t.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _TraceStrip(
              label: 'position',
              recorder: _positionTrace,
              minY: -.2,
              maxY: 1.2,
            ),
            const SizedBox(height: 8),
            _TraceStrip(
              label: 'velocity',
              recorder: _velocityTrace,
              minY: -4,
              maxY: 4,
            ),
            const SizedBox(height: 16),
            const TakeawayText(
              'A curve is a fixed shape on a fixed clock — it does not know '
              'you were moving. A spring is re-solved every frame from live '
              'position and velocity.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, ExampleTheme t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Text(
      label,
      style: TextStyle(
        color: t.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _TraceStrip extends StatelessWidget {
  const _TraceStrip({
    required this.label,
    required this.recorder,
    required this.minY,
    required this.maxY,
  });

  final String label;
  final ValueRecordingNotifier recorder;
  final double minY;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return SizedBox(
      height: 74,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.fog,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ValueListenableBuilder<List<double>>(
                valueListenable: recorder,
                builder: (context, _, __) => TrajectoryLine(
                  points: recorder.toPoints(minY: minY, maxY: maxY),
                  gradient: ExampleTheme.spectrum,
                  thickness: 3,
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 8,
              child: Text(
                label,
                style: TextStyle(
                  color: t.textTertiary,
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: const ['monospace', 'Menlo'],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
