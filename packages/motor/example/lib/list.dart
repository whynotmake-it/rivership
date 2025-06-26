import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

void main() async {
  final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  runApp(MaterialApp(
    theme: ThemeData.from(
      colorScheme: colorScheme,
    ),
    home: ListExample(),
  ));
}

class ListExample extends StatefulWidget {
  const ListExample({super.key});

  @override
  State<ListExample> createState() => _ListExampleState();
}

class _ListExampleState extends State<ListExample> {
  final List<int> items = List.generate(100, (index) => index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('List'),
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          return ListItem(
            data: items[index],
            onInsert: (insertIndex) {
              setState(() {
                items.insert(
                  insertIndex > index ? index : index,
                  items.removeAt(items.indexOf(insertIndex)),
                );
              });
            },
          );
        },
      ),
    );
  }
}

class ListItem extends StatefulWidget {
  const ListItem({
    super.key,
    required this.data,
    required this.onInsert,
  });

  final int data;

  final void Function(int index) onInsert;

  @override
  State<ListItem> createState() => _ListItemState();
}

class _ListItemState extends State<ListItem> {
  @override
  Widget build(BuildContext context) {
    final tile = ListTile(title: Text('Item ${widget.data}'));
    return MotionDraggable(
      axis: Axis.vertical,
      data: widget.data,
      childWhenDragging: SizedBox.shrink(),
      child: DragTarget<int>(
        onAcceptWithDetails: (details) {
          widget.onInsert(details.data);
        },
        builder: (context, candidateData, rejectedData) => Column(
          children: [
            SingleMotionBuilder(
              motion: const CupertinoMotion.smooth(),
              value: candidateData.isNotEmpty ? 1.0 : 0.0,
              builder: (context, value, child) => SizedBox.fromSize(
                size: Size.fromHeight(value.clamp(0, 1) * 64),
                child: child,
              ),
              child: Card(
                margin: EdgeInsets.all(8),
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            tile,
          ],
        ),
      ),
      feedbackMatchesConstraints: true,
      feedback: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1),
        duration: Durations.short4,
        curve: Easing.standard,
        builder: (context, value, child) => Transform.translate(
          offset: Offset(value * 16, -value * 16),
          child: Card(
            elevation: (value + .2) * 8,
            child: tile,
          ),
        ),
      ),
    );
  }
}
