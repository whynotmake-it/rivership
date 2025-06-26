import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor.dart';
import 'package:motor_example/motion_dropdown.dart';

void main() {
  runApp(MaterialApp(
    home: TwoDimensionRedirectionExample(),
  ));
}

final motion = ValueNotifier<Motion>(CupertinoMotion.smooth);

class TwoDimensionRedirectionExample extends StatefulWidget {
  const TwoDimensionRedirectionExample({super.key});

  static const name = 'Two Dimension Redirection';
  static const path = 'two-dimension-redirection';

  @override
  State<TwoDimensionRedirectionExample> createState() =>
      _TwoDimensionRedirectionExampleState();
}

class _TwoDimensionRedirectionExampleState
    extends State<TwoDimensionRedirectionExample> {
  Offset offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(),
      child: SafeArea(
        child: Column(
          children: [
            Wrap(
              spacing: 16,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MotionDropdown(motion: motion, label: const Text('Motion:')),
              ],
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: offset,
                    child: const Icon(Icons.adjust_rounded),
                  ),
                  Center(
                    child: ListenableBuilder(
                      listenable: motion,
                      builder: (context, child) => MotionBuilder(
                        motion: motion.value,
                        converter: const OffsetMotionConverter(),
                        value: offset,
                        from: Offset(0, 200),
                        builder: (context, value, child) => Transform.translate(
                          offset: value,
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
            ),
            const Text('Click or drag anywhere'),
            const SizedBox(height: 16),
          ],
        ),
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
