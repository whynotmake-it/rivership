import 'package:flutter/material.dart';
import 'package:springster/springster.dart';

void main() {
  runApp(MaterialApp(
    home: TwoDimensionRedirectionExample(),
  ));
}

class TwoDimensionRedirectionExample extends StatefulWidget {
  const TwoDimensionRedirectionExample({super.key});

  @override
  State<TwoDimensionRedirectionExample> createState() =>
      _TwoDimensionRedirectionExampleState();
}

class _TwoDimensionRedirectionExampleState
    extends State<TwoDimensionRedirectionExample> {
  Offset offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('One Dimension'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            opacity: offset == Offset.zero ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: const Text('Click or drag anywhere'),
          ),
          Transform.translate(
            offset: offset,
            child: AnimatedOpacity(
              opacity: offset == Offset.zero ? 0 : 1,
              duration: const Duration(milliseconds: 500),
              child: const Icon(Icons.adjust_rounded),
            ),
          ),
          Center(
            child: SpringBuilder2D(
              spring: SimpleSpring.bouncy,
              value: (offset.dx, offset.dy),
              builder: (context, value, child) => Transform.translate(
                offset: Offset(value.x, value.y),
                child: child,
              ),
              child: Material(
                color: Colors.transparent,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 4,
                  ),
                ),
                child: SizedBox.square(
                  dimension: 100,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) =>
                    _setPosition(details.localPosition, constraints),
                onPanUpdate: (details) =>
                    _setPosition(details.localPosition, constraints),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _setPosition(Offset position, BoxConstraints constraints) {
    final center = constraints.biggest.center(Offset.zero);
    setState(() {
      offset = position - center;
    });
  }
}
