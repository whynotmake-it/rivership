import 'package:flutter/material.dart';
import 'package:springster/springster.dart';

void main() async {
  final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  runApp(MaterialApp(
    theme: ThemeData.from(
      colorScheme: colorScheme,
    ),
    home: PipExample(),
  ));
}

class PipExample extends StatefulWidget {
  const PipExample({super.key});

  @override
  State<PipExample> createState() => _PipExampleState();
}

class _PipExampleState extends State<PipExample> {
  Alignment alignment = Alignment.topLeft;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Align(
              alignment: alignment,
              child: SpringDraggable<bool>(
                data: true,
                spring: SimpleSpring.bouncy,
                child: Card(
                  elevation: 4,
                  color: Theme.of(context).colorScheme.primary,
                  child: const SizedBox(width: 320, height: 180),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: Target(
                        alignment: Alignment.topLeft,
                        onAccept: () {
                          setState(() {
                            alignment = Alignment.topLeft;
                          });
                        },
                      )),
                      Expanded(
                        child: Target(
                          alignment: Alignment.topRight,
                          onAccept: () {
                            setState(() {
                              alignment = Alignment.topRight;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Target(
                          alignment: Alignment.bottomLeft,
                          onAccept: () {
                            setState(() {
                              alignment = Alignment.bottomLeft;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: Target(
                          alignment: Alignment.bottomRight,
                          onAccept: () {
                            setState(() {
                              alignment = Alignment.bottomRight;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Target extends StatelessWidget {
  const Target({
    super.key,
    required this.alignment,
    required this.onAccept,
  });

  final Alignment alignment;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<bool>(
      builder: (context, candidateData, rejectedData) => Container(),
      onWillAcceptWithDetails: (details) {
        onAccept();
        return true;
      },
    );
  }
}
