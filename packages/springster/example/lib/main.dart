import 'package:flutter/material.dart';
import 'package:springster/springster.dart';

void main() async {
  runApp(MaterialApp(
    home: SpringsterExample(),
  ));
}

class SpringsterExample extends StatelessWidget {
  const SpringsterExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: DraggableLogo(),
      ),
    );
  }
}

class DraggableLogo extends StatefulWidget {
  const DraggableLogo({super.key});

  @override
  State<DraggableLogo> createState() => _DraggableLogoState();
}

class _DraggableLogoState extends State<DraggableLogo> {
  bool isDragging = false;

  double x = 0;
  double y = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          isDragging = true;
        });
      },
      onPanEnd: (details) {
        setState(() {
          x = 0;
          y = 0;
          isDragging = false;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          x += details.delta.dx;
          y += details.delta.dy;
        });
      },
      child: SpringBuilder2D<double>(
        value: (x, y),
        spring: SimpleSpring.defaultIOS,
        simulate: !isDragging,
        builder: (context, value) => Transform.translate(
          offset: Offset(value.$1, value.$2),
          child: Container(
            width: 100,
            height: 100,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }
}
