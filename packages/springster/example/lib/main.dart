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
      backgroundColor: Theme.of(context).colorScheme.inverseSurface,
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
      child: Stack(
        children: [
          Card(
            child: SizedBox.square(dimension: 100),
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.2),
          ),
          SpringBuilder2D<double>(
            value: (x, y),
            spring: SimpleSpring.bouncy.extraBounce(.1),
            simulate: !isDragging,
            builder: (context, offset, child) => Transform.translate(
              offset: Offset(offset.$1, offset.$2),
              child: child,
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: FlutterLogo(
                  size: 80,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
