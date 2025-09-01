import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:motor/motor.dart';

final motionOptions = {
  "Smooth Spring": CupertinoMotion.smooth(),
  "Bouncy Spring": CupertinoMotion.bouncy(),
  "Snappy Spring": CupertinoMotion.snappy(),
  "Interactive Spring": CupertinoMotion.interactive(),
  "Material 3 Ease": CurvedMotion(Durations.long2, Easing.standard),
  "Material 3 Expressive Spring":
      MaterialSpringMotion.expressiveSpatialDefault(),
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
