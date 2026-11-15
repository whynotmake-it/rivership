import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/project.dart';

/// The editing stage: the edited frame, or the playing animation.
class EditorCanvas extends StatelessWidget {
  const EditorCanvas({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => IconTheme.merge(
        // Dots without a color of their own take the theme's ink.
        data: IconThemeData(color: CoilTheme.of(context).colors.foreground),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: switch (controller.project.mode) {
            DotMode.grid => _GridCanvas(controller: controller),
            DotMode.cloud => _CloudCanvas(controller: controller),
          },
        ),
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
    _strokeValue = controller.strokeValue(column, row);
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
    final colors = CoilTheme.of(context).colors;
    final ink = style.color ?? colors.foreground;
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
                    line: colors.foreground.withValues(alpha: 0.16),
                    highlight: colors.brand,
                    hover: _hover,
                    playing: playing,
                  ),
                ),
                if (!playing && controller.onionSkin && previous != null)
                  IgnorePointer(
                    child: DotGridView(
                      grid: project.grid.frames[previous].state,
                      style: style.copyWith(color: ink.withValues(alpha: 0.12)),
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
    required this.line,
    required this.highlight,
    required this.hover,
    required this.playing,
  }) : super(repaint: hover);

  final int columns;
  final int rows;
  final Color line;
  final Color highlight;
  final ValueNotifier<(int, int)?> hover;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    final spacing = math.min(size.width / columns, size.height / rows);
    final topLeft = Offset(
      (size.width - spacing * columns) / 2,
      (size.height - spacing * rows) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..color = line;
    // Hairline cells, each with its inscribed circle.
    for (var column = 0; column <= columns; column++) {
      final x = topLeft.dx + column * spacing;
      canvas.drawLine(
        Offset(x, topLeft.dy),
        Offset(x, topLeft.dy + rows * spacing),
        paint,
      );
    }
    for (var row = 0; row <= rows; row++) {
      final y = topLeft.dy + row * spacing;
      canvas.drawLine(
        Offset(topLeft.dx, y),
        Offset(topLeft.dx + columns * spacing, y),
        paint,
      );
    }
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        canvas.drawCircle(
          topLeft + Offset((column + 0.5) * spacing, (row + 0.5) * spacing),
          spacing / 2,
          paint,
        );
      }
    }
    final cell = hover.value;
    if (cell != null && !playing) {
      canvas.drawCircle(
        topLeft + Offset((cell.$1 + 0.5) * spacing, (cell.$2 + 0.5) * spacing),
        spacing / 2 - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = highlight,
      );
    }
  }

  @override
  bool shouldRepaint(_GridGuidesPainter old) =>
      old.columns != columns ||
      old.rows != rows ||
      old.line != line ||
      old.highlight != highlight ||
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
    final colors = CoilTheme.of(context).colors;
    final ink = style.color ?? colors.foreground;
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
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(
                    CoilTheme.radiiOf(context).container,
                  ),
                ),
              ),
              if (!playing && controller.onionSkin && previous != null)
                IgnorePointer(
                  child: DotCloudView(
                    cloud: project.cloud.frames[previous].state,
                    style: style.copyWith(color: ink.withValues(alpha: 0.12)),
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
                      outline: colors.mutedForeground,
                      highlight: colors.brand,
                      center: colors.background,
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
  _CloudHandlesPainter({
    required this.cloud,
    required this.selected,
    required this.outline,
    required this.highlight,
    required this.center,
  });

  final DotCloud cloud;
  final int? selected;
  final Color outline;
  final Color highlight;
  final Color center;

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
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outline;
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = highlight;
    final centerPaint = Paint()..color = center;
    for (var i = 0; i < cloud.dots.length; i++) {
      final dot = cloud.dots[i];
      final position = origin + dot.center * scale;
      final radius = math.max(dot.radius * scale, 3).toDouble();
      if (i == selected) {
        canvas.drawCircle(position, radius + 4, highlightPaint);
      } else if (dot.radius * scale < 4) {
        canvas.drawCircle(position, radius, outlinePaint);
      }
      canvas.drawCircle(position, 1.5, centerPaint);
    }
  }

  @override
  bool shouldRepaint(_CloudHandlesPainter old) =>
      old.cloud != cloud ||
      old.selected != selected ||
      old.outline != outline ||
      old.highlight != highlight;
}
