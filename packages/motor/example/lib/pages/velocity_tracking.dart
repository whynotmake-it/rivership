import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

class VelocityTrackingPage extends StatefulWidget {
  const VelocityTrackingPage({super.key});
  static const routeName = 'Velocity Tracking';

  @override
  State<VelocityTrackingPage> createState() => _VelocityTrackingPageState();
}

class _VelocityTrackingPageState extends State<VelocityTrackingPage>
    with TickerProviderStateMixin {
  late final SingleMotionController _controller;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _controller = SingleMotionController(
      motion: const CupertinoMotion.bouncy(),
      vsync: this,
      initialValue: 0.5,
    );
    _controller.addListener(_onUpdate);
    _controller.addStatusListener(_onStatusChanged);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _onStatusChanged(AnimationStatus status) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _stateLabel {
    if (_isTracking) return 'Tracking';
    if (_controller.isAnimating) return 'Animating';
    return 'Idle';
  }

  Color _stateColor(ExampleTheme t) {
    if (_isTracking) return t.accentGreen;
    if (_controller.isAnimating) return t.accentPurple;
    return t.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final value = _controller.value.clamp(0.0, 1.0);
    final velocity = _controller.velocities.first;
    final stateColor = _stateColor(t);

    return ExamplePage(
      title: VelocityTrackingPage.routeName,
      description:
          'Drag the slider quickly and release. The value bounces back '
          'to center with momentum from tracked velocity.',
      action: const SizedBox.shrink(),
      child: Column(
        children: [
          Surface(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        LiveDot(color: stateColor),
                        const SizedBox(width: 8),
                        Text(
                          _stateLabel,
                          style: TextStyle(
                            color: stateColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'v: ${velocity.toStringAsFixed(1)} /s',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final trackWidth = constraints.maxWidth;
                      return GestureDetector(
                        onHorizontalDragStart: (_) {
                          setState(() => _isTracking = true);
                        },
                        onHorizontalDragUpdate: (details) {
                          final delta = details.delta.dx / trackWidth;
                          final newValue =
                              (_controller.value + delta).clamp(0.0, 1.0);
                          _controller.value = newValue;
                        },
                        onHorizontalDragEnd: (_) {
                          setState(() => _isTracking = false);
                          _controller.animateTo(0.5);
                        },
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: t.borderSubtle,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Positioned(
                              left: value * (trackWidth - 40),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: t.accentBlue,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          t.accentBlue.withValues(alpha: .3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Value: ${value.toStringAsFixed(3)}',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
