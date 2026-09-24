import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/style.dart';
import 'package:motor_example/widgets/timeline_inspector.dart';

/// A card showing [controller]'s tracks as live lanes.
///
/// The one place the example renders a timeline, so the devtools' public
/// timeline widget can replace the inspector here.
class LiveTimeline extends StatelessWidget {
  const LiveTimeline({
    required this.controller,
    required this.lanes,
    this.groups = const [],
    super.key,
  });

  final TrackController controller;

  /// Lane names, in the order the tracks are given colors.
  final Map<Track, String> lanes;

  /// Tracks drawn as one lane.
  final List<Set<Track>> groups;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final tracks = lanes.keys.toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceSolid,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: DefaultTextStyle.merge(
          style: archivo(11, weight: 500),
          child: TimelineInspector(
            controller: controller,
            laneLabels: lanes,
            laneGroups: groups,
            laneColors: {
              for (final (index, track) in tracks.indexed)
                track: trackColors[index % trackColors.length],
            },
            height: 44.0 + 30 * (lanes.length - _grouped).clamp(1, 5),
          ),
        ),
      ),
    );
  }

  int get _grouped => groups.fold(0, (sum, group) => sum + group.length - 1);
}
