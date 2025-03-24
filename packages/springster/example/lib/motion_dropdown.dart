import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:springster/springster.dart';

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
