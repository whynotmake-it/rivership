import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/live_timeline.dart';
import 'package:motor_example/widgets/style.dart';

/// A thrown card clears the stack, then curves back under it.
class CardStackPage extends StatefulWidget {
  const CardStackPage({super.key});

  @override
  State<CardStackPage> createState() => _CardStackPageState();
}

enum _Phase { clearing, returning }

// One track, shared: every card has its own controller.
final _offset = Track<Offset>(
  .offset,
  initial: Offset.zero,
  motion: .bouncySpring(),
  debugLabel: 'Offset',
);

const _words = ['Clear', 'Redirect', 'Settle'];
const _friction = FrictionMotion(drag: .001, constantDeceleration: 200);
const _clearance = 300.0;

class _CardStackPageState extends State<CardStackPage>
    with TickerProviderStateMixin {
  late final _cards = [
    for (var i = 0; i < _words.length; i++)
      PhaseTrackController<_Phase>(
        vsync: this,
        // Releases pass the gesture's own velocity.
        velocityTracking: .off(),
        debugLabel: 'Card ${i + 1}',
      ),
  ];

  // Card indices from the top of the stack down.
  final _order = [0, 1, 2];
  var _lastThrown = 0;
  final _code = ValueNotifier(
    '// Throw the top card.\n'
    'card.playPhases(TrackPhaseTimeline({\n'
    '  clearing: [offset.to(out, motion: spring.trimmed(fromEnd: .9))],\n'
    '  returning: [offset.to(Offset.zero)],\n'
    '}));',
  );

  @override
  void dispose() {
    for (final card in _cards) {
      card.dispose();
    }
    _code.dispose();
    super.dispose();
  }

  void _drag(int card, DragUpdateDetails details) {
    final controller = _cards[card];
    final offset = controller.value(_offset) + details.delta;
    _code.value =
        '// Dragging: set() moves the card with your finger.\n'
        'card.set([offset.value(${_format(offset)})]);';
    controller.set([_offset.value(offset)]);
  }

  void _release(int card, DragEndDetails details) {
    final controller = _cards[card];
    final velocity = details.velocity.pixelsPerSecond;
    final landing = _friction.project(
      from: controller.value(_offset),
      velocity: velocity,
      converter: .offset,
    );
    setState(() => _lastThrown = card);
    if (landing.distance < 70) {
      _code.value =
          '// A gentle throw: spring straight back, at the throw\'s speed.\n'
          'card.animate([offset.to(Offset.zero, withVelocity: '
          '${_format(velocity)})]);';
      controller.animate([_offset.to(Offset.zero, withVelocity: velocity)]);
      return;
    }
    // Go at least far enough to clear the stack.
    final out = landing.distance > _clearance
        ? landing
        : landing / landing.distance * _clearance;
    _code.value =
        '// Thrown: clear the stack, then come back underneath.\n'
        'card.playPhases(TrackPhaseTimeline({\n'
        '  clearing: [offset.to(${_format(out)}, motion: spring.trimmed(fromEnd: .9))],\n'
        '  returning: [offset.to(Offset.zero)],\n'
        '}, initialVelocities: [offset.value(${_format(velocity)})]));';
    controller.playPhases(
      TrackPhaseTimeline(
        {
          // Only the start of the spring: it's cut while still moving, so the
          // next phase takes over its velocity and curves back.
          _Phase.clearing: [
            _offset.to(out, motion: .smoothSpring().trimmed(fromEnd: .9)),
          ],
          _Phase.returning: [_offset.to(Offset.zero)],
        },
        initialVelocities: [_offset.value(velocity)],
      ),
      onTransition: (transition) {
        if (transition case PhaseTransitioning(to: _Phase.returning)) {
          setState(
            () => _order
              ..remove(card)
              ..add(card),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Card stack'),
      lead:
          'Throw the top card. It flies far enough to clear the stack, then '
          'turns around and slides back underneath in one continuous path. '
          'The first phase uses only the start of a spring, so it ends while '
          'the card is still moving, and the second phase carries on at that '
          'speed. A gentle throw springs straight back.',
      code: _code,
      below: LiveTimeline(
        key: ValueKey(_lastThrown),
        controller: _cards[_lastThrown],
        lanes: {_offset: 'card ${_lastThrown + 1}'},
      ),
      stageHeight: 440,
      stage: Stack(
        children: [
          for (final card in _order.reversed)
            Center(
              key: ValueKey(card),
              child: _Card(
                index: card,
                depth: _order.indexOf(card),
                controller: _cards[card],
                onDrag: card == _order.first
                    ? (details) => _drag(card, details)
                    : null,
                onRelease: card == _order.first
                    ? (details) => _release(card, details)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.index,
    required this.depth,
    required this.controller,
    required this.onDrag,
    required this.onRelease,
  });

  final int index;
  final int depth;
  final TrackController controller;
  final GestureDragUpdateCallback? onDrag;
  final GestureDragEndCallback? onRelease;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SingleMotionBuilder(
      value: depth.toDouble(),
      motion: const .smoothSpring(duration: Duration(milliseconds: 350)),
      debugLabel: 'Card ${index + 1} depth',
      builder: (context, depth, child) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final offset = controller.value(_offset);
          return Transform.translate(
            offset: offset + Offset(0, -depth * 14),
            child: Transform.rotate(
              // Cards behind rest a little crooked.
              angle: (index.isEven ? -1 : 1) * depth * .035 + offset.dx / 900,
              child: Transform.scale(scale: 1 - depth * .05, child: child),
            ),
          );
        },
        child: child,
      ),
      child: GestureDetector(
        onPanUpdate: onDrag,
        onPanEnd: onRelease,
        child: Container(
          width: 220,
          height: 280,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: index == 0 ? p.accent : p.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: index == 0 ? p.accent : p.borderStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                _words[index],
                style: p.display.copyWith(
                  fontSize: 36,
                  color: index == 0 ? p.onAccent : p.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _format(Offset offset) =>
    'Offset(${offset.dx.round()}, ${offset.dy.round()})';
