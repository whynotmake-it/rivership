import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/controls.dart';
import 'package:motor_example/widgets/live_timeline.dart';
import 'package:motor_example/widgets/style.dart';

/// Tracks that share a sync token wait for each other.
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

/// A card is one three-dimensional value: where it is and how far it flipped.
typedef _Card = ({Offset position, double flip});

final _cardConverter = MotionConverter<_Card>.custom(
  normalize: (card) => [card.position.dx, card.position.dy, card.flip],
  denormalize: (values) =>
      (position: Offset(values[0], values[1]), flip: values[2]),
);

const _deck = Offset(0, 96);
const _faces = [
  ('A', 'Ace', CupertinoIcons.suit_heart_fill),
  ('K', 'King', CupertinoIcons.suit_spade_fill),
  ('Q', 'Queen', CupertinoIcons.suit_diamond_fill),
];
// Offsets from the stage center, and how long each deal takes. Curves arrive
// exactly on time, so the wait at the barrier is easy to see.
const _spots = [Offset(-112, -76), Offset(0, -76), Offset(112, -76)];
const _flights = [900, 350, 600];

class _SyncPageState extends State<SyncPage>
    with SingleTickerProviderStateMixin {
  late final _dealer = TrackController(vsync: this, debugLabel: 'Card deal');

  final _cards = [
    for (final (_, name, _) in _faces)
      Track<_Card>(
        _cardConverter,
        initial: (position: _deck, flip: 0),
        debugLabel: name,
      ),
  ];

  var _together = true;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _dealer.dispose();
    super.dispose();
  }

  TrackTimeline get _timeline => TrackTimeline([
    for (final (index, card) in _cards.indexed)
      card([
        .hold(Duration(milliseconds: 90 * index)),
        .to(
          (position: _spots[index], flip: 0),
          motion: .curved(
            Duration(milliseconds: _flights[index]),
            Curves.easeOutCubic,
          ),
        ),
        // One token for everyone, or one per card.
        .sync(token: _together ? #dealt : index),
        .to((
          position: _spots[index],
          flip: 1,
        ), motion: .bouncySpring(duration: Duration(milliseconds: 650))),
      ]),
  ]);

  void _deal() {
    final timeline = _timeline;
    _dealer
      ..set(timeline.startValues)
      ..play(timeline);
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Sync'),
      lead:
          'Three cards fly out, each taking its own time. With one shared '
          'token they wait at the barrier and flip together. With a token '
          'each, every card flips the moment it lands.',
      code: 'card([.to(spot), .sync(token: #dealt), .to(faceUp)])',
      below: LiveTimeline(
        controller: _dealer,
        lanes: {for (final card in _cards) card: card.debugLabel!},
      ),
      stageHeight: 440,
      stage: Stack(
        children: [
          Center(
            child: Transform.translate(
              offset: _deck,
              child: const _CardBack(stacked: true),
            ),
          ),
          AnimatedBuilder(
            animation: _dealer,
            builder: (context, _) => Stack(
              children: [
                for (final (index, card) in _cards.indexed)
                  Center(
                    child: _FlyingCard(
                      card: _dealer.value(card),
                      face: _faces[index],
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Choice(
                      options: const ['Together', 'On landing'],
                      selected: _together ? 0 : 1,
                      onSelect: (index) {
                        setState(() => _together = index == 0);
                        _deal();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PillButton(
                  label: 'Deal',
                  icon: CupertinoIcons.arrow_counterclockwise,
                  onTap: _deal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _cardSize = Size(88, 124);

class _FlyingCard extends StatelessWidget {
  const _FlyingCard({required this.card, required this.face});

  final _Card card;
  final (String, String, IconData) face;

  @override
  Widget build(BuildContext context) {
    final angle = card.flip * math.pi;
    final showFront = card.flip > .5;
    return Transform.translate(
      offset: card.position,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0015)
          ..rotateY(angle)
          ..scaleByDouble(
            1 + math.sin(angle) * .1,
            1 + math.sin(angle) * .1,
            1,
            1,
          ),
        child: showFront
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: _CardFront(face: face),
              )
            : const _CardBack(),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({this.stacked = false});

  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      width: _cardSize.width,
      height: _cardSize.height,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (stacked)
            for (var i = 1; i <= 3; i++)
              BoxShadow(
                color: const Color(0xFF16161A).withValues(alpha: .5),
                offset: Offset(0, i * 2.5),
              ),
          ...t.softShadow,
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ExampleTheme.signalBlue, ExampleTheme.roseQuartz],
          ),
        ),
        child: Center(
          child: Text(
            'm',
            style: archivo(
              30,
              weight: 700,
              width: 125,
            ).copyWith(color: CupertinoColors.white.withValues(alpha: .85)),
          ),
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.face});

  final (String, String, IconData) face;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final (rank, _, suit) = face;
    final color = suit == CupertinoIcons.suit_spade_fill
        ? const Color(0xFF111113)
        : ExampleTheme.spectrumRed;
    return Container(
      width: _cardSize.width,
      height: _cardSize.height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
        boxShadow: t.softShadow,
      ),
      child: Stack(
        children: [
          Text(rank, style: archivo(18, weight: 640, color: color)),
          Center(child: Icon(suit, size: 38, color: color)),
        ],
      ),
    );
  }
}
