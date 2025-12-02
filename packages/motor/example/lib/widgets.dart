import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

void main() async {
  runApp(CupertinoApp(
    home: WidgetsExample(),
  ));
}

class WidgetsExample extends StatefulWidget {
  const WidgetsExample({super.key});

  static const name = 'Widgets';
  static const path = 'widgets';

  @override
  State<WidgetsExample> createState() => _WidgetsExampleState();
}

class _WidgetsExampleState extends State<WidgetsExample> {
  bool active = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Picture in Picture'),
        trailing: CupertinoButton(
          child: Text('Toggle'),
          padding: EdgeInsets.zero,
          onPressed: () => setState(() {
            active = !active;
          }),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Placeholder(
                child: MotionPadding(
                  motion:
                      CupertinoMotion.bouncy(snapToEnd: true, extraBounce: .1),
                  padding: active
                      ? EdgeInsets.all(0)
                      : EdgeInsetsGeometry.directional(
                          top: 50,
                          bottom: 50,
                          start: 100,
                          end: 10,
                        ),
                  child: Container(
                    color: CupertinoColors.activeGreen,
                    child: Center(child: Text('MotionPadding')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Recognizer extends StatelessWidget {
  const Recognizer({
    super.key,
    required this.onChanged,
  });

  final ValueChanged<Alignment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _Target(
                  alignment: Alignment.topLeft,
                  onOver: (alignment) => onChanged(alignment),
                ),
              ),
              Expanded(
                child: _Target(
                  alignment: Alignment.bottomLeft,
                  onOver: (alignment) => onChanged(alignment),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _Target(
                  alignment: Alignment.topRight,
                  onOver: (alignment) => onChanged(alignment),
                ),
              ),
              Expanded(
                child: _Target(
                  alignment: Alignment.bottomRight,
                  onOver: (alignment) => onChanged(alignment),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Target extends StatefulWidget {
  const _Target({
    required this.alignment,
    required this.onOver,
  });

  final Alignment alignment;
  final ValueChanged<Alignment> onOver;

  @override
  State<_Target> createState() => _TargetState();
}

class _TargetState extends State<_Target> {
  @override
  Widget build(BuildContext context) {
    return DragTarget<bool>(
      onWillAcceptWithDetails: (details) {
        widget.onOver(widget.alignment);
        return true;
      },
      builder: (context, candidateData, rejectedData) => IgnorePointer(
        child: Align(
          alignment: widget.alignment,
          child: AnimatedContainer(
            duration: Durations.short4,
            curve: Easing.standard,
            margin: EdgeInsets.all(32),
            width: 320,
            height: 180,
            decoration: ShapeDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: candidateData.isNotEmpty ? 1 : 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
