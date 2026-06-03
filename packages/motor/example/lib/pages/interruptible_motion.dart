import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/value_recording_notifier.dart';

/// The headline demo: why continuous motion matters.
///
/// A handle chases wherever you point. A spring keeps its velocity when the
/// target changes mid-flight, so the recorded trajectory stays smooth. A curve
/// restarts from zero velocity on every redirect, leaving a visible kink.
class InterruptibleMotionPage extends StatefulWidget {
  const InterruptibleMotionPage({super.key});
  static const routeName = 'Interruptible Motion';

  @override
  State<InterruptibleMotionPage> createState() =>
      _InterruptibleMotionPageState();
}

enum _Kind { spring, curve }

late final _value = Track(.single, origin: 0.0);

class _InterruptibleMotionPageState extends State<InterruptibleMotionPage>
    with TickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);
  late final Ticker _ticker;
  final _recorder = ValueRecordingNotifier();

  _Kind _kind = _Kind.spring;

  static const _spring = CupertinoMotion.smooth(
    duration: Duration(milliseconds: 700),
  );
  static const _curve = CurvedMotion(
    Duration(milliseconds: 700),
    Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    _recorder.record(_controller.value(_value).clamp(0.0, 1.0));
  }

  Motion get _motion => _kind == _Kind.spring ? _spring : _curve;

  void _setKind(_Kind? kind) {
    if (kind == null) return;
    setState(() => _kind = kind);
  }

  void _aimAt(double target) {
    _controller..animate([_value.to(target.clamp(0.0, 1.0), motion: _motion)]);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
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
            _Graph(recorder: _recorder, isSpring: _kind == _Kind.spring),
            const SizedBox(height: 20),
            _Track(controller: _controller, onAim: _aimAt),
            const SizedBox(height: 14),
            Text(
              _kind == _Kind.spring
                  ? 'Spring · velocity preserved across targets'
                  : 'Curve · velocity resets to zero on every redirect',
              style: TextStyle(
                color: t.textTertiary,
                fontSize: 12,
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: const ['monospace', 'Menlo'],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

class _Graph extends StatelessWidget {
  const _Graph({required this.recorder, required this.isSpring});

  final ValueRecordingNotifier recorder;
  final bool isSpring;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: t.fog,
        borderRadius: BorderRadius.circular(ExampleTheme.previewRadius),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BaselinePainter(t))),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ValueListenableBuilder<List<double>>(
                valueListenable: recorder,
                builder: (context, _, __) => TrajectoryLine(
                  points: recorder.toPoints(minY: 0, maxY: 1),
                  gradient: ExampleTheme.spectrum,
                  thickness: 3.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BaselinePainter extends CustomPainter {
  _BaselinePainter(this.t);
  final ExampleTheme t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = t.border
      ..strokeWidth = 1;
    for (final f in const [0.16, 0.5, 0.84]) {
      final y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_BaselinePainter oldDelegate) => t != oldDelegate.t;
}

class _Track extends StatelessWidget {
  const _Track({required this.controller, required this.onAim});

  final TrackController controller;
  final ValueChanged<double> onAim;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const handle = 36.0;
        void aim(Offset local) =>
            onAim(((local.dx - handle / 2) / (width - handle)).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => aim(d.localPosition),
          onHorizontalDragStart: (d) => aim(d.localPosition),
          onHorizontalDragUpdate: (d) => aim(d.localPosition),
          child: SizedBox(
            height: handle,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final value = controller.value(_value).clamp(0.0, 1.0);
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      left: value * (width - handle),
                      child: Container(
                        width: handle,
                        height: handle,
                        decoration: BoxDecoration(
                          color: t.textPrimary,
                          shape: BoxShape.circle,
                          boxShadow: t.softShadow,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
