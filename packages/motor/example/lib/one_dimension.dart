import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/motion_dropdown.dart';

void main() {
  runApp(CupertinoApp(
    home: OneDimensionExample(),
  ));
}

final motion = ValueNotifier<Motion>(CupertinoMotion.bouncy());

class OneDimensionExample extends StatefulWidget {
  const OneDimensionExample({super.key});

  static const name = 'One Dimension';
  static const path = 'one-dimension';

  @override
  State<OneDimensionExample> createState() => _OneDimensionExampleState();
}

class _OneDimensionExampleState extends State<OneDimensionExample> {
  final statesController = WidgetStatesController();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(),
      child: SafeArea(
        child: Column(
          children: [
            MotionDropdown(
              label: Text('Motion:'),
              motion: motion,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([motion, statesController]),
                builder: (context, child) => Center(
                  child: SingleMotionBuilder(
                    motion: motion.value,
                    value: switch (statesController.value) {
                      final v when v.contains(WidgetState.pressed) => 1.2,
                      final v when v.contains(WidgetState.hovered) => 1.5,
                      _ => 1,
                    },
                    from: 0,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: Listener(
                        onPointerDown: (event) {
                          statesController.update(WidgetState.pressed, true);
                        },
                        onPointerUp: (event) {
                          statesController.update(WidgetState.pressed, false);
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (event) {
                            statesController.update(WidgetState.hovered, true);
                          },
                          onExit: (event) {
                            statesController.update(WidgetState.hovered, false);
                          },
                          child: Material(
                            color: Theme.of(context).colorScheme.primary,
                            shape: StadiumBorder(),
                            child: SizedBox.square(
                              dimension: 200,
                              child: Center(
                                child: Text(
                                  'Click Me',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    statesController.dispose();
    super.dispose();
  }
}
