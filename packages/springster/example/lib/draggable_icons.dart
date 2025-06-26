import 'package:flutter/material.dart';
import 'package:springster/springster.dart';

void main() async {
  final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  runApp(MaterialApp(
    theme: ThemeData.from(
      colorScheme: colorScheme,
    ),
    home: DraggableIconsExample(),
  ));
}

class DraggableIconsExample extends StatelessWidget {
  const DraggableIconsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draggable Icons'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Drag the icons to the target'),
          Expanded(child: DraggableIcons()),
        ],
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
    return SpringDraggable(
      data: icon,
      spring: Spring.bouncy,
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
