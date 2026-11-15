import 'package:flutter/cupertino.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/ui.dart';

/// The frames of the open project, with playback controls.
class Timeline extends StatelessWidget {
  const Timeline({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final project = controller.project;
        final frame = controller.frame;
        final hold = project.holdOf(frame);
        return Panel(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ToolButton(
                    icon: controller.playing
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    label: controller.playing ? 'Pause' : 'Play',
                    prominent: true,
                    onPressed: project.frameCount < 2
                        ? null
                        : () => controller.setPlaying(
                            playing: !controller.playing,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Frame ${frame + 1} of ${project.frameCount}',
                    style: EditorText.label,
                  ),
                  const Spacer(),
                  ToolButton(
                    icon: CupertinoIcons.chevron_left,
                    onPressed: frame > 0
                        ? () => controller.moveFrame(-1)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  ToolButton(
                    icon: CupertinoIcons.chevron_right,
                    onPressed: frame < project.frameCount - 1
                        ? () => controller.moveFrame(1)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  ToolButton(
                    icon: CupertinoIcons.trash,
                    onPressed: project.frameCount > 1
                        ? controller.removeFrame
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ValueListenableBuilder(
                  valueListenable: controller.playingFrame,
                  builder: (context, playingFrame, _) => ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < project.frameCount; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FrameThumbnail(
                            project: project,
                            index: i,
                            selected: !controller.playing && i == frame,
                            playing: controller.playing && i == playingFrame,
                            onTap: () => controller.selectFrame(i),
                          ),
                        ),
                      GestureDetector(
                        onTap: controller.duplicateFrame,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            width: 76,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: EditorColors.border),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.plus,
                                  size: 18,
                                  color: EditorColors.textSecondary,
                                ),
                                SizedBox(height: 4),
                                Text('Duplicate', style: EditorText.label),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              LabeledSlider(
                label: 'Hold after frame ${frame + 1}',
                value: hold.inMilliseconds.toDouble(),
                min: 0,
                max: 3000,
                format: (v) => '${v.round()} ms',
                onChanged: (ms) =>
                    controller.setHold(Duration(milliseconds: ms.round())),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FrameThumbnail extends StatelessWidget {
  const _FrameThumbnail({
    required this.project,
    required this.index,
    required this.selected,
    required this.playing,
    required this.onTap,
  });

  final Project project;
  final int index;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = selected || playing;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 76,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: EditorColors.raised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: highlight ? EditorColors.accent : EditorColors.border,
              width: highlight ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              switch (project.mode) {
                DotMode.grid => DotGridView(
                  grid: project.grid.frames[index].state,
                  style: project.gridStyle,
                ),
                DotMode.cloud => DotCloudView(
                  cloud: project.cloud.frames[index].state,
                  style: project.cloudStyle,
                ),
              },
              Align(
                alignment: Alignment.bottomRight,
                child: Text('${index + 1}', style: EditorText.section),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
