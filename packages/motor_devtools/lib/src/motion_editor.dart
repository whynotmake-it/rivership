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

/// A track's row in a motion list: its name, its current motion, and a
/// chevron that turns while its editor is [open].
class TrackMotionHeader extends StatelessWidget {
  /// Creates a header for the track [name].
  const TrackMotionHeader({
    required this.name,
    required this.motion,
    required this.tuned,
    required this.open,
    required this.onTap,
    this.value,
    super.key,
  });

  /// The track's name.
  final String name;

  /// The current motion, described.
  final String motion;

  /// Whether the motion replaces the authored one.
  final bool tuned;

  /// Whether the editor is open.
  final bool open;

  /// Toggles the editor.
  final VoidCallback onTap;

  /// The track's current value, if shown.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: '$name, $motion',
      pressedScale: 1,
      child: SizedBox(
        height: 26,
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
                        color: open ? palette.text : palette.secondary,
                        fontWeight: open ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tuned
                          ? palette.accent.withValues(alpha: 0.14)
                          : palette.fill,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      motion,
                      maxLines: 1,
                      style: palette.caption.copyWith(
                        fontSize: 10.5,
                        color: tuned ? palette.accent : palette.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (value case final value? when value.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: palette.numeric,
                ),
              ),
            const SizedBox(width: 4),
            SingleMotionBuilder(
              value: open ? 0.25 : 0,
              motion: foldMotion,
              debugLabel: internalDebugLabel,
              builder: (context, turns, child) =>
                  Transform.rotate(angle: turns * 2 * math.pi, child: child),
              child: GlyphIcon(Glyph.forward, color: palette.tertiary),
            ),
          ],
        ),
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
    super.key,
  });

  /// The motion that replaces the track's authored motions, if any.
  final Motion? current;

  /// Motions registered by the app, by name.
  final Map<String, Motion> appMotions;

  /// Replaces the track's motion, or restores it with null.
  final ValueChanged<Motion?> onChanged;

  @override
  State<MotionEditor> createState() => _MotionEditorState();
}

class _MotionEditorState extends State<MotionEditor> {
  /// The spring being dragged, before it is applied on release.
  CupertinoMotion? _draft;

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
        Row(
          children: [
            Expanded(child: Text(kind.hint, style: palette.caption)),
            if (current != null)
              Pressable(
                key: const ValueKey('motor-devtools-reset'),
                onTap: () => widget.onChanged(null),
                semanticLabel: 'Reset to authored',
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'Reset',
                    style: palette.caption.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (kind == MotionKind.app) ...[
          const SizedBox(height: 10),
          Wrap(
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
        ],
        if (motion case final CupertinoMotion spring
            when kind == MotionKind.spring) ...[
          const SizedBox(height: 10),
          SpringGraph(
            key: const ValueKey('motor-devtools-spring-graph'),
            duration: spring.duration,
            bounce: spring.bounce,
            onChanged: (duration, bounce) => setState(
              () => _draft = CupertinoMotion(
                duration: duration,
                bounce: bounce,
                snapToEnd: spring.snapToEnd,
              ),
            ),
            onChangeEnd: () {
              final draft = _draft;
              setState(() => _draft = null);
              if (draft != null) widget.onChanged(draft);
            },
          ),
        ],
        if (motion case final CurvedMotion curved
            when kind == MotionKind.curve) ...[
          const SizedBox(height: 10),
          _CurveEditor(motion: curved, onChanged: widget.onChanged),
        ],
        if (motion != null) ...[
          const SizedBox(height: 10),
          if (motion is! CupertinoMotion || kind == MotionKind.app) ...[
            SizedBox(height: 56, child: MotionPreview(motion: motion)),
            const SizedBox(height: 8),
          ],
          if (codeFor(motion) case final code?) _CodeLine(code: code),
        ],
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.fill);
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
      ..drawCircle(
        point + const Offset(0, 1),
        10,
        Paint()
          ..color = palette.shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawCircle(point, 10, Paint()..color = palette.surface)
      ..drawCircle(point, 4.5, Paint()..color = palette.accent);
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
    _controller.animateTo(1, from: 0, withVelocity: 0).orCancel.then(
      (_) {
        if (mounted) {
          _pause = Timer(const Duration(milliseconds: 700), _play);
        }
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
      (motion.duration?.inMilliseconds ?? 0).toDouble();

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
        4,
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
        7,
        Paint()..color = palette.text,
      );
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) => true;
}

/// Dart code that creates [motion], for the motions the editor makes.
String? codeFor(Motion motion) {
  String ms(Duration d) => 'Duration(milliseconds: ${d.inMilliseconds})';
  return switch (motion) {
    CupertinoMotion(:final duration, :final bounce) =>
      'Motion.cupertino(duration: ${ms(duration)}, '
          'bounce: ${bounce.toStringAsFixed(2)})',
    LinearMotion(:final duration) => 'Motion.linear(${ms(duration)})',
    CurvedMotion(:final duration, :final curve) =>
      'Motion.curved(${ms(duration)}, ${_curveNames[curve] ?? 'curve'})',
    _ => null,
  };
}

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
        decoration: BoxDecoration(
          color: palette.fill,
          borderRadius: BorderRadius.circular(8),
        ),
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
