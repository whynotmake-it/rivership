import 'package:flutter/material.dart';
import 'package:springster/springster.dart';

void main() {
  runApp(MaterialApp(
    home: OneDimensionExample(),
  ));
}

class OneDimensionExample extends StatefulWidget {
  const OneDimensionExample({super.key});

  @override
  State<OneDimensionExample> createState() => _OneDimensionExampleState();
}

class _OneDimensionExampleState extends State<OneDimensionExample> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('One Dimension'),
      ),
      body: Center(
        child: SpringBuilder(
          spring: SimpleSpring.bouncy,
          value: hovered ? 1.5 : 1,
          builder: (context, value, child) => Transform.scale(
            scale: value,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (event) {
                setState(() {
                  hovered = true;
                });
              },
              onExit: (event) {
                setState(() {
                  hovered = false;
                });
              },
              child: Material(
                color: Theme.of(context).colorScheme.primary,
                shape: StadiumBorder(),
                child: SizedBox.square(
                  dimension: 200,
                  child: Center(
                    child: Text(
                      'Hover me',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
