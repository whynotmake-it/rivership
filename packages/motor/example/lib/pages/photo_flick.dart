import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// A free 2D photo flick with independent motion and projection per axis.
class PhotoFlickPage extends StatefulWidget {
  const PhotoFlickPage({super.key});

  static const routeName = 'More Than One Dimension';

  @override
  State<PhotoFlickPage> createState() => _PhotoFlickPageState();
}

class _PhotoFlickPageState extends State<PhotoFlickPage>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);
  final _position = Track(.offset, initial: Offset.zero);

  static const _single = CupertinoMotion.smooth(
    duration: Duration(milliseconds: 650),
    extraBounce: .1,
  );
  static const _perDimension = [
    CupertinoMotion.snappy(),
    CupertinoMotion.bouncy(extraBounce: .35),
  ];
  static const _friction = FrictionMotion(
    drag: .001,
    constantDeceleration: 200,
  );
  static const _dismissThreshold = 180.0;

  final List<double> _xTrace = [];
  final List<double> _yTrace = [];
  int? _openedPhoto;
  bool _independent = false;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_recordPosition)
      ..addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_recordPosition)
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  void _recordPosition() {
    if (_openedPhoto == null) return;
    final position = _controller.value(_position);
    _xTrace.add(position.dx);
    _yTrace.add(position.dy);
    if (_xTrace.length > 60) {
      _xTrace.removeAt(0);
      _yTrace.removeAt(0);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_dismissing || !mounted) {
      return;
    }
    _controller.set([_position.value(Offset.zero)]);
    setState(() {
      _dismissing = false;
      _openedPhoto = null;
      _xTrace.clear();
      _yTrace.clear();
    });
  }

  void _openPhoto(int index) {
    _controller.set([_position.value(Offset.zero)]);
    setState(() {
      _openedPhoto = index;
      _dismissing = false;
      _xTrace.clear();
      _yTrace.clear();
    });
  }

  void _onPanStart(DragStartDetails _) {
    _controller.stop(canceled: true);
    setState(() {
      _dismissing = false;
      _xTrace.clear();
      _yTrace.clear();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final next = _controller.value(_position) + details.delta;
    _controller.set([_position.value(next)]);
  }

  void _onPanEnd(DragEndDetails details) {
    final current = _controller.value(_position);
    final velocity = details.velocity.pixelsPerSecond;
    final projected = _friction.project(
      from: current,
      velocity: velocity,
      converter: .offset,
    );

    if (projected.distance > _dismissThreshold) {
      final direction = projected.distance == 0
          ? const Offset(0, 1)
          : projected / projected.distance;
      final target = direction * math.max(projected.distance, 520);
      setState(() => _dismissing = true);
      _controller.animate([
        _position.to(
          target,
          motion: .smoothSpring().trimmed(fromEnd: .86),
          withVelocity: velocity,
        ),
      ]);
      return;
    }

    _controller.animate([
      if (_independent)
        _position.to(
          Offset.zero,
          motionPerDimension: _perDimension,
          withVelocity: velocity,
        )
      else
        _position.to(Offset.zero, motion: _single, withVelocity: velocity),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: PhotoFlickPage.routeName,
      next: (label: 'Meet Tracks', routeName: 'Meet Tracks'),
      description:
          'Open a photo and flick it freely. Its X and Y projections keep '
          'their own velocity and can settle on different springs.',
      action: Row(
        children: [
          CupertinoSwitch(
            value: _independent,
            activeTrackColor: t.textPrimary,
            onChanged: (value) => setState(() => _independent = value),
          ),
          const SizedBox(width: 12),
          Text(
            'Independent axes',
            style: TextStyle(color: t.textSecondary, fontSize: 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const ValueKey('photo-stage'),
            height: 390,
            child: Stage(
              label: _openedPhoto == null
                  ? 'Tap a photo'
                  : 'Drag & flick the photo',
              padding: EdgeInsets.zero,
              child: LayoutBuilder(
                builder: (context, constraints) => SizedBox.expand(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) => CustomPaint(
                            painter: _ProjectionPainter(
                              theme: t,
                              position: _controller.value(_position),
                              xTrace: _xTrace,
                              yTrace: _yTrace,
                            ),
                          ),
                        ),
                      ),
                      if (_openedPhoto == null)
                        _PhotoGrid(onOpen: _openPhoto)
                      else
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) => Transform.translate(
                            offset: _controller.value(_position),
                            child: child,
                          ),
                          child: GestureDetector(
                            key: const ValueKey('opened-photo'),
                            behavior: HitTestBehavior.opaque,
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: _Photo(index: _openedPhoto!, large: true),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TakeawayText(
            'One Offset track, one spring per axis — velocity is preserved per '
            'dimension, which a single-clock curve cannot express.',
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (var index = 0; index < 4; index++)
            GestureDetector(
              key: ValueKey('photo-$index'),
              onTap: () => onOpen(index),
              child: _Photo(index: index),
            ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.index, this.large = false});

  final int index;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final shades = [t.textPrimary, t.textSecondary, t.borderStrong, t.pebble];
    return Container(
      width: large ? 190 : 112,
      height: large ? 230 : 92,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            shades[index].withValues(alpha: .9),
            shades[(index + 1) % shades.length].withValues(alpha: .55),
          ],
        ),
        borderRadius: BorderRadius.circular(large ? 22 : 14),
        border: Border.all(color: t.border),
        boxShadow: t.softShadow,
      ),
      child: Icon(
        CupertinoIcons.photo_fill,
        color: t.surfaceSolid.withValues(alpha: .75),
        size: large ? 42 : 24,
      ),
    );
  }
}

class _ProjectionPainter extends CustomPainter {
  _ProjectionPainter({
    required this.theme,
    required this.position,
    required this.xTrace,
    required this.yTrace,
  });

  final ExampleTheme theme;
  final Offset position;
  final List<double> xTrace;
  final List<double> yTrace;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 24.0;
    final center = size.center(Offset.zero);
    final horizontalY = size.height - inset;
    final verticalX = inset;
    final axisPaint = Paint()
      ..color = theme.borderStrong
      ..strokeWidth = 1;
    canvas
      ..drawLine(
        Offset(inset, horizontalY),
        Offset(size.width - inset, horizontalY),
        axisPaint,
      )
      ..drawLine(
        Offset(verticalX, inset),
        Offset(verticalX, size.height - inset),
        axisPaint,
      );

    _drawTrace(canvas, [
      for (var index = 0; index < xTrace.length; index++)
        Offset(center.dx + xTrace[index], horizontalY),
    ]);
    _drawTrace(canvas, [
      for (var index = 0; index < yTrace.length; index++)
        Offset(verticalX, center.dy + yTrace[index]),
    ]);

    final dotPaint = Paint()..color = theme.textPrimary;
    canvas
      ..drawCircle(Offset(center.dx + position.dx, horizontalY), 5, dotPaint)
      ..drawCircle(Offset(verticalX, center.dy + position.dy), 5, dotPaint);
  }

  void _drawTrace(Canvas canvas, List<Offset> points) {
    if (points.length < 2) return;
    for (var index = 1; index < points.length; index++) {
      final opacity = index / points.length;
      canvas.drawLine(
        points[index - 1],
        points[index],
        Paint()
          ..color = theme.textSecondary.withValues(alpha: opacity * .65)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ProjectionPainter oldDelegate) => true;
}
