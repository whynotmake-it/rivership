import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/motion_dropdown.dart';

void main() async {
  runApp(CupertinoApp(
    home: DraggableIconsExample(),
  ));
}

final motion = ValueNotifier<Motion>(const CupertinoMotion.bouncy());

class DraggableIconsExample extends StatelessWidget {
  const DraggableIconsExample({super.key});

  static const name = 'Draggable Icons';
  static const path = 'draggable-icons';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Draggable Icons'),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MotionDropdown(motion: motion, label: const Text('Motion:')),
            Expanded(child: DraggableIcons()),
            const Text('Drag the icons to the target'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class DraggableIcons extends StatefulWidget {
  const DraggableIcons({super.key});

  @override
  State<DraggableIcons> createState() => _DraggableIconsState();
}

class _DraggableIconsState extends State<DraggableIcons> {
  bool isDragging = false;

  double x = 0;
  double y = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        DraggableCard(icon: Icons.favorite),
        const Target(),
        DraggableCard(icon: Icons.cabin),
      ],
    );
  }
}

class DraggableCard extends StatelessWidget {
  const DraggableCard({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: motion,
      builder: (context, child) => MotionDraggable(
        data: icon,
        motion: motion.value,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            elevation: 0,
            shape: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                icon,
                size: 80,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Target extends StatefulWidget {
  const Target({super.key});

  @override
  State<Target> createState() => _TargetState();
}

class _TargetState extends State<Target> {
  IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DragTarget<IconData>(
      builder: (context, candidateData, rejectedData) {
        final color = candidateData.isNotEmpty
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest;
        return AnimatedContainer(
          duration: Durations.medium4,
          curve: Easing.standard,
          padding: const EdgeInsets.all(48),
          decoration: ShapeDecoration(
            shape: const CircleBorder(),
            color: color,
          ),
          child: AnimatedOpacity(
            opacity: candidateData.isEmpty ? 1.0 : 0.0,
            duration: Durations.medium4,
            curve: Easing.standard,
            child: Icon(
              icon,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      },
      onAcceptWithDetails: (details) {
        setState(() {
          icon = details.data;
        });
      },
    );
  }
}
