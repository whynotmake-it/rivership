import 'package:flutter/material.dart';
import 'package:springster/springster.dart';

void main() {
  runApp(MaterialApp(
    home: TwoDimensionRedirectionExample(),
  ));
}

final xMotion = ValueNotifier<Motion>(SpringMotion(Spring()));
final yMotion = ValueNotifier<Motion>(SpringMotion(Spring()));

const motionOptions = {
  "Smooth Spring": SpringMotion(Spring()),
  "Bouncy Spring": SpringMotion(Spring.bouncy),
  "Snappy Spring": SpringMotion(Spring.snappy),
  "Interactive Spring": SpringMotion(Spring.interactive),
  "Material 3 Ease": DurationAndCurve(
    duration: Durations.long2,
    curve: Easing.standard,
  ),
};

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
        title: const Text('2D with Dynamic Redirection'),
      ),
      body: Column(
        children: [
          Wrap(
            spacing: 16,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MotionDropdown(motion: xMotion, label: const Text('X Motion:')),
              MotionDropdown(motion: yMotion, label: const Text('Y Motion:')),
            ],
          ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment(0, -.5),
                    child: AnimatedOpacity(
                      opacity: offset == Offset.zero ? 1 : 0,
                      duration: const Duration(milliseconds: 500),
                      child: const Text('Click or drag anywhere'),
                    ),
                  ),
                  Transform.translate(
                    offset: offset,
                    child: const Icon(Icons.adjust_rounded),
                  ),
                  Center(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([xMotion, yMotion]),
                      builder: (context, child) =>
                          MotionBuilder.motionPerDimension(
                        motionPerDimension: [
                          xMotion.value,
                          yMotion.value,
                        ],
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

class MotionDropdown extends StatelessWidget {
  const MotionDropdown({
    super.key,
    required this.label,
    required this.motion,
  });

  final Widget label;

  final ValueNotifier<Motion> motion;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyLarge,
          child: label,
        ),
        ValueListenableBuilder(
          valueListenable: motion,
          builder: (context, value, child) => DropdownButton<Motion>(
            value: value,
            items: motionOptions.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.value,
                    child: Text(e.key),
                  ),
                )
                .toList(),
            onChanged: (Motion? value) {
              motion.value = value!;
            },
          ),
        ),
      ],
    );
  }
}
