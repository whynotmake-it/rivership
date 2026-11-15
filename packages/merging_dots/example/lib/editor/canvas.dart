import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/ui.dart';

/// The editing stage: the edited frame, or the playing animation.
class EditorCanvas extends StatelessWidget {
  const EditorCanvas({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: switch (controller.project.mode) {
          DotMode.grid => _GridCanvas(controller: controller),
          DotMode.cloud => _CloudCanvas(controller: controller),
        },
      ),
    );
  }
}

/// How fast edits animate on the canvas.
const _editMotion = CupertinoMotion(
  duration: Duration(milliseconds: 320),
  bounce: 0.3,
);

class _GridCanvas extends StatefulWidget {
  const _GridCanvas({required this.controller});

  final EditorController controller;

  @override
  State<_GridCanvas> createState() => _GridCanvasState();
}

class _GridCanvasState extends State<_GridCanvas> {
  final _dots = GlobalKey();
  final _hover = ValueNotifier<(int, int)?>(null);
  double? _strokeValue;

  EditorController get controller => widget.controller;

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  (int, int)? _cellAt(Offset globalPosition) {
    final box = _dots.currentContext?.findRenderObject();
    if (box is! RenderDotGrid) return null;
    return box.cellAt(box.globalToLocal(globalPosition));
  }

  void _strokeStart(Offset globalPosition) {
    final cell = _cellAt(globalPosition);
    if (cell == null || controller.playing) return;
    final (column, row) = cell;
    final current = controller.currentGrid.valueAt(column, row);
    // Starting on a cell that already has the brush erases instead.
    _strokeValue =
        (current - controller.brush).abs() < 1e-3 && controller.brush > 0
        ? 0
        : controller.brush;
    controller
      ..checkpoint()
      ..paintCell(column, row, _strokeValue!);
  }

  void _strokeUpdate(Offset globalPosition) {
    final value = _strokeValue;
    final cell = _cellAt(globalPosition);
    if (value == null || cell == null) return;
    controller.paintCell(cell.$1, cell.$2, value);
  }

  @override
  Widget build(BuildContext context) {
    final project = controller.project;
    final grid = controller.currentGrid;
    final style = project.gridStyle;
    final previous = controller.previousFrame;
    final playing = controller.playing;

    return Center(
      child: AspectRatio(
        aspectRatio: grid.columns / grid.rows,
        child: MouseRegion(
          cursor: playing ? MouseCursor.defer : SystemMouseCursors.precise,
          onHover: (event) => _hover.value = _cellAt(event.position),
          onExit: (_) => _hover.value = null,
          child: Listener(
            onPointerDown: (event) => _strokeStart(event.position),
            onPointerMove: (event) {
              _hover.value = _cellAt(event.position);
              _strokeUpdate(event.position);
            },
            onPointerUp: (_) => _strokeValue = null,
            onPointerCancel: (_) => _strokeValue = null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _GridGuidesPainter(
                    columns: grid.columns,
                    rows: grid.rows,
                    dotSize: style.dotSize,
                    hover: _hover,
                    playing: playing,
                  ),
                ),
                if (!playing && controller.onionSkin && previous != null)
                  IgnorePointer(
                    child: DotGridView(
                      grid: project.grid.frames[previous].state,
                      style: style.copyWith(
                        color: (style.color ?? EditorColors.text).withValues(
                          alpha: 0.16,
                        ),
                      ),
                    ),
                  ),
                if (playing)
                  DotGridView.sequence(
                    key: _dots,
                    sequence: project.grid,
                    style: style,
                    onFrame: (frame) => controller.playingFrame.value = frame,
                  )
                else
                  DotGridView(
                    key: _dots,
                    grid: grid,
                    style: style,
                    motion: _editMotion,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridGuidesPainter extends CustomPainter {
  _GridGuidesPainter({
    required this.columns,
    required this.rows,
    required this.dotSize,
    required this.hover,
    required this.playing,
  }) : super(repaint: hover);

  final int columns;
  final int rows;
  final double dotSize;
  final ValueNotifier<(int, int)?> hover;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    final spacing = math.min(size.width / columns, size.height / rows);
    final origin = Offset(
      (size.width - spacing * columns) / 2 + spacing / 2,
      (size.height - spacing * rows) / 2 + spacing / 2,
    );
    final radius = spacing * dotSize / 2;
    final paint = Paint()..color = EditorColors.control;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        canvas.drawCircle(
          origin + Offset(column * spacing, row * spacing),
          math.max(1.5, radius * 0.18),
          paint,
        );
      }
    }
    final cell = hover.value;
    if (cell != null && !playing) {
      canvas.drawCircle(
        origin + Offset(cell.$1 * spacing, cell.$2 * spacing),
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = EditorColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_GridGuidesPainter old) =>
      old.columns != columns ||
      old.rows != rows ||
      old.dotSize != dotSize ||
      old.playing != playing;
}

class _CloudCanvas extends StatefulWidget {
  const _CloudCanvas({required this.controller});

  final EditorController controller;

  @override
  State<_CloudCanvas> createState() => _CloudCanvasState();
}

class _CloudCanvasState extends State<_CloudCanvas> {
  final _dots = GlobalKey();
  int? _dragging;
  Offset _grabOffset = Offset.zero;

  EditorController get controller => widget.controller;

  RenderDotCloud? get _box {
    final box = _dots.currentContext?.findRenderObject();
    return box is RenderDotCloud ? box : null;
  }

  Offset? _toCanvas(Offset globalPosition) {
    final box = _box;
    if (box == null) return null;
    return box.toCanvas(box.globalToLocal(globalPosition));
  }

  int? _hitTest(Offset position) {
    final box = _box;
    final scale = box == null ? 1.0 : box.transform.$1;
    final dots = controller.currentCloud.dots;
    int? hit;
    var best = double.infinity;
    for (var i = 0; i < dots.length; i++) {
      final distance = (dots[i].center - position).distance;
      if (distance < dots[i].radius + 8 / scale && distance < best) {
        best = distance;
        hit = i;
      }
    }
    return hit;
  }

  void _down(Offset globalPosition) {
    if (controller.playing) return;
    final position = _toCanvas(globalPosition);
    if (position == null) return;
    final size = controller.currentCloud.size;
    if (!(Offset.zero & size).contains(position)) return;
    final hit = _hitTest(position);
    if (hit != null) {
      controller
        ..selectDot(hit)
        ..checkpoint();
      _dragging = hit;
      _grabOffset = controller.currentCloud.dots[hit].center - position;
    } else if (controller.cloudTool == CloudTool.add) {
      controller.addDot(position);
      _dragging = controller.selectedDot;
      _grabOffset = Offset.zero;
    } else {
      controller.selectDot(null);
    }
  }

  void _move(Offset globalPosition) {
    final dragging = _dragging;
    final position = _toCanvas(globalPosition);
    if (dragging == null || position == null) return;
    controller.moveDot(dragging, position + _grabOffset);
  }

  void _scroll(PointerSignalEvent event) {
    final selected = controller.selectedDot;
    if (event is! PointerScrollEvent || selected == null) return;
    final dot = controller.currentCloud.dots[selected];
    controller.setDotRadius(
      selected,
      (dot.radius - event.scrollDelta.dy / 20).clamp(0, 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = controller.project;
    final cloud = controller.currentCloud;
    final style = project.cloudStyle;
    final previous = controller.previousFrame;
    final playing = controller.playing;

    return Center(
      child: AspectRatio(
        aspectRatio: cloud.size.width / cloud.size.height,
        child: Listener(
          onPointerDown: (event) => _down(event.position),
          onPointerMove: (event) => _move(event.position),
          onPointerUp: (_) => _dragging = null,
          onPointerCancel: (_) => _dragging = null,
          onPointerSignal: _scroll,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: EditorColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              if (!playing && controller.onionSkin && previous != null)
                IgnorePointer(
                  child: DotCloudView(
                    cloud: project.cloud.frames[previous].state,
                    style: style.copyWith(
                      color: (style.color ?? EditorColors.text).withValues(
                        alpha: 0.16,
                      ),
                    ),
                  ),
                ),
              if (playing)
                DotCloudView.sequence(
                  key: _dots,
                  sequence: project.cloud,
                  style: style,
                  onFrame: (frame) => controller.playingFrame.value = frame,
                )
              else
                DotCloudView(
                  key: _dots,
                  cloud: cloud,
                  style: style,
                  motion: _editMotion,
                ),
              if (!playing)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _CloudHandlesPainter(
                      cloud: cloud,
                      selected: controller.selectedDot,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudHandlesPainter extends CustomPainter {
  _CloudHandlesPainter({required this.cloud, required this.selected});

  final DotCloud cloud;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / cloud.size.width,
      size.height / cloud.size.height,
    );
    final origin = Offset(
      (size.width - cloud.size.width * scale) / 2,
      (size.height - cloud.size.height * scale) / 2,
    );
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = EditorColors.textTertiary;
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = EditorColors.accent;
    for (var i = 0; i < cloud.dots.length; i++) {
      final dot = cloud.dots[i];
      final center = origin + dot.center * scale;
      final radius = math.max(dot.radius * scale, 3).toDouble();
      if (i == selected) {
        canvas.drawCircle(center, radius + 4, highlight);
      } else if (dot.radius * scale < 4) {
        canvas.drawCircle(center, radius, outline);
      }
      canvas.drawCircle(center, 1.5, Paint()..color = EditorColors.onAccent);
    }
  }

  @override
  bool shouldRepaint(_CloudHandlesPainter old) =>
      old.cloud != cloud || old.selected != selected;
}
