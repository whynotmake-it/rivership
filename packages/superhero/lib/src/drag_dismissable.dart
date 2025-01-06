import 'package:flutter/material.dart';
import 'package:springster/springster.dart';
import 'package:superhero/src/superhero_velocity.dart';
import 'package:superhero/superhero.dart';

class DragDismissable extends StatefulWidget {
  const DragDismissable({
    super.key,
    required this.child,
    this.onDismiss,
    this.threshold = 100,
  });

  final VoidCallback? onDismiss;
  final double threshold;
  final Widget child;

  @override
  State<DragDismissable> createState() => _DragDismissableState();
}

class _DragDismissableState extends State<DragDismissable> {
  bool _dragging = false;
  Offset _offset = Offset.zero;
  Velocity _velocity = Velocity.zero;

  VoidCallback get onDismiss =>
      widget.onDismiss ?? () => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        Navigator.of(context).didStartUserGesture();
        SuperheroPageRoute.maybeOf<dynamic>(context)?.setDismissProgress(0);
        setState(() {
          _dragging = true;
        });
      },
      onPanUpdate: (details) {
        _offset += details.delta;
        SuperheroPageRoute.maybeOf<dynamic>(context)?.setDismissProgress(
          _offset.distance / widget.threshold,
        );
        setState(() {});
      },
      onPanCancel: () {
        SuperheroPageRoute.maybeOf<dynamic>(context)?.cancelDismiss();
        setState(() {
          _dragging = false;
          _offset = Offset.zero;
        });
      },
      onPanEnd: (details) {
        Navigator.of(context).didStopUserGesture();

        if (_offset.distance > widget.threshold) {
          setState(() {
            _velocity = details.velocity;
            _dragging = false;
            onDismiss();
          });
        } else {
          SuperheroPageRoute.maybeOf<dynamic>(context)?.cancelDismiss();
          setState(() {
            _offset = Offset.zero;
            _dragging = false;
          });
        }
      },
      child: SpringBuilder2D(
        simulate: !_dragging,
        value: (_offset.dx, _offset.dy),
        spring: SimpleSpring.interactive,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(value.x, value.y),
            child: child,
          );
        },
        child: SuperheroVelocity(
          velocity: _velocity,
          child: widget.child,
        ),
      ),
    );
  }
}
