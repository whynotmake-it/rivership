import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/style.dart';

/// How a track's motion is chosen.
enum MotionKind {
  /// The motions the track was given.
  authored('Authored', 'Plays the motions it was given.'),

  /// One of the app's registered motions.
  app('App', "Plays one of your app's motions."),

  /// A spring tuned by duration and bounce.
  spring('Spring', 'A spring: drag to set its duration and bounce.'),

  /// An easing curve and a duration.
  curve('Curve', 'An easing curve with a duration.');

  const MotionKind(this.label, this.hint);

  /// The name shown in the picker.
  final String label;

  /// One line explaining the choice.
  final String hint;

  /// The kind of [motion], a replacement for authored motions.
  static MotionKind of(Motion? motion, Map<String, Motion> appMotions) =>
      switch (motion) {
        null => authored,
        _ when appMotions.containsValue(motion) => app,
        CupertinoMotion() => spring,
        CurvedMotion() => curve,
        _ => app,
      };
}

/// A short description of a track's current motion, such as `Authored` or
/// `Spring 420 ms · 0.18`.
String describeMotion(Motion? motion, Map<String, Motion> appMotions) {
  for (final MapEntry(:key, :value) in appMotions.entries) {
    if (value == motion) return key;
  }
  return switch (motion) {
    null => 'Authored',
    CupertinoMotion(:final duration, :final bounce) =>
      'Spring ${formatDuration(duration)} · ${bounce.toStringAsFixed(2)}',
    CurvedMotion(:final duration) => 'Curve ${formatDuration(duration)}',
    _ => 'Custom',
  };
}

/// A track that can be edited in place: a header with its name, its tuned
/// motion and value, an optional [body] such as its timeline lane, and an
/// [editor] shown while [editing]. While editing, all of it sits on one card.
class EditableTrack extends StatelessWidget {
  /// Creates an editable track named [name].
  const EditableTrack({
    required this.name,
    required this.editing,
    required this.onEdit,
    required this.onDone,
    required this.editor,
    this.tuned,
    this.onReset,
    this.value,
    this.body,
    this.dimmed = false,
    super.key,
  });

  /// The track's name.
  final String name;

  /// The motion that replaces the authored one, described, if any.
  final String? tuned;

  /// The track's current value, if shown.
  final String? value;

  /// Content under the header, such as the track's timeline lane.
  final Widget? body;

  /// The editor shown while [editing].
  final Widget editor;

  /// Whether the editor is open.
  final bool editing;

  /// Whether another track is being edited.
  final bool dimmed;

  /// Opens the editor.
  final VoidCallback onEdit;

  /// Closes the editor.
  final VoidCallback onDone;

  /// Restores the authored motion.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final action = palette.caption.copyWith(
      color: palette.accent,
      fontWeight: FontWeight.w600,
    );
    final header = Pressable(
      key: ValueKey('motor-devtools-track-$name'),
      onTap: editing ? onDone : onEdit,
      semanticLabel: editing ? 'Done editing $name' : 'Edit $name',
      pressedScale: 1,
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: palette.caption.copyWith(
                        color: editing ? palette.text : palette.secondary,
                        fontWeight: editing ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (tuned case final tuned?) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: ShapeDecoration(
                          color: palette.accent.withValues(alpha: 0.12),
                          shape: rounded(6),
                        ),
                        child: Text(
                          tuned,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: palette.caption.copyWith(
                            fontSize: 10.5,
                            color: palette.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (editing) ...[
              if (tuned != null && onReset != null)
                Pressable(
                  key: const ValueKey('motor-devtools-reset'),
                  onTap: onReset,
                  semanticLabel: 'Reset to authored',
                  child: Text(
                    'Reset',
                    style: action.copyWith(color: palette.secondary),
                  ),
                ),
              const SizedBox(width: 14),
              Pressable(
                key: const ValueKey('motor-devtools-done'),
                onTap: onDone,
                semanticLabel: 'Done',
                child: Text('Done', style: action),
              ),
            ] else ...[
              if (value case final value? when value.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: palette.numeric.copyWith(color: palette.tertiary),
                  ),
                ),
              const SizedBox(width: 8),
              GlyphIcon(Glyph.edit, color: palette.tertiary, size: 14),
            ],
          ],
        ),
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (body case final body?) ...[const SizedBox(height: 4), body],
        Disclosure(
          open: editing,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: editor,
          ),
        ),
      ],
    );
    return SingleMotionBuilder(
      value: dimmed ? 0.45 : 1,
      motion: foldMotion,
      debugLabel: internalDebugLabel,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
      child: SingleMotionBuilder(
        value: editing ? 1 : 0,
        motion: foldMotion,
        debugLabel: internalDebugLabel,
        builder: (context, t, child) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -10,
              right: -10,
              top: -8,
              bottom: -8,
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: palette.fill,
                    shape: rounded(14),
                  ),
                ),
              ),
            ),
            child!,
          ],
        ),
        child: content,
      ),
    );
  }
}

/// Picks and tunes the motion that replaces one track's authored motions.
class MotionEditor extends StatefulWidget {
  /// Creates an editor showing [current].
  const MotionEditor({
    required this.current,
    required this.appMotions,
    required this.onChanged,
    required this.onTuned,
    super.key,
  });

  /// The motion that replaces the track's authored motions, if any.
  final Motion? current;

  /// Motions registered by the app, by name.
  final Map<String, Motion> appMotions;

  /// Replaces the track's motion, or restores it with null, and replays.
  final ValueChanged<Motion?> onChanged;

  /// Replaces the track's motion after tuning it on the graph, without
  /// replaying: the graph previews it.
  final ValueChanged<Motion> onTuned;

  @override
  State<MotionEditor> createState() => _MotionEditorState();
}

class _MotionEditorState extends State<MotionEditor> {
  /// The spring being dragged, before it is applied on release.
  CupertinoMotion? _draft;

  /// The last spring, curve and motion shown, so their controls can fold
  /// away after another kind is picked.
  CupertinoMotion _spring = const CupertinoMotion(bounce: 0.2);
  CurvedMotion _curve = const CurvedMotion(
    Duration(milliseconds: 500),
    Curves.easeInOutCubic,
  );
  Motion? _shown;

  void _pick(MotionKind kind) {
    final duration = switch (widget.current) {
      CupertinoMotion(:final duration) ||
      CurvedMotion(:final duration) => duration,
      _ => const Duration(milliseconds: 500),
    };
    widget.onChanged(switch (kind) {
      MotionKind.authored => null,
      MotionKind.app => widget.appMotions.values.first,
      MotionKind.spring => CupertinoMotion(duration: duration, bounce: 0.2),
      MotionKind.curve => CurvedMotion(duration, Curves.easeInOutCubic),
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final apps = widget.appMotions;
    final current = widget.current;
    final motion = _draft ?? current;
    final kind = MotionKind.of(current, apps);
    if (motion is CupertinoMotion && kind == MotionKind.spring) {
      _spring = motion;
    }
    if (motion is CurvedMotion && kind == MotionKind.curve) _curve = motion;
    if (motion != null) _shown = motion;
    final shown = _shown ?? _spring;
    final previewed =
        motion != null &&
        (motion is! CupertinoMotion || kind == MotionKind.app);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented<MotionKind>(
          options: [
            for (final option in MotionKind.values)
              if (option != MotionKind.app || apps.isNotEmpty) option,
          ],
          selected: kind,
          labelOf: (kind) => kind.label,
          keyOf: (kind) => ValueKey('motor-devtools-motion-${kind.label}'),
          onSelected: (option) {
            if (option != kind) _pick(option);
          },
        ),
        const SizedBox(height: 8),
        Text(kind.hint, style: palette.caption),
        Disclosure(
          open: kind == MotionKind.app,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final MapEntry(key: name, value: app) in apps.entries)
                  Tag(
                    key: ValueKey('motor-devtools-app-$name'),
                    label: name,
                    selected: app == current,
                    outlined: true,
                    onTap: () => widget.onChanged(app),
                  ),
              ],
            ),
          ),
        ),
        Disclosure(
          open: kind == MotionKind.spring,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SpringGraph(
              key: const ValueKey('motor-devtools-spring-graph'),
              duration: _spring.duration,
              bounce: _spring.bounce,
              onChanged: (duration, bounce) => setState(
                () => _draft = CupertinoMotion(
                  duration: duration,
                  bounce: bounce,
                  snapToEnd: _spring.snapToEnd,
                ),
              ),
              onChangeEnd: () {
                final draft = _draft;
                setState(() => _draft = null);
                if (draft != null) widget.onTuned(draft);
              },
            ),
          ),
        ),
        Disclosure(
          open: kind == MotionKind.curve,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _CurveEditor(motion: _curve, onChanged: widget.onChanged),
          ),
        ),
        Disclosure(
          open: previewed,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(height: 56, child: MotionPreview(motion: shown)),
          ),
        ),
        Disclosure(
          open: motion != null && codeFor(shown) != null,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _CodeLine(code: codeFor(shown) ?? ''),
          ),
        ),
      ],
    );
  }
}

/// A duration × bounce plane with a draggable handle for a spring, and a
/// live preview of the spring behind it.
class SpringGraph extends StatelessWidget {
  /// Creates a graph showing [duration] and [bounce].
  const SpringGraph({
    required this.duration,
    required this.bounce,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  /// The shortest duration on the graph.
  static const minDuration = 100.0;

  /// The longest duration on the graph.
  static const maxDuration = 1500.0;

  /// The largest bounce on the graph.
  static const maxBounce = 0.8;

  /// The spring's duration.
  final Duration duration;

  /// The spring's bounce, from 0 (none) upward.
  final double bounce;

  /// Called while the handle is dragged.
  final void Function(Duration duration, double bounce) onChanged;

  /// Called once the handle is released.
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final ms = duration.inMicroseconds / Duration.microsecondsPerMillisecond;
    final handle = Offset(
      ((ms - minDuration) / (maxDuration - minDuration)).clamp(0.0, 1.0),
      1 - (bounce / maxBounce).clamp(0.0, 1.0),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 150);
        void update(Offset position) {
          final x = (position.dx / size.width).clamp(0.0, 1.0);
          final y = (position.dy / size.height).clamp(0.0, 1.0);
          final ms = minDuration + (maxDuration - minDuration) * x;
          onChanged(
            Duration(milliseconds: (ms / 10).round() * 10),
            ((1 - y) * maxBounce * 100).round() / 100,
          );
        }

        return Semantics(
          label: 'Spring duration and bounce',
          value:
              '${formatDuration(duration)}, bounce '
              '${bounce.toStringAsFixed(2)}',
          child: HoldsPointer(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => update(details.localPosition),
              onTapUp: (_) => onChangeEnd(),
              onPanStart: (details) => update(details.localPosition),
              onPanUpdate: (details) => update(details.localPosition),
              onPanEnd: (_) => onChangeEnd(),
              child: SizedBox.fromSize(
                size: size,
                child: MotionBuilder<Offset>(
                  value: handle,
                  motion: const Motion.snappySpring(
                    duration: Duration(milliseconds: 220),
                  ),
                  converter: MotionConverter.offset,
                  debugLabel: internalDebugLabel,
                  builder: (context, handle, _) => Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRSuperellipse(
                          borderRadius: BorderRadius.circular(10),
                          child: CustomPaint(
                            painter: _GraphBackgroundPainter(palette),
                            foregroundPainter: _HandlePainter(handle, palette),
                            child: MotionPreview(
                              motion: CupertinoMotion(
                                duration: duration,
                                bounce: bounce,
                              ),
                              inGraph: true,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 8,
                        child: Text('Duration →', style: palette.axis),
                      ),
                      Positioned(
                        left: 10,
                        top: 8,
                        child: Text('Bouncy ↑', style: palette.axis),
                      ),
                      Positioned(
                        right: 10,
                        top: 8,
                        child: Text(
                          '${formatDuration(duration)} · '
                          '${bounce.toStringAsFixed(2)}',
                          style: palette.numeric.copyWith(color: palette.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GraphBackgroundPainter extends CustomPainter {
  const _GraphBackgroundPainter(this.palette);

  final DevToolsPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.surface);
    final grid = Paint()
      ..color = palette.hairline
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_GraphBackgroundPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

class _HandlePainter extends CustomPainter {
  const _HandlePainter(this.handle, this.palette);

  final Offset handle;
  final DevToolsPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final point = Offset(handle.dx * size.width, handle.dy * size.height);
    final guide = Paint()
      ..color = palette.accent.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas
      ..drawLine(Offset(point.dx, size.height), point, guide)
      ..drawLine(Offset(0, point.dy), point, guide)
      ..drawCircle(point, 9, Paint()..color = palette.surface)
      ..drawCircle(
        point,
        9,
        Paint()
          ..color = palette.outline
          ..style = PaintingStyle.stroke,
      )
      ..drawCircle(point, 4, Paint()..color = palette.accent);
  }

  @override
  bool shouldRepaint(_HandlePainter oldDelegate) =>
      oldDelegate.handle != handle || oldDelegate.palette != palette;
}

class _CurveEditor extends StatelessWidget {
  const _CurveEditor({required this.motion, required this.onChanged});

  static const _curves = {
    'Ease out': Curves.easeOutCubic,
    'In-out': Curves.easeInOutCubic,
    'Emphasized': Curves.fastEaseInToSlowEaseOut,
    'Linear': Curves.linear,
  };

  final CurvedMotion motion;
  final ValueChanged<Motion> onChanged;

  @override
  Widget build(BuildContext context) {
    final ms = motion.duration.inMilliseconds.toDouble();
    final selected = _curves.entries
        .where((entry) => entry.value == motion.curve)
        .firstOrNull
        ?.key;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented<String>(
          options: _curves.keys.toList(),
          selected: selected,
          labelOf: (name) => name,
          onSelected: (name) =>
              onChanged(CurvedMotion(motion.duration, _curves[name]!)),
        ),
        const SizedBox(height: 8),
        ValueSlider(
          key: const ValueKey('motor-devtools-duration'),
          label: 'Duration',
          valueLabel: formatDuration(motion.duration),
          value: ms,
          min: 100,
          max: 1500,
          onChanged: (value) => onChanged(
            CurvedMotion(
              Duration(milliseconds: (value / 10).round() * 10),
              motion.curve,
            ),
          ),
          onChangeEnd: () {},
        ),
      ],
    );
  }
}

/// Plays [motion] from 0 to 1 over and over, drawing its curve and a dot
/// that rides it. Fills its parent.
class MotionPreview extends StatefulWidget {
  /// Previews [motion].
  const MotionPreview({required this.motion, this.inGraph = false, super.key});

  /// The motion to preview.
  final Motion motion;

  /// Whether the preview is drawn behind a [SpringGraph]: inset from its
  /// labels, without the value rail.
  final bool inGraph;

  @override
  State<MotionPreview> createState() => _MotionPreviewState();
}

class _MotionPreviewState extends State<MotionPreview>
    with SingleTickerProviderStateMixin {
  late final _controller = SingleMotionController(
    motion: widget.motion,
    vsync: this,
    debugLabel: internalDebugLabel,
  );
  late var _samples = _sample(widget.motion);
  Timer? _pause;
  Timer? _restart;
  var _run = 0;

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(MotionPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion == widget.motion) return;
    _samples = _sample(widget.motion);
    _restart?.cancel();
    _restart = Timer(const Duration(milliseconds: 120), () {
      _controller.motion = widget.motion;
      _play();
    });
  }

  void _play() {
    _pause?.cancel();
    // Restarting mid-run returns the controller's in-flight future again, so
    // only the latest run may schedule the next one; otherwise an earlier
    // callback leaves a timer that outlives dispose.
    final run = ++_run;
    _controller.animateTo(1, from: 0, withVelocity: 0).orCancel.then(
      (_) {
        if (!mounted || run != _run) return;
        _pause = Timer(const Duration(milliseconds: 700), _play);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _pause?.cancel();
    _restart?.cancel();
    _controller.dispose();
    super.dispose();
  }

  static List<double> _sample(Motion motion) {
    final simulation = motion.createSimulation();
    const step = 1 / 60;
    final values = <double>[];
    for (var t = 0.0; t < 3; t += step) {
      values.add(simulation.x(t));
      if (simulation.isDone(t) && t * 1000 >= _minMs(motion)) break;
    }
    return values;
  }

  static double _minMs(Motion motion) =>
      (motion.settlingDuration()?.inMicroseconds ?? 0) / 1000;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final elapsed = _controller.isAnimating
              ? (_controller.lastElapsedDuration?.inMicroseconds ?? 0) /
                    Duration.microsecondsPerSecond
              : _samples.length / 60;
          return CustomPaint(
            painter: _PreviewPainter(
              samples: _samples,
              progress: (elapsed * 60 / math.max(1, _samples.length)).clamp(
                0.0,
                1.0,
              ),
              value: _controller.value,
              palette: palette,
              inGraph: widget.inGraph,
            ),
          );
        },
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({
    required this.samples,
    required this.progress,
    required this.value,
    required this.palette,
    required this.inGraph,
  });

  final List<double> samples;
  final double progress;
  final double value;
  final DevToolsPalette palette;
  final bool inGraph;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = inGraph
        ? Rect.fromLTRB(12, 34, size.width - 12, size.height - 30)
        : Rect.fromLTRB(8, 8, size.width - 40, size.height - 8);
    final lo = math.min<double>(0, samples.fold(0, math.min));
    final hi = math.max<double>(1, samples.fold(1, math.max));
    double yOf(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;
    final baseline = Paint()
      ..color = palette.hairline
      ..strokeWidth = 1;
    canvas
      ..drawLine(
        Offset(plot.left, yOf(0)),
        Offset(plot.right, yOf(0)),
        baseline,
      )
      ..drawLine(
        Offset(plot.left, yOf(1)),
        Offset(plot.right, yOf(1)),
        baseline,
      );
    final path = Path();
    for (final (i, v) in samples.indexed) {
      final x = plot.left + plot.width * i / math.max(1, samples.length - 1);
      i == 0 ? path.moveTo(x, yOf(v)) : path.lineTo(x, yOf(v));
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = palette.text.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..drawCircle(
        Offset(plot.left + plot.width * progress, yOf(value)),
        3.5,
        Paint()..color = palette.accent,
      );
    if (inGraph) return;
    final rail = Rect.fromLTRB(
      size.width - 20,
      plot.top,
      size.width - 16,
      plot.bottom,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(rail, const Radius.circular(2)),
        Paint()..color = palette.fill,
      )
      ..drawCircle(
        Offset(rail.center.dx, yOf(value)),
        6,
        Paint()..color = palette.text,
      );
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) => true;
}

/// Dart code that creates [motion], for the motions the editor makes.
///
/// The code uses dot shorthands, for a `Motion` parameter.
String? codeFor(Motion motion) {
  String ms(Duration d) => 'Duration(milliseconds: ${d.inMilliseconds})';
  return switch (motion) {
    CupertinoMotion(:final duration, :final bounce) =>
      '.cupertino(duration: ${ms(duration)}, bounce: ${_decimal(bounce)})',
    LinearMotion(:final duration) => '.linear(${ms(duration)})',
    CurvedMotion(:final duration, :final curve) =>
      '.curved(${ms(duration)}, ${_curveNames[curve] ?? 'curve'})',
    _ => null,
  };
}

/// [value] with at most two decimals and no trailing zeros, like `0.2`.
String _decimal(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

const _curveNames = {
  Curves.easeOutCubic: 'Curves.easeOutCubic',
  Curves.easeInOutCubic: 'Curves.easeInOutCubic',
  Curves.fastEaseInToSlowEaseOut: 'Curves.fastEaseInToSlowEaseOut',
  Curves.linear: 'Curves.linear',
  Curves.ease: 'Curves.ease',
  Curves.easeOut: 'Curves.easeOut',
  Curves.easeInOut: 'Curves.easeInOut',
};

class _CodeLine extends StatefulWidget {
  const _CodeLine({required this.code});

  final String code;

  @override
  State<_CodeLine> createState() => _CodeLineState();
}

class _CodeLineState extends State<_CodeLine> {
  var _copied = false;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Pressable(
      key: const ValueKey('motor-devtools-motion-code'),
      semanticLabel: 'Copy code',
      pressedScale: 0.98,
      onTap: () {
        unawaited(Clipboard.setData(ClipboardData(text: widget.code)));
        setState(() => _copied = true);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: ShapeDecoration(color: palette.surface, shape: rounded(8)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.code,
                style: palette.code,
              ),
            ),
            const SizedBox(width: 8),
            Text(_copied ? 'Copied' : 'Copy', style: palette.caption),
          ],
        ),
      ),
    );
  }
}
