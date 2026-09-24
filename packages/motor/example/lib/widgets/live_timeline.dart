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

  /// Lane names, in order.
  final Map<Track<Object>, String> lanes;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const .fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: .circular(radius),
        border: Border.all(color: p.border),
      ),
      child: DefaultTextStyle(
        style: mono(11, color: p.textSecondary),
        child: MotorTimeline(
          controller: controller,
          playheadColor: p.text,
          lanes: [
            for (final MapEntry(key: track, value: label) in lanes.entries)
              MotorTimelineLane(label, [track], color: p.accent),
          ],
        ),
      ),
    );
  }
}
