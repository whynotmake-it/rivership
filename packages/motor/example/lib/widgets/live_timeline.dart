import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_example/widgets/style.dart';

/// [controller]'s tracks as live lanes, from `motor_devtools`, on a quiet
/// panel under the code.
class LiveTimeline extends StatelessWidget {
  const LiveTimeline({
    required this.controller,
    required this.lanes,
    super.key,
  });

  final TrackController controller;

  /// Lane names, in order.
  final Map<Track<Object>, String> lanes;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: DefaultTextStyle(
          style: mono(11, color: colors.mutedForeground),
          child: MotorTimeline(
            controller: controller,
            playheadColor: colors.foreground,
            lanes: [
              for (final MapEntry(key: track, value: label) in lanes.entries)
                MotorTimelineLane(label, [track], color: colors.brand),
            ],
          ),
        ),
      ),
    );
  }
}
