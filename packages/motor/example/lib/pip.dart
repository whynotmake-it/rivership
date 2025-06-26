import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

void main() async {
  runApp(CupertinoApp(
    home: PipExample(),
  ));
}

class PipExample extends StatefulWidget {
  const PipExample({super.key});

  static const name = 'Picture in Picture';
  static const path = 'pip';

  @override
  State<PipExample> createState() => _PipExampleState();
}

class _PipExampleState extends State<PipExample> {
  Alignment alignment = Alignment.topLeft;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Picture in Picture'),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Align(
                alignment: alignment,
                child: MotionDraggable<bool>(
                  data: true,
                  motion: CupertinoMotion.bouncy(),
                  child: Card(
                    color: Theme.of(context).colorScheme.primary,
                    child: SizedBox(
                      width: 320,
                      height: 180,
                      child: Center(
                        child: Text(
                          'Drag me to a corner!',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Recognizer(
                onChanged: (alignment) =>
                    setState(() => this.alignment = alignment),
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
