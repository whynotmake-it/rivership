import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/live_timeline.dart';
import 'package:motor_example/widgets/style.dart';

/// One controller animates five values, each with its own motion.
class TracksPage extends StatefulWidget {
  const TracksPage({super.key});

  @override
  State<TracksPage> createState() => _TracksPageState();
}

const _closed = Size(60, 60);
const _open = Size(236, 220);

class _TracksPageState extends State<TracksPage>
    with SingleTickerProviderStateMixin {
  late final _menu = TrackController(vsync: this, debugLabel: 'Menu morph');

  final _size = Track<Size>(
    .size,
    initial: _closed,
    motion: .bouncySpring(duration: Duration(milliseconds: 560)),
    debugLabel: 'Size',
  );
  final _radius = Track<double>(
    .single,
    initial: 30,
    motion: .smoothSpring(),
    debugLabel: 'Radius',
  );
  final _content = Track<double>(.single, initial: 0, debugLabel: 'Content');
  final _turn = Track<double>(
    .single,
    initial: 0,
    motion: .bouncySpring(extraBounce: .15),
    debugLabel: 'Icon turn',
  );
  final _backdrop = Track<double>(
    .single,
    initial: 0,
    motion: .smoothSpring(duration: Duration(milliseconds: 700)),
    debugLabel: 'Backdrop',
  );

  var _isOpen = false;

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  void _toggle() {
    _isOpen = !_isOpen;
    _menu.animate([
      _size.to(_isOpen ? _open : _closed),
      _radius.to(_isOpen ? 26 : 30),
      // Content arrives late and leaves early.
      _content.to(
        _isOpen ? 1 : 0,
        motion: _isOpen
            ? const .smoothSpring(duration: Duration(milliseconds: 650))
            : const .snappySpring(duration: Duration(milliseconds: 220)),
      ),
      _turn.to(_isOpen ? 1 / 8 : 0),
      _backdrop.to(_isOpen ? 1 : 0),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ChapterPage(
      chapter: chapterNamed('Tracks'),
      lead:
          'Tap the button, then tap again mid-morph. Size, radius, content, '
          'icon and backdrop are five tracks on one controller. Each has its '
          'own spring, and each turns around without losing speed.',
      code: 'menu.animate([size.to(open), content.to(1), turn.to(1 / 8)]);',
      below: LiveTimeline(
        controller: _menu,
        lanes: {
          _size: 'size',
          _radius: 'radius',
          _content: 'content',
          _turn: 'icon',
          _backdrop: 'backdrop',
        },
      ),
      stage: AnimatedBuilder(
        animation: _menu,
        builder: (context, _) {
          final value = _menu.value;
          final size = value(_size);
          final content = value(_content);
          final backdrop = value(_backdrop);
          return Stack(
            children: [
              GestureDetector(
                onTap: _isOpen ? _toggle : null,
                child: Blur(
                  sigma: Offset(backdrop, backdrop) * 5,
                  child: Opacity(
                    opacity: 1 - backdrop * .35,
                    child: const _Notes(),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: 20,
                width: math.max(size.width, 0),
                height: math.max(size.height, 0),
                child: GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: t.textPrimary,
                      borderRadius: BorderRadius.circular(value(_radius)),
                      boxShadow: t.softShadow,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          bottom: 0,
                          width: _open.width,
                          height: _open.height,
                          child: Reveal(
                            progress: content,
                            offset: const Offset(0, 20),
                            blur: 10,
                            child: _MenuItems(color: t.canvas),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          width: _closed.width,
                          height: _closed.height,
                          child: Transform.rotate(
                            angle: value(_turn) * 2 * math.pi,
                            child: Icon(
                              CupertinoIcons.add,
                              color: t.canvas,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuItems extends StatelessWidget {
  const _MenuItems({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const items = [
      (CupertinoIcons.pencil, 'Note'),
      (CupertinoIcons.photo, 'Photo'),
      (CupertinoIcons.mic, 'Voice memo'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 70),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, label) in items)
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: archivo(16, weight: 500, color: color),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A placeholder list behind the menu.
class _Notes extends StatelessWidget {
  const _Notes();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Notes', style: t.title.copyWith(fontSize: 24)),
        const SizedBox(height: 16),
        for (final width in [.9, .7, .8, .55])
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surfaceSolid,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: width,
                  child: Container(height: 8, color: t.pebble),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: width * .6,
                  child: Container(height: 6, color: t.fog),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
