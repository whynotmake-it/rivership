import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:springster/springster.dart';

void main() {
  runApp(MaterialApp(
    home: TwoDimensionRedirectionExample(),
  ));
}

final motion = ValueNotifier<Motion>(SpringMotion(Spring()));

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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('2D with Dynamic Redirection'),
      ),
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
            const SizedBox(
              height: 16,
            ),
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
          builder: (context, value, child) => PullDownButton(
            buttonBuilder: (context, pressed) => CupertinoButton.tinted(
              onPressed: pressed,
              child: Text(
                motionOptions.entries.firstWhere((e) => e.value == value).key,
              ),
            ),
            itemBuilder: (context) => motionOptions.entries
                .map(
                  (e) => PullDownMenuItem.selectable(
                    onTap: () => motion.value = e.value,
                    title: e.key,
                    selected: motion.value == e.value,
                    subtitle: e.value.needsSettle ? 'Physics' : 'Traditional',
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
