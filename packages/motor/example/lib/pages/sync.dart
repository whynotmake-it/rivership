import 'dart:math' as math;

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
@immutable
class _Card {
  const _Card(this.position, this.flip);

  final Offset position;
  final double flip;

  @override
  String toString() => 'flip ${flip.toStringAsFixed(2)}';
}

final _cardConverter = MotionConverter<_Card>.custom(
  normalize: (card) => [card.position.dx, card.position.dy, card.flip],
  denormalize: (values) => _Card(Offset(values[0], values[1]), values[2]),
);

const _deck = Offset(0, 96);
const _faces = [
  ('A', 'Ace', CupertinoIcons.suit_heart_fill),
  ('K', 'King', CupertinoIcons.suit_spade_fill),
  ('Q', 'Queen', CupertinoIcons.suit_diamond_fill),
];
// Offsets from the stage center, and how long each deal takes. Curves arrive
// exactly on time, so the wait at the barrier is easy to see.
const _spots = [Offset(-112, -64), Offset(0, -64), Offset(112, -64)];
const _flights = [900, 350, 600];

class _SyncPageState extends State<SyncPage>
    with SingleTickerProviderStateMixin {
  late final _dealer = TrackController(vsync: this, debugLabel: 'Card deal');

  final _cards = [
    for (final (_, name, _) in _faces)
      Track<_Card>(_cardConverter, initial: _Card(_deck, 0), debugLabel: name),
  ];

  var _together = true;

  @override
  void initState() {
    super.initState();
    // After the first frame, so the timeline is listening when the deal starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _deal();
    });
  }

  @override
  void dispose() {
    _dealer.dispose();
    _code.dispose();
    super.dispose();
  }

  TrackTimeline get _timeline => TrackTimeline([
    for (final (index, card) in _cards.indexed)
      card([
        .hold(Duration(milliseconds: 90 * index)),
        .to(
          _Card(_spots[index], 0),
          motion: .curved(
            Duration(milliseconds: _flights[index]),
            Curves.easeOutCubic,
          ),
        ),
        // One token for everyone, or one per card.
        .sync(token: _together ? #dealt : index),
        .to(
          _Card(_spots[index], 1),
          motion: .bouncySpring(duration: Duration(milliseconds: 650)),
        ),
      ]),
  ]);

  final _code = ValueNotifier('');

  void _deal() {
    _code.value = _together
        ? '// One token: the cards that land early wait for the last.\n'
              'card([.to(spot), .sync(token: #dealt), .to(faceUp)])'
        : '// A token per card: each flips as soon as it lands.\n'
              'card([.to(spot), .sync(token: index), .to(faceUp)])';
    final timeline = _timeline;
    _dealer
      ..set(timeline.startValues)
      ..play(timeline);
  }

  @override
  Widget build(BuildContext context) {
    final t = Palette.of(context);
    return ChapterPage(
      chapter: chapterNamed('Sync'),
      lead:
          'Three cards fly out on curves of different lengths, then flip on a '
          'spring. When they share a sync token, the cards that land first '
          'wait at the barrier until the last one arrives, so no durations '
          'need lining up by hand. Give each card its own token and it flips '
          'as soon as it lands.',
      code: _code,
      below: LiveTimeline(
        controller: _dealer,
        lanes: {for (final card in _cards) card: card.debugLabel!},
      ),
      stageHeight: 440,
      stage: Stack(
        children: [
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: SingleMotionBuilder(
              value: _together ? 0 : 1,
              motion: const .smoothSpring(),
              debugLabel: 'Sync note',
              builder: (context, shown, child) => Reveal(
                progress: shown,
                offset: const Offset(0, -8),
                child: child!,
              ),
              child: Text(
                'A barrier waits until a spring has fully settled, often two '
                'to three times its nominal duration. To sync on the moment a '
                'card visibly lands, give that step a fixed length: '
                'motion.scaleTo(d), a curve, or an .at keyframe.',
                textAlign: .center,
                style: t.caption,
              ),
            ),
          ),
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
              mainAxisAlignment: .spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: .scaleDown,
                    alignment: .centerLeft,
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
        alignment: .center,
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
                alignment: .center,
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
    final t = Palette.of(context);
    return Container(
      width: _cardSize.width,
      height: _cardSize.height,
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: .circular(6),
        boxShadow: [
          if (stacked)
            for (var i = 1; i <= 3; i++)
              BoxShadow(
                color: i.isOdd ? t.canvas : t.accent,
                offset: Offset(0, i * 2.0),
              ),
        ],
      ),
      child: Center(
        child: Text('m', style: archivo(32, weight: 700, color: t.onAccent)),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.face});

  final (String, String, IconData) face;

  @override
  Widget build(BuildContext context) {
    final t = Palette.of(context);
    final (rank, _, suit) = face;
    final color = suit == CupertinoIcons.suit_spade_fill ? t.text : t.accent;
    return Container(
      width: _cardSize.width,
      height: _cardSize.height,
      padding: const .all(10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: .circular(6),
        border: Border.all(color: t.borderStrong),
      ),
      child: Stack(
        children: [
          Text(rank, style: mono(16, weight: 600, color: color)),
          Center(child: Icon(suit, size: 38, color: color)),
        ],
      ),
    );
  }
}
