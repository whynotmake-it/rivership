import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_example/widgets/style.dart';

/// A card showing [controller]'s tracks as live lanes.
class LiveTimeline extends StatelessWidget {
  const LiveTimeline({
    required this.controller,
    required this.lanes,
    super.key,
  });

  final TrackController controller;

  /// Lane names, in order. Lanes take their colors from [trackColors].
  final Map<Track<Object>, String> lanes;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: t.surfaceSolid,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.border),
      ),
      child: DefaultTextStyle(
        style: archivo(11.5, weight: 500, color: t.textSecondary),
        child: MotorTimeline(
          controller: controller,
          playheadColor: t.textPrimary,
          lanes: [
            for (final (index, MapEntry(key: track, value: label))
                in lanes.entries.indexed)
              MotorTimelineLane(label, [
                track,
              ], color: trackColors[index % trackColors.length]),
          ],
        ),
      ),
    );
  }
}
