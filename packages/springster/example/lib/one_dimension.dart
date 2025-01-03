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
  late final SpringSimulationController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SpringDraggable<bool>(
          data: true,
          spring: SimpleSpring.bouncy,
          child: FlutterLogo(
            size: 100,
          ),
        ),
      ),
    );
  }
}
