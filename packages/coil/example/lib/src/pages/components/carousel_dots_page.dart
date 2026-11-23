import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const carouselDotsEntry = CatalogEntry(
  slug: 'carousel-dots',
  title: 'CarouselDots',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Page dots whose active pill stretches as you move between pages.',
  page: CarouselDotsPage.new,
);

typedef _Slide = ({Glyph glyph, String title, String description});

const _slides = <_Slide>[
  (
    glyph: Glyph.inbox,
    title: 'Capture ideas',
    description: 'Drop a thought anywhere and it lands in your inbox.',
  ),
  (
    glyph: Glyph.users,
    title: 'Shape them together',
    description: 'Invite a teammate and edit the same page at once.',
  ),
  (
    glyph: Glyph.rotate,
    title: 'Keep track of changes',
    description: 'Every edit is saved, so you can always step back.',
  ),
  (
    glyph: Glyph.send,
    title: 'Ship when ready',
    description: 'Publish with one press, and undo if you change your mind.',
  ),
  (
    glyph: Glyph.bell,
    title: 'Stay in the loop',
    description: 'Get a nudge only when something needs you.',
  ),
];

class CarouselDotsPage extends StatefulWidget {
  const CarouselDotsPage({super.key});

  @override
  State<CarouselDotsPage> createState() => _CarouselDotsPageState();
}

class _CarouselDotsPageState extends State<CarouselDotsPage> {
  var _count = 5;
  var _autoplay = false;
  var _size = CoilSize.regular;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'CarouselDots',
    summary:
        'Dots that show where you are in a pager. You can tap a dot or focus '
        'the row and use the arrow keys, and swiping the pages themselves '
        'moves the pill along.',
    hero: const _Pager(count: 5),
    usage: '''
CoilCarouselDots(
  count: slides.length,
  value: page,
  onChanged: (index) => controller.animateToPage(
    index,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  ),
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'The dots are one tab stop. Left and Right, or Up and Down, step '
            'through the slides, and Home and End jump to the ends.',
      ),
      CatalogNote(
        'Pointer',
        'Each dot has its own 18 click target, and a single highlight glides '
            'between them.',
      ),
      CatalogNote(
        'Touch',
        'The row is one 44 high control, so you can tap or drag along it to '
            'scrub, and swiping the pager itself still pages.',
      ),
      CatalogNote(
        'Motion',
        'The pill grows from 6 to 24 on standard. The dots never advance by '
            'themselves: an autoplaying carousel drives the progress, and '
            'stops under reduced motion.',
      ),
      CatalogNote(
        'Screen readers',
        'The row is one adjustable control that reads "Slide 2 of 5" and '
            'offers increase and decrease actions.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description:
            'With progress on, the current pill fills as the slide plays. The '
            'carousel owns the clock, so picking a dot restarts it.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Slides',
              value: _count,
              values: const [3, 5],
              labelOf: (v) => '$v',
              onChanged: (v) => setState(() => _count = v),
            ),
            DemoControl.choice(
              label: 'Size',
              value: _size,
              values: const [CoilSize.regular, CoilSize.compact],
              labelOf: (v) => v == CoilSize.regular ? 'Regular' : 'Compact',
              onChanged: (v) => setState(() => _size = v),
            ),
            DemoControl.toggle(
              label: 'Autoplay',
              value: _autoplay,
              onChanged: (v) => setState(() => _autoplay = v),
            ),
          ],
        ),
        child: _Pager(count: _count, autoplay: _autoplay, size: _size),
      ),
    ],
  );
}

/// Onboarding pages in a PageView, with dots that drive it and follow it.
/// With [autoplay], the pages advance on a clock the dots show as progress.
class _Pager extends StatefulWidget {
  const _Pager({required this.count, this.autoplay = false, this.size});

  final int count;
  final bool autoplay;
  final CoilSize? size;

  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> with SingleTickerProviderStateMixin {
  static const _slideTime = Duration(seconds: 4);

  final _pages = PageController();
  late final _clock = AnimationController(vsync: this, duration: _slideTime)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goTo((_page + 1) % widget.count);
      }
    });
  var _page = 0;

  /// Whether the pages are animating to a dot, which they pass others on.
  var _animating = false;

  @override
  void didUpdateWidget(_Pager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.count) {
      _page = widget.count - 1;
      _pages.jumpToPage(_page);
    }
    _syncClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncClock();
  }

  @override
  void dispose() {
    _clock.dispose();
    _pages.dispose();
    super.dispose();
  }

  bool get _playing =>
      widget.autoplay && !MediaQuery.disableAnimationsOf(context);

  void _syncClock() {
    if (_playing) {
      if (!_clock.isAnimating) _clock.forward(from: _clock.value);
    } else {
      _clock
        ..stop()
        ..value = 0;
    }
  }

  void _goTo(int index) {
    _clock.value = 0;
    setState(() => _page = index);
    if (_pages.hasClients) {
      _animating = true;
      unawaited(
        _pages
            .animateToPage(
              index,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() => _animating = false),
      );
    }
    if (_playing) _clock.forward();
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pages,
            itemCount: widget.count,
            onPageChanged: (index) {
              if (_animating || index == _page) return;
              _clock.value = 0;
              setState(() => _page = index);
              if (_playing) _clock.forward();
            },
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.muted,
                      shape: RoundedSuperellipseBorder(borderRadius: radius),
                    ),
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(child: CatalogIcon(slide.glyph)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(slide.title, style: text.title),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      slide.description,
                      textAlign: TextAlign.center,
                      style: text.muted.body,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, _) => CoilCarouselDots(
              count: widget.count,
              size: widget.size,
              value: _page,
              progress: widget.autoplay ? _clock.value : null,
              onChanged: _goTo,
            ),
          ),
        ),
      ],
    );
  }
}
