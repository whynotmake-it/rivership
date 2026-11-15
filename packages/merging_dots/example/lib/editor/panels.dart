import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/icons.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/ui.dart';

/// The frames of the open project: thumbnails, order and hold.
class FramesPanel extends StatelessWidget {
  const FramesPanel({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final project = controller.project;
        final frame = controller.frame;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(child: RoleText.title('Frames')),
                  CoilTooltip(
                    message: const Text('Move earlier'),
                    child: CoilButton.icon(
                      variant: CoilButtonVariant.ghost,
                      size: CoilSize.compact,
                      semanticLabel: 'Move earlier',
                      icon: const GlyphIcon(Glyph.left),
                      onPressed: frame > 0
                          ? () => controller.moveFrame(-1)
                          : null,
                    ),
                  ),
                  CoilTooltip(
                    message: const Text('Move later'),
                    child: CoilButton.icon(
                      variant: CoilButtonVariant.ghost,
                      size: CoilSize.compact,
                      semanticLabel: 'Move later',
                      icon: const GlyphIcon(Glyph.right),
                      onPressed: frame < project.frameCount - 1
                          ? () => controller.moveFrame(1)
                          : null,
                    ),
                  ),
                  CoilTooltip(
                    message: const Text('Delete frame'),
                    child: CoilButton.icon(
                      variant: CoilButtonVariant.ghost,
                      size: CoilSize.compact,
                      semanticLabel: 'Delete frame',
                      icon: const GlyphIcon(Glyph.clear),
                      onPressed: project.frameCount > 1
                          ? controller.removeFrame
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: controller.playingFrame,
                builder: (context, playingFrame, _) => GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 84,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: project.frameCount + 1,
                  itemBuilder: (context, i) => i == project.frameCount
                      ? _AddFrame(onPressed: controller.duplicateFrame)
                      : _FrameThumbnail(
                          project: project,
                          index: i,
                          selected: controller.playing
                              ? i == playingFrame
                              : i == frame,
                          onPressed: () => controller.selectFrame(i),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: PropertySlider(
                label: 'Hold',
                value: project.holdOf(frame).inMilliseconds.toDouble(),
                min: 0,
                max: 3000,
                divisions: 60,
                format: (v) => '${v.round()} ms',
                onChanged: (ms) =>
                    controller.setHold(Duration(milliseconds: ms.round())),
              ),
            ),
          ],
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
    required this.onPressed,
  });

  final Project project;
  final int index;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).item);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Frame ${index + 1}',
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? colors.active : colors.muted,
              borderRadius: radius,
              border: Border.all(
                color: selected ? colors.foreground : colors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                IconTheme.merge(
                  data: IconThemeData(color: colors.foreground),
                  child: switch (project.mode) {
                    DotMode.grid => DotGridView(
                      grid: project.grid.frames[index].state,
                      style: project.gridStyle,
                    ),
                    DotMode.cloud => DotCloudView(
                      cloud: project.cloud.frames[index].state,
                      style: project.cloudStyle,
                    ),
                  },
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: RoleText(
                    '${index + 1}',
                    step: const CoilTypeStep(11, 14),
                    muted: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddFrame extends StatelessWidget {
  const _AddFrame({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CoilTooltip(
      message: const Text('Duplicate this frame'),
      child: CoilButton.icon(
        variant: CoilButtonVariant.tertiary,
        semanticLabel: 'Duplicate this frame',
        icon: const GlyphIcon(Glyph.plus),
        onPressed: onPressed,
      ),
    );
  }
}

/// Mode, style and motion of the open project.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final project = controller.project;
        return CoilScrollArea(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Section(
                title: 'Canvas',
                children: [
                  Segmented(
                    value: project.mode,
                    options: const {
                      DotMode.grid: 'Grid',
                      DotMode.cloud: 'Freeform',
                    },
                    onChanged: controller.setMode,
                  ),
                ],
              ),
              _style(project),
              if (project.mode == DotMode.cloud) _selectedDot(),
              _motion(project.motion),
              _stagger(project.stagger),
              Section(
                title: 'Playback',
                children: [
                  Segmented(
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
                  CoilSwitch(
                    value: controller.onionSkin,
                    label: const Text('Onion skin'),
                    onChanged: (enabled) =>
                        controller.setOnionSkin(enabled: enabled),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _style(Project project) {
    switch (project.mode) {
      case DotMode.grid:
        final style = project.gridStyle;
        final tiles = style.shape == DotGridShape.tiles;
        return Section(
          title: 'Style',
          children: [
            Segmented(
              value: style.shape,
              options: const {
                DotGridShape.tiles: 'Tiles',
                DotGridShape.goo: 'Goo',
              },
              onChanged: (shape) => controller.setGridStyle(
                shape == DotGridShape.tiles
                    ? DotGridStyle.tiles(color: style.color)
                    : DotGridStyle(color: style.color),
              ),
            ),
            if (tiles) ...[
              PropertySlider(
                label: 'Corners',
                value: style.cornerRadius,
                min: 0,
                max: 1,
                onChanged: (v) =>
                    controller.setGridStyle(style.copyWith(cornerRadius: v)),
              ),
              PropertySlider(
                label: 'Inner corners',
                value: style.innerRadius,
                min: 0,
                max: 1,
                onChanged: (v) =>
                    controller.setGridStyle(style.copyWith(innerRadius: v)),
              ),
              PropertySlider(
                label: 'Weight',
                value: style.dotSize,
                min: 0.6,
                max: 1.2,
                onChanged: (v) =>
                    controller.setGridStyle(style.copyWith(dotSize: v)),
              ),
            ] else ...[
              PropertySlider(
                label: 'Blend',
                value: style.blend,
                min: 0,
                max: 1.4,
                onChanged: (v) =>
                    controller.setGridStyle(style.copyWith(blend: v)),
              ),
              PropertySlider(
                label: 'Dot size',
                value: style.dotSize,
                min: 0.2,
                max: 1.2,
                onChanged: (v) =>
                    controller.setGridStyle(style.copyWith(dotSize: v)),
              ),
              PropertySlider(
                label: 'Brush',
                value: math.max(controller.brush, 1 / 9),
                min: 1 / 9,
                max: 1,
                divisions: 8,
                format: (v) => '${(v * 9).round()} / 9',
                onChanged: controller.setBrush,
              ),
            ],
            SwatchPicker(
              value: style.color,
              onChanged: (color) =>
                  controller.setGridStyle(_withColor(style, color)),
            ),
          ],
        );
      case DotMode.cloud:
        final style = project.cloudStyle;
        return Section(
          title: 'Style',
          children: [
            PropertySlider(
              label: 'Blend',
              value: style.blend,
              min: 0,
              max: 40,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (v) =>
                  controller.setCloudStyle(style.copyWith(blend: v)),
            ),
            SwatchPicker(
              value: style.color,
              onChanged: (color) => controller.setCloudStyle(
                DotCloudStyle(color: color, blend: style.blend),
              ),
            ),
          ],
        );
    }
  }

  Widget _selectedDot() {
    final selected = controller.selectedDot;
    final cloud = controller.currentCloud;
    return Section(
      title: selected == null ? 'Dots' : 'Selected dot',
      children: [
        if (selected == null)
          RoleText.caption(
            '${cloud.dots.length} dots. Click to add a dot to every frame, '
            'drag one to move it in this frame, scroll to resize it.',
          )
        else ...[
          PropertySlider(
            label: 'Radius',
            value: cloud.dots[selected].radius,
            min: 0,
            max: 50,
            format: (v) => v.toStringAsFixed(1),
            onChanged: (r) => controller.setDotRadius(selected, r),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CoilButton(
              variant: CoilButtonVariant.destructive,
              size: CoilSize.compact,
              leading: const GlyphIcon(Glyph.clear),
              onPressed: () => controller.removeDot(selected),
              child: const Text('Delete dot'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _motion(Motion motion) {
    final duration = motion.duration ?? const Duration(milliseconds: 500);
    final spring = motion is CupertinoMotion;
    return Section(
      title: 'Motion',
      children: [
        Segmented(
          value: spring,
          options: const {true: 'Spring', false: 'Curve'},
          onChanged: (spring) => controller.setMotion(
            spring
                ? CupertinoMotion(duration: duration, bounce: 0.2)
                : CurvedMotion(duration, Curves.easeInOutCubic),
          ),
        ),
        PropertySlider(
          label: 'Duration',
          value: duration.inMilliseconds.toDouble(),
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
          PropertySlider(
            label: 'Bounce',
            value: bounce,
            min: -0.5,
            max: 0.9,
            onChanged: (bounce) => controller.setMotion(
              CupertinoMotion(duration: duration, bounce: bounce),
            ),
          )
        else if (motion case CurvedMotion(:final curve))
          Segmented(
            value: MotionJson.curveName(curve) ?? 'linear',
            options: const {
              'easeInOutCubic': 'Ease',
              'easeOutBack': 'Back',
              'elasticOut': 'Elastic',
              'bounceOut': 'Bounce',
              'linear': 'Linear',
            },
            onChanged: (name) => controller.setMotion(
              CurvedMotion(duration, MotionJson.curves[name]!),
            ),
          ),
      ],
    );
  }

  Widget _stagger(DotStagger stagger) {
    final duration = stagger is NoDotStagger
        ? const Duration(milliseconds: 300)
        : stagger.duration;
    final type = switch (stagger) {
      NoDotStagger() => 'none',
      DirectionalDotStagger() => 'sweep',
      RadialDotStagger() => 'ripple',
      OrderedDotStagger() => 'order',
      RandomDotStagger() => 'scatter',
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
      'scatter' => DotStagger.random(duration: duration),
      _ => const DotStagger.none(),
    };
    return Section(
      title: 'Cascade',
      children: [
        Segmented(
          value: type,
          options: const {
            'none': 'None',
            'ripple': 'Ripple',
            'sweep': 'Sweep',
            'order': 'Order',
            'scatter': 'Scatter',
          },
          onChanged: (type) => controller.setStagger(ofType(type, duration)),
        ),
        if (stagger is! NoDotStagger)
          PropertySlider(
            label: 'Length',
            value: duration.inMilliseconds.toDouble(),
            min: 0,
            max: 1500,
            format: (v) => '${v.round()} ms',
            onChanged: (ms) => controller.setStagger(
              ofType(type, Duration(milliseconds: ms.round())),
            ),
          ),
        if (stagger case DirectionalDotStagger(:final angle))
          PropertySlider(
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
          CoilSwitch(
            value: inward,
            label: const Text('Inward'),
            onChanged: (inward) => controller.setStagger(
              DotStagger.radial(duration: duration, inward: inward),
            ),
          ),
      ],
    );
  }
}

DotGridStyle _withColor(DotGridStyle style, Color? color) =>
    switch (style.shape) {
      DotGridShape.tiles => DotGridStyle.tiles(
        color: color,
        dotSize: style.dotSize,
        cornerRadius: style.cornerRadius,
        innerRadius: style.innerRadius,
        cellSize: style.cellSize,
      ),
      DotGridShape.goo => DotGridStyle(
        color: color,
        dotSize: style.dotSize,
        blend: style.blend,
        offsetRange: style.offsetRange,
        cellSize: style.cellSize,
      ),
    };
