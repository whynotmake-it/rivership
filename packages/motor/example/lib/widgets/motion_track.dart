import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/value_recording_notifier.dart';

/// A reusable "drag a handle along a track, watch its trajectory" instrument.
///
/// Dragging or tapping the rail aims the handle at a new target using
/// [motion]; the value is sampled every frame and drawn as a live trajectory
/// above the rail. Swapping [motion] (e.g. spring vs curve) changes how every
/// subsequent redirect feels, so the graph tells the story.
///
/// The caller owns the [controller] and [track] so it can read
/// `controller.velocity(track)` for extra readouts and choose the [motion].
class MotionTrack extends StatefulWidget {
  const MotionTrack({
    required this.controller,
    required this.track,
    required this.motion,
    this.gradient = ExampleTheme.spectrum,
    this.graphHeight = 180,
    super.key,
  });

  final TrackController controller;
  final Track<double> track;
  final Motion motion;
  final Gradient gradient;
  final double graphHeight;

  @override
  State<MotionTrack> createState() => _MotionTrackState();
}

class _MotionTrackState extends State<MotionTrack>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _recorder = ValueRecordingNotifier();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    _recorder.record(widget.controller.value(widget.track).clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _aim(double target) {
    widget.controller.animate([
      widget.track.to(target.clamp(0.0, 1.0), motion: widget.motion),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: widget.graphHeight,
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
                    valueListenable: _recorder,
                    builder: (context, _, __) => TrajectoryLine(
                      points: _recorder.toPoints(minY: 0, maxY: 1),
                      gradient: widget.gradient,
                      thickness: 3.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Rail(controller: widget.controller, track: widget.track, onAim: _aim),
      ],
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

class _Rail extends StatelessWidget {
  const _Rail({
    required this.controller,
    required this.track,
    required this.onAim,
  });

  final TrackController controller;
  final Track<double> track;
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
                final value = controller.value(track).clamp(0.0, 1.0);
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
