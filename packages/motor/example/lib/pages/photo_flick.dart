import 'dart:ui' show lerpDouble;

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

  /// The opened photo's center, relative to the stage center. Doubles as the
  /// open/close travel (slot → center → slot) and the flick position, so one
  /// continuous value carries the photo through its whole story.
  final _position = Track(.offset, initial: Offset.zero);

  /// 0 = resting in its grid slot, 1 = opened large.
  final _zoom = Track<double>(.single, initial: 0);

  static const _single = CupertinoMotion.smooth(
    duration: Duration(milliseconds: 650),
    extraBounce: .1,
  );
  static const _perDimension = [
    CupertinoMotion.snappy(),
    CupertinoMotion.bouncy(extraBounce: .35),
  ];
  static const _openClose = CupertinoMotion.smooth(
    duration: Duration(milliseconds: 450),
    extraBounce: .05,
  );

  /// The dismissal return: long enough that a hard fling visibly carries the
  /// photo outward before the spring curves it home into its slot.
  static const _goHome = CupertinoMotion.smooth(
    duration: Duration(milliseconds: 700),
  );
  static const _friction = FrictionMotion(
    drag: .001,
    constantDeceleration: 200,
  );
  static const _dismissThreshold = 180.0;

  static const _smallSize = Size(112, 92);
  static const _largeSize = Size(190, 230);
  static const _gridGap = 14.0;

  /// The center of grid slot [index] (2×2 grid), relative to stage center.
  static Offset _slotOffset(int index) => Offset(
    (index.isEven ? -1 : 1) * (_smallSize.width + _gridGap) / 2,
    (index < 2 ? -1 : 1) * (_smallSize.height + _gridGap) / 2,
  );

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
    // The photo has settled back into its slot at grid size, so swapping in
    // the static grid tile is invisible.
    setState(() {
      _dismissing = false;
      _openedPhoto = null;
      _xTrace.clear();
      _yTrace.clear();
    });
  }

  void _openPhoto(int index) {
    if (_openedPhoto != null) return;
    // Anchor both tracks at the slot's resting state, then animate position
    // and zoom together so the photo grows out of its grid slot.
    _controller.set([
      _position.value(_slotOffset(index)),
      _zoom.value(0),
    ]);
    setState(() {
      _openedPhoto = index;
      _dismissing = false;
      _xTrace.clear();
      _yTrace.clear();
    });
    _controller.animate([
      _position.to(Offset.zero, motion: _openClose),
      _zoom.to(1, motion: _openClose),
    ]);
  }

  void _onPanStart(DragStartDetails _) {
    // Stop only the position track: the finger owns it now. If the photo was
    // caught mid-dismissal, grow it back to full size while the drag goes on.
    _controller.stop(tracks: [_position], canceled: true);
    if (_dismissing) {
      _controller.animate([_zoom.to(1, motion: _openClose)]);
    }
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
      // Dismiss: the fling velocity carries the photo outward while the
      // spring bends its path home, shrinking it back into its grid slot.
      setState(() => _dismissing = true);
      _controller.animate([
        _position.to(
          _slotOffset(_openedPhoto!),
          motion: _goHome,
          withVelocity: velocity,
        ),
        _zoom.to(0, motion: _goHome),
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
          'their own velocity and can settle on different springs — flick '
          'hard and it carries that velocity home into its grid slot.',
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
              child: SizedBox.expand(
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
                    // All four photos stay in the tree; the opened one leaves
                    // its slot and animates above the others.
                    for (var index = 0; index < 4; index++)
                      if (index != _openedPhoto)
                        Transform.translate(
                          offset: _slotOffset(index),
                          child: GestureDetector(
                            key: ValueKey('photo-$index'),
                            onTap: () => _openPhoto(index),
                            child: _Photo(index: index),
                          ),
                        ),
                    if (_openedPhoto case final opened?)
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => Transform.translate(
                          offset: _controller.value(_position),
                          child: GestureDetector(
                            key: const ValueKey('opened-photo'),
                            behavior: HitTestBehavior.opaque,
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: _Photo(
                              index: opened,
                              zoom: _controller.value(_zoom),
                            ),
                          ),
                        ),
                      ),
                  ],
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

class _Photo extends StatelessWidget {
  const _Photo({required this.index, this.zoom = 0});

  final int index;

  /// Blend between grid-tile size (0) and opened size (1).
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final shades = [t.textPrimary, t.textSecondary, t.borderStrong, t.pebble];
    final small = _PhotoFlickPageState._smallSize;
    final large = _PhotoFlickPageState._largeSize;
    return Container(
      width: lerpDouble(small.width, large.width, zoom),
      height: lerpDouble(small.height, large.height, zoom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            shades[index].withValues(alpha: .9),
            shades[(index + 1) % shades.length].withValues(alpha: .55),
          ],
        ),
        borderRadius: BorderRadius.circular(lerpDouble(14, 22, zoom)!),
        border: Border.all(color: t.border),
        boxShadow: t.softShadow,
      ),
      child: Icon(
        CupertinoIcons.photo_fill,
        color: t.surfaceSolid.withValues(alpha: .75),
        size: lerpDouble(24, 42, zoom),
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
