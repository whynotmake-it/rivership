import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/style.dart';

/// Picks and tunes the motion used for one of a controller's tracks.
class MotionEditor extends StatefulWidget {
  /// Creates an editor for [track].
  const MotionEditor({
    required this.tracks,
    required this.track,
    required this.current,
    required this.tuned,
    required this.appMotions,
    required this.onTrackSelected,
    required this.onChanged,
    super.key,
  });

  /// The controller's tracks and their names.
  final List<(Track<Object>, String)> tracks;

  /// The track being edited.
  final Track<Object> track;

  /// The motion that replaces the track's authored motions, if any.
  final Motion? current;

  /// Tracks that have a replacement motion.
  final Set<Track<Object>> tuned;

  /// Motions registered by the app, by name.
  final Map<String, Motion> appMotions;

  /// Selects another track.
  final ValueChanged<Track<Object>> onTrackSelected;

  /// Replaces the track's motion, or restores it with null.
  final ValueChanged<Motion?> onChanged;

  @override
  State<MotionEditor> createState() => _MotionEditorState();
}

class _MotionEditorState extends State<MotionEditor> {
  static const _authored = 'Authored';
  static const _spring = 'Spring';
  static const _curve = 'Curve';

  /// The preset each track's motion was last picked from.
  final _presets = <Track<Object>, String>{};

  /// The spring being dragged, before it is applied on release.
  CupertinoMotion? _draft;

  String _presetOf(Motion? motion) {
    if (_presets[widget.track] case final preset?) return preset;
    if (motion == null) return _authored;
    for (final MapEntry(:key, :value) in widget.appMotions.entries) {
      if (value == motion) return key;
    }
    return motion is CurvedMotion ? _curve : _spring;
  }

  void _pick(String preset) {
    _presets[widget.track] = preset;
    final current = widget.current;
    final duration = switch (current) {
      CupertinoMotion(:final duration) ||
      CurvedMotion(:final duration) => duration,
      _ => const Duration(milliseconds: 500),
    };
    widget.onChanged(switch (preset) {
      _authored => null,
      _spring => CupertinoMotion(duration: duration, bounce: 0.2),
      _curve => CurvedMotion(duration, Curves.easeInOutCubic),
      _ => widget.appMotions[preset],
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final current = widget.current;
    final motion = _draft ?? current;
    final preset = _presetOf(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tracks.length > 1) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (track, name) in widget.tracks)
                Tag(
                  label: name,
                  selected: identical(track, widget.track),
                  marked: widget.tuned.contains(track),
                  onTap: () => widget.onTrackSelected(track),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final name in [
              _authored,
              ...widget.appMotions.keys,
              _spring,
              _curve,
            ])
              Tag(
                key: ValueKey('motor-devtools-motion-$name'),
                label: name,
                selected: name == preset,
                outlined: true,
                onTap: () => _pick(name),
              ),
          ],
        ),
        const SizedBox(height: 14),
        switch (motion) {
          null => Text(
            'The track plays the motions it was given. Pick another motion '
            'to try it; changes replay the latest plan and last for this '
            'session.',
            style: palette.caption,
          ),
          final CupertinoMotion spring => SpringGraph(
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
          final CurvedMotion curved => _CurveEditor(
            motion: curved,
            onChanged: widget.onChanged,
          ),
          _ => Text(
            'This motion plays as registered and cannot be tuned here.',
            style: palette.caption,
          ),
        },
        if (motion != null) ...[
          const SizedBox(height: 12),
          MotionPreview(motion: motion),
          if (codeFor(motion) case final code?) ...[
            const SizedBox(height: 10),
            _CodeLine(code: code),
          ],
        ],
      ],
    );
  }
}

/// A duration × bounce plane with a draggable handle for a spring.
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
                      child: CustomPaint(
                        painter: _SpringGraphPainter(handle, palette),
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

class _SpringGraphPainter extends CustomPainter {
  const _SpringGraphPainter(this.handle, this.palette);

  final Offset handle;
  final DevToolsPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(area, const Radius.circular(12)),
        Paint()..color = palette.fill,
      )
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(area, const Radius.circular(12)));
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
      ..drawCircle(point, 4.5, Paint()..color = palette.accent)
      ..restore();
  }

  @override
  bool shouldRepaint(_SpringGraphPainter oldDelegate) =>
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
/// that rides it.
class MotionPreview extends StatefulWidget {
  /// Previews [motion].
  const MotionPreview({required this.motion, super.key});

  /// The motion to preview.
  final Motion motion;

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
    _controller.motion = widget.motion;
    _play();
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
    return SizedBox(
      height: 64,
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
  });

  final List<double> samples;
  final double progress;
  final double value;
  final DevToolsPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final plot = Rect.fromLTRB(inset, inset, size.width - 40, size.height - 8);
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
