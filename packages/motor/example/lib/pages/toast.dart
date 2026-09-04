import 'dart:async';

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// A notification banner that springs in from the top and can be flicked away.
///
/// One controller animates a 0..1 reveal; a vertical drag feeds its release
/// velocity into the spring so a quick flick up dismisses naturally.
class ToastPage extends StatefulWidget {
  const ToastPage({super.key});
  static const routeName = 'Toast';

  @override
  State<ToastPage> createState() => _ToastPageState();
}

class _ToastPageState extends State<ToastPage> with TickerProviderStateMixin {
  static const _height = 84.0;
  late final SingleMotionController _reveal;
  Timer? _autoDismiss;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _reveal = SingleMotionController(
      motion: const CupertinoMotion.bouncy(),
      vsync: this,
      initialValue: 0,
    );
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  void _show() {
    setState(() => _count++);
    _reveal.animateTo(1);
    _autoDismiss?.cancel();
    _autoDismiss = Timer(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss({double velocity = 0}) {
    _autoDismiss?.cancel();
    _reveal.animateTo(0, withVelocity: velocity / _height);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _autoDismiss?.cancel();
    _reveal.value = (_reveal.value + d.delta.dy / _height).clamp(0.0, 1.05);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (v < -200 || _reveal.value < 0.6) {
      _dismiss(velocity: v);
    } else {
      _reveal.animateTo(1, withVelocity: v / _height);
      _autoDismiss = Timer(const Duration(seconds: 3), _dismiss);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: ToastPage.routeName,
      description:
          'A notification that springs down from the top. Flick it upward to '
          'dismiss — the gesture velocity is handed to the spring, so a fast '
          'swipe leaves quickly and a gentle one eases back.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: NeutralButton(onPressed: _show, child: const Text('Notify')),
      ),
      child: SizedBox(
        height: 360,
        child: Stage(
          glow: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) {
                final v = _reveal.value;
                return Transform.translate(
                  offset: Offset(0, (v.clamp(0.0, 1.05) - 1) * (_height + 24)),
                  child: Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: GestureDetector(
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: _Toast(count: _count, height: _height),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.count, required this.height});
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: t.surfaceSolid,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
        boxShadow: t.softShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.fog, shape: BoxShape.circle),
            child: Icon(CupertinoIcons.bell_fill,
                size: 20, color: t.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New message',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Delivered ${count == 0 ? 'just now' : '$count× now'} · swipe up',
                  style: TextStyle(color: t.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: t.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}
