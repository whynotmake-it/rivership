import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/ui.dart';

/// Tools for the edited frame: brushes, or dot tools.
class ToolsPanel extends StatelessWidget {
  const ToolsPanel({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final project = controller.project;
        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Section(
              title: 'Mode',
              children: [
                Choice(
                  value: project.mode,
                  options: const {
                    DotMode.grid: 'Grid',
                    DotMode.cloud: 'Freeform',
                  },
                  onChanged: controller.setMode,
                ),
              ],
            ),
            if (project.mode == DotMode.grid)
              ..._gridTools()
            else
              ..._cloudTools(),
            Section(
              title: 'View',
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Onion skin', style: EditorText.label),
                    ),
                    CupertinoSwitch(
                      value: controller.onionSkin,
                      activeTrackColor: EditorColors.accent,
                      onChanged: (enabled) =>
                          controller.setOnionSkin(enabled: enabled),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _gridTools() {
    final grid = controller.currentGrid;
    return [
      Section(
        title: 'Brush',
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ToolButton(
                icon: CupertinoIcons.clear,
                label: 'Erase',
                selected: controller.brush == 0,
                onPressed: () => controller.setBrush(0),
              ),
              for (final level in const [3, 5, 7, 9])
                _BrushButton(
                  level: level,
                  selected: (controller.brush * 9).round() == level,
                  onPressed: () => controller.setBrush(level / 9),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ToolButton(label: 'Fill', onPressed: controller.fillFrame),
              ToolButton(label: 'Invert', onPressed: controller.invertFrame),
              ToolButton(label: 'Clear', onPressed: controller.clearFrame),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(child: Text('Shift', style: EditorText.label)),
              ToolButton(
                icon: CupertinoIcons.arrow_left,
                onPressed: () => controller.shiftFrame(-1, 0),
              ),
              const SizedBox(width: 4),
              ToolButton(
                icon: CupertinoIcons.arrow_up,
                onPressed: () => controller.shiftFrame(0, -1),
              ),
              const SizedBox(width: 4),
              ToolButton(
                icon: CupertinoIcons.arrow_down,
                onPressed: () => controller.shiftFrame(0, 1),
              ),
              const SizedBox(width: 4),
              ToolButton(
                icon: CupertinoIcons.arrow_right,
                onPressed: () => controller.shiftFrame(1, 0),
              ),
            ],
          ),
        ],
      ),
      Section(
        title: 'Grid',
        children: [
          Stepper(
            label: 'Columns',
            value: grid.columns,
            onChanged: (columns) => controller.resizeGrid(columns, grid.rows),
          ),
          Stepper(
            label: 'Rows',
            value: grid.rows,
            onChanged: (rows) => controller.resizeGrid(grid.columns, rows),
          ),
        ],
      ),
    ];
  }

  List<Widget> _cloudTools() {
    final selected = controller.selectedDot;
    final cloud = controller.currentCloud;
    return [
      Section(
        title: 'Dots',
        children: [
          Choice(
            value: controller.cloudTool,
            options: const {CloudTool.add: 'Add', CloudTool.move: 'Select'},
            onChanged: controller.setCloudTool,
          ),
          Text(
            '${cloud.dots.length} / ${DotCloud.maxDots} dots. Added dots go '
            'into every frame; moving and resizing only changes this one.',
            style: EditorText.label,
          ),
          const SizedBox(height: 10),
          ToolButton(label: 'Shrink all', onPressed: controller.clearFrame),
        ],
      ),
      if (selected != null)
        Section(
          title: 'Selected dot',
          children: [
            LabeledSlider(
              label: 'Radius',
              value: cloud.dots[selected].radius,
              min: 0,
              max: 50,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (radius) => controller.setDotRadius(selected, radius),
            ),
            Row(
              children: [
                ToolButton(
                  icon: CupertinoIcons.trash,
                  label: 'Delete',
                  onPressed: () => controller.removeDot(selected),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Scroll over the canvas to resize.',
              style: EditorText.label,
            ),
          ],
        ),
    ];
  }
}

class _BrushButton extends StatelessWidget {
  const _BrushButton({
    required this.level,
    required this.selected,
    required this.onPressed,
  });

  final int level;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? EditorColors.accent : EditorColors.control,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Container(
            width: 4 + 16 * level / 9,
            height: 4 + 16 * level / 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? EditorColors.onAccent : EditorColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Style and motion settings of the open project.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final project = controller.project;
        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _style(project),
            _motion(project.motion),
            _stagger(project.stagger),
            Section(
              title: 'Playback',
              children: [
                Choice(
                  value: project.loop == LoopMode.seamless
                      ? LoopMode.loop
                      : project.loop,
                  options: const {
                    LoopMode.none: 'Once',
                    LoopMode.loop: 'Loop',
                    LoopMode.pingPong: 'Ping-pong',
                  },
                  onChanged: controller.setLoop,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _style(Project project) {
    final Color? color;
    final List<Widget> sliders;
    switch (project.mode) {
      case DotMode.grid:
        final style = project.gridStyle;
        color = style.color;
        sliders = [
          LabeledSlider(
            label: 'Blend',
            value: style.blend,
            min: 0,
            max: 1.4,
            onChanged: (blend) =>
                controller.setGridStyle(style.copyWith(blend: blend)),
          ),
          LabeledSlider(
            label: 'Dot size',
            value: style.dotSize,
            min: 0.2,
            max: 1.2,
            onChanged: (size) =>
                controller.setGridStyle(style.copyWith(dotSize: size)),
          ),
        ];
      case DotMode.cloud:
        final style = project.cloudStyle;
        color = style.color;
        sliders = [
          LabeledSlider(
            label: 'Blend',
            value: style.blend,
            min: 0,
            max: 40,
            format: (v) => v.toStringAsFixed(1),
            onChanged: (blend) =>
                controller.setCloudStyle(style.copyWith(blend: blend)),
          ),
        ];
    }
    void setColor(Color color) => switch (project.mode) {
      DotMode.grid => controller.setGridStyle(
        project.gridStyle.copyWith(color: color),
      ),
      DotMode.cloud => controller.setCloudStyle(
        project.cloudStyle.copyWith(color: color),
      ),
    };
    return Section(
      title: 'Style',
      children: [
        ...sliders,
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final swatch in EditorColors.swatches)
              GestureDetector(
                onTap: () => setColor(swatch),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: swatch == color
                            ? EditorColors.text
                            : EditorColors.border,
                        width: swatch == color ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _motion(Motion motion) {
    final duration = motion.duration ?? const Duration(milliseconds: 500);
    final ms = duration.inMilliseconds.toDouble();
    final isSpring = motion is CupertinoMotion;
    return Section(
      title: 'Motion',
      children: [
        Choice(
          value: isSpring,
          options: const {true: 'Spring', false: 'Curve'},
          onChanged: (spring) => controller.setMotion(
            spring
                ? CupertinoMotion(duration: duration, bounce: 0.2)
                : CurvedMotion(duration, Curves.easeInOutCubic),
          ),
        ),
        LabeledSlider(
          label: 'Duration',
          value: ms,
          min: 60,
          max: 2000,
          format: (v) => '${v.round()} ms',
          onChanged: (ms) {
            final duration = Duration(milliseconds: ms.round());
            controller.setMotion(switch (motion) {
              CupertinoMotion(:final bounce) => CupertinoMotion(
                duration: duration,
                bounce: bounce,
              ),
              CurvedMotion(:final curve) => CurvedMotion(duration, curve),
              _ => CupertinoMotion(duration: duration),
            });
          },
        ),
        if (motion case CupertinoMotion(:final bounce))
          LabeledSlider(
            label: 'Bounce',
            value: bounce,
            min: -0.5,
            max: 0.9,
            onChanged: (bounce) => controller.setMotion(
              CupertinoMotion(duration: duration, bounce: bounce),
            ),
          )
        else if (motion case CurvedMotion(:final curve))
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in const [
                'linear',
                'easeInOut',
                'easeInOutCubic',
                'easeOutBack',
                'elasticOut',
                'bounceOut',
              ])
                ToolButton(
                  label: name,
                  selected: MotionJson.curveName(curve) == name,
                  onPressed: () => controller.setMotion(
                    CurvedMotion(duration, MotionJson.curves[name]!),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _stagger(DotStagger stagger) {
    final duration = stagger is NoDotStagger
        ? const Duration(milliseconds: 200)
        : stagger.duration;
    final type = switch (stagger) {
      NoDotStagger() => 'none',
      DirectionalDotStagger() => 'sweep',
      RadialDotStagger() => 'ripple',
      OrderedDotStagger() => 'order',
      RandomDotStagger() => 'random',
    };
    DotStagger ofType(String type, Duration duration) => switch (type) {
      'sweep' => DotStagger.directional(
        duration: duration,
        angle: stagger is DirectionalDotStagger ? stagger.angle : 0,
      ),
      'ripple' => DotStagger.radial(
        duration: duration,
        inward: stagger is RadialDotStagger && stagger.inward,
      ),
      'order' => DotStagger.ordered(duration: duration),
      'random' => DotStagger.random(duration: duration),
      _ => const DotStagger.none(),
    };
    return Section(
      title: 'Stagger',
      children: [
        Choice(
          value: type,
          options: const {
            'none': 'None',
            'sweep': 'Sweep',
            'ripple': 'Ripple',
            'order': 'Order',
            'random': 'Random',
          },
          onChanged: (type) => controller.setStagger(ofType(type, duration)),
        ),
        if (stagger is! NoDotStagger)
          LabeledSlider(
            label: 'Spread',
            value: duration.inMilliseconds.toDouble(),
            min: 0,
            max: 1500,
            format: (v) => '${v.round()} ms',
            onChanged: (ms) => controller.setStagger(
              ofType(type, Duration(milliseconds: ms.round())),
            ),
          ),
        if (stagger case DirectionalDotStagger(:final angle))
          LabeledSlider(
            label: 'Angle',
            value: angle * 180 / math.pi,
            min: -180,
            max: 180,
            divisions: 72,
            format: (v) => '${v.round()}°',
            onChanged: (degrees) => controller.setStagger(
              DotStagger.directional(
                duration: duration,
                angle: degrees * math.pi / 180,
              ),
            ),
          ),
        if (stagger case RadialDotStagger(:final inward))
          Row(
            children: [
              const Expanded(child: Text('Inward', style: EditorText.label)),
              CupertinoSwitch(
                value: inward,
                activeTrackColor: EditorColors.accent,
                onChanged: (inward) => controller.setStagger(
                  DotStagger.radial(duration: duration, inward: inward),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
