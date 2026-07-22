import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/timeline_inspector.dart';

/// A boarding pass whose causal timeline stays live to the user's hand.
class BoardingPassPage extends StatefulWidget {
  const BoardingPassPage({super.key});

  static const routeName = 'Boarding Pass';

  @override
  State<BoardingPassPage> createState() => _BoardingPassPageState();
}

const _ticketStart = Offset(0, 280);
const _ticketStartAngle = 5 * math.pi / 180;
const _routeLetters = 'CGN → LIS';

/// The ticket spring's design duration — also where the lanes draw #landed.
const _ticketLanding = Duration(milliseconds: 520);
const _letterStagger = Duration(milliseconds: 45);
const _letterReveal = Duration(milliseconds: 260);

/// Projected horizontal travel of the release gesture (not the ticket's
/// inherited momentum) required to read as a deliberate dismissal fling.
const _dismissTravel = 200.0;

class _BoardingPassPageState extends State<BoardingPassPage>
    with TickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);

  final _ticketPos = Track<Offset>(.offset, initial: _ticketStart);
  final _ticketAngle = Track<double>(.single, initial: _ticketStartAngle);
  final _letterTracks = [
    for (var i = 0; i < _routeLetters.length; i++)
      Track<double>(.single, initial: 0),
  ];
  final _barcode = Track<double>(.single, initial: 0);
  final _gateChip = Track<double>(.single, initial: 0);

  Offset _velocityBeforeDrag = Offset.zero;
  Offset _dragDelta = Offset.zero;
  bool _dismissed = false;
  int _flyOutGeneration = 0;

  late final TrackTimeline _entranceTimeline = TrackTimeline([
    // The ticket arrives first. Its real upward velocity makes the spring
    // overshoot before both physical tracks meet the landing barrier.
    _ticketPos([
      .to(Offset.zero, motion: .smoothSpring(duration: _ticketLanding)),
      .sync(token: #landed),
    ], withVelocity: const Offset(0, -900)),
    _ticketAngle([
      .to(
        0,
        motion: .smoothSpring(duration: const Duration(milliseconds: 480)),
      ),
      .sync(token: #landed),
    ]),
    // Every glyph waits for the landing, then owns its stagger as timeline
    // data. There are no widget-local timers.
    for (final (index, track) in _letterTracks.indexed)
      track([
        .sync(token: #landed),
        .hold(_letterStagger * index),
        .to(1, motion: const CurvedMotion(_letterReveal, Curves.easeOutCubic)),
      ]),
    _barcode([
      .sync(token: #landed),
      .to(
        1,
        motion: const CurvedMotion(
          Duration(milliseconds: 520),
          Curves.easeOutCubic,
        ),
      ),
    ]),
    // This deliberately finishes last, so the gate reads as the final fact
    // revealed by the landing.
    _gateChip([
      .sync(token: #landed),
      .hold(const Duration(milliseconds: 430)),
      .to(1, motion: .bouncySpring(extraBounce: .35).trimmed(fromEnd: .45)),
    ]),
  ]);

  @override
  void initState() {
    super.initState();
    _resetAndPlayEntrance();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _rebook() => _resetAndPlayEntrance();

  void _resetAndPlayEntrance() {
    _dragDelta = Offset.zero;
    _dismissed = false;
    _flyOutGeneration += 1;
    _controller
      ..set([
        _ticketPos.value(_ticketStart),
        _ticketAngle.value(_ticketStartAngle),
        for (final track in _letterTracks) track.value(0),
        _barcode.value(0),
        _gateChip.value(0),
      ])
      ..play(_entranceTimeline);
  }

  void _onPanStart(DragStartDetails _) {
    // set() disposes only the position track's remaining steps. Capture its
    // entrance momentum first so the hand can add to it on release.
    _velocityBeforeDrag = _controller.velocity(_ticketPos);
    _dragDelta = Offset.zero;
    _flyOutGeneration += 1;
    // Leave the lanes on their current plan: every other track keeps
    // following it while the hand owns only the ticket's position.
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragDelta += details.delta;
    _controller.set([
      _ticketPos.value(_controller.value(_ticketPos) + details.delta),
    ]);
  }

  void _onPanEnd(DragEndDetails details) {
    final gestureVelocity = details.velocity.pixelsPerSecond;
    // Merging the pre-drag momentum back in keeps the release spring
    // continuous with whatever the ticket was already doing.
    final mergedVelocity = _velocityBeforeDrag + gestureVelocity;

    if (_dragDelta.dy > 80 && _dragDelta.dy.abs() > _dragDelta.dx.abs()) {
      _rebook();
      return;
    }

    const friction = FrictionMotion(drag: 0.001, constantDeceleration: 200);
    final current = _controller.value(_ticketPos);
    // The dismissal decision judges the hand alone: mid-entrance the
    // inherited momentum can be huge (the -900 arrival velocity), and the
    // old position-based test (`projected.dx.abs() > 100`) dismissed after
    // any ~100px sideways displacement, even for a gentle release. Only a
    // deliberate horizontal fling — enough gesture velocity to coast past
    // [_dismissTravel] — sends the ticket away.
    final gestureProjected = friction.project(
      from: current,
      velocity: gestureVelocity,
      converter: .offset,
    );
    final projectedTravel = gestureProjected.dx - current.dx;

    if (projectedTravel.abs() > _dismissTravel) {
      final target = Offset(
        projectedTravel.sign * 720,
        gestureProjected.dy.clamp(-300.0, 300.0),
      );
      final flyOut = _ticketPos.to(
        target,
        motion: .smoothSpring(
          duration: const Duration(milliseconds: 420),
        ).trimmed(fromEnd: .88),
        withVelocity: mergedVelocity,
      );
      final generation = ++_flyOutGeneration;
      // Once the fly-out lands, surface a way back: the stage would
      // otherwise dead-end as an empty rectangle.
      _controller.animate([flyOut]).whenCompleteOrCancel(() {
        if (!mounted || generation != _flyOutGeneration) return;
        setState(() => _dismissed = true);
      });
      return;
    }

    // The other tracks never stopped. Replacing only this track with a
    // barrier-ending spring lets it rejoin their in-flight choreography.
    final springBack = _ticketPos([
      .to(
        Offset.zero,
        motion: .smoothSpring(duration: const Duration(milliseconds: 420)),
      ),
      .sync(token: #landed),
    ], withVelocity: mergedVelocity);
    _controller.animate([springBack]);
  }

  void _onPanCancel() {
    final springBack = _ticketPos([
      .to(
        Offset.zero,
        motion: .smoothSpring(duration: const Duration(milliseconds: 420)),
      ),
      .sync(token: #landed),
    ]);
    _controller.animate([springBack]);
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: BoardingPassPage.routeName,
      description:
          'One disposable plan lands the ticket, releases its contents through '
          'a sync barrier, and stays interruptible by your hand throughout.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: NeutralButton(onPressed: _rebook, child: const Text('Re-book')),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 420,
            child: Stage(
              key: const ValueKey('boarding-pass-stage'),
              label: 'Book flight',
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_dismissed)
                        NeutralButton(
                          key: const ValueKey('boarding-pass-rebook-empty'),
                          onPressed: _rebook,
                          child: const Text('Book another flight'),
                        ),
                      Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          onPanCancel: _onPanCancel,
                          child: Transform.translate(
                            offset: _controller.value(_ticketPos),
                            child: Transform.rotate(
                              angle: _controller.value(_ticketAngle),
                              child: _BoardingTicket(
                                letterValues: [
                                  for (final track in _letterTracks)
                                    _controller.value(track),
                                ],
                                barcode: _controller.value(_barcode),
                                gateScale: _controller.value(_gateChip),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Surface(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TimelineInspector(
              controller: _controller,
              laneGroups: [
                {..._letterTracks},
              ],
              laneLabels: {
                _ticketPos: 'ticket',
                _ticketAngle: 'tilt',
                _letterTracks.first: 'letters',
                _barcode: 'barcode',
                _gateChip: 'gate',
              },
              laneColors: {
                _ticketPos: ExampleTheme.signalBlue,
                _ticketAngle: ExampleTheme.roseQuartz,
                _letterTracks.first: ExampleTheme.marigold,
                _barcode: ExampleTheme.spectrumRed,
                _gateChip: ExampleTheme.signalBlue,
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardingTicket extends StatelessWidget {
  const _BoardingTicket({
    required this.letterValues,
    required this.barcode,
    required this.gateScale,
  });

  final List<double> letterValues;
  final double barcode;
  final double gateScale;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      key: const ValueKey('boarding-pass-ticket'),
      width: 280,
      height: 150,
      padding: const EdgeInsets.all(18),
      decoration: ShapeDecoration(
        color: t.surfaceSolid,
        shape: RoundedSuperellipseBorder(
          side: BorderSide(color: t.border),
          borderRadius: BorderRadius.circular(22),
        ),
        shadows: t.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIVERSHIP AIR',
                  style: TextStyle(
                    color: t.textTertiary,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontFamily: 'JetBrains Mono',
                    fontFamilyFallback: const ['monospace', 'Menlo'],
                  ),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (index, letter)
                          in _routeLetters.split('').indexed)
                        _RouteLetter(
                          letter: letter,
                          value: letterValues[index],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '22 JUL  ·  14:40',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 10,
                    fontFamily: 'JetBrains Mono',
                    fontFamilyFallback: const ['monospace', 'Menlo'],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: t.border,
          ),
          SizedBox(
            width: 54,
            child: Column(
              children: [
                Transform.scale(
                  key: const ValueKey('boarding-pass-gate'),
                  scale: gateScale.clamp(0.0, 1.25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: t.textPrimary,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      'GATE\nB12',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: t.surfaceSolid,
                        fontSize: 9,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'JetBrains Mono',
                        fontFamilyFallback: const ['monospace', 'Menlo'],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 50,
                  width: 50,
                  child: CustomPaint(
                    painter: _BarcodePainter(
                      progress: barcode.clamp(0.0, 1.0),
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLetter extends StatelessWidget {
  const _RouteLetter({required this.letter, required this.value});

  final String letter;
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final progress = value.clamp(0.0, 1.0);
    return Text(
      letter,
      style: TextStyle(
        color: t.textPrimary.withValues(alpha: progress),
        fontFamily: 'Archivo',
        fontSize: 27,
        height: 1,
        fontVariations: [
          FontVariation('wght', 200 + 500 * progress),
          FontVariation('wdth', 78 + 22 * progress),
        ],
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height),
    );
    const widths = [2.0, 1.0, 3.0, 1.0, 2.0, 4.0, 1.0, 3.0, 2.0, 1.0];
    var x = 0.0;
    final paint = Paint()..color = color;
    for (final width in widths) {
      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
      x += width + 2;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
