import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const skeletonEntry = CatalogEntry(
  slug: 'skeleton',
  title: 'Skeleton',
  group: CatalogGroup.leafControls,
  summary:
      'Placeholders in the shape of loading content, and a switcher that '
      'swaps them for it.',
  page: SkeletonPage.new,
);

class SkeletonPage extends StatefulWidget {
  const SkeletonPage({super.key});

  @override
  State<SkeletonPage> createState() => _SkeletonPageState();
}

class _SkeletonPageState extends State<SkeletonPage> {
  var _lines = 3;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Skeleton',
    summary:
        'A skeleton holds the place of content that is still loading, and '
        'CoilSkeletonSwitcher swaps it for the real content. The switcher '
        'cross-fades the two in the same space, so the layout never jumps, '
        'and it keeps a fast first load from flashing a skeleton at all.',
    hero: const _FeedCard(),
    usage: '''
CoilSkeletonSwitcher(
  loading: loading,
  skeleton: const CoilSkeletonRegion(
    semanticLabel: 'Loading post',
    child: PostSkeleton(),
  ),
  child: const Post(),
)''',
    notes: const [
      CatalogNote(
        'Motion',
        'A skeleton that appears first waits out a 160 ms grace period and '
            'then fades in, while one that replaces content already on screen '
            'appears at once, because waiting would leave the space empty. '
            'Once it is visible it pulses between full and half opacity every '
            '2 s, and reduced motion keeps the fades and drops the pulse.',
      ),
      CatalogNote(
        'Screen readers',
        'The individual blocks are skipped, and the loading region '
            'announces its semanticLabel as a live region.',
      ),
      CatalogNote(
        "Do / Don't",
        'Match the line count and widths of the final layout so that nothing '
            'moves when the content arrives, and let CoilSkeletonSwitcher do '
            'the swap rather than replacing one widget with the other '
            'yourself. Text lines vary between 55% and 82% of the width, as '
            'real text does, and a skeleton never shimmers.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Building blocks',
        description:
            'A skeleton is built from blocks: CoilSkeleton takes any size, '
            'and a text line is as tall as the line of text it stands in for. '
            'Arrange them the way the loaded layout is arranged and hand the '
            'result to a switcher.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Text lines',
              value: _lines,
              values: const [1, 2, 3, 4],
              labelOf: (v) => '$v',
              onChanged: (v) => setState(() => _lines = v),
            ),
          ],
        ),
        child: DemoColumn(
          children: [
            const CoilSkeleton(height: 120),
            CoilSkeletonText(lines: _lines),
          ],
        ),
      ),
    ],
  );
}

/// A post that loads, on three buttons: two first loads (one under the grace
/// period, one over it) and a reload of content that is already on screen.
class _FeedCard extends StatefulWidget {
  const _FeedCard();

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  /// Changing it mounts a fresh switcher, which is a first load again.
  var _generation = 0;
  var _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _finishAfter(const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finishAfter(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _firstLoad(Duration delay) {
    setState(() {
      _generation++;
      _loading = true;
    });
    _finishAfter(delay);
  }

  void _reload() {
    setState(() => _loading = true);
    _finishAfter(const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    final gap = CoilTheme.metricsOf(context).buttonGap;
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoilSkeletonSwitcher(
          key: ValueKey(_generation),
          loading: _loading,
          skeleton: const CoilSkeletonRegion(
            semanticLabel: 'Loading post',
            child: _PostSkeleton(),
          ),
          child: const _Post(),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () => _firstLoad(const Duration(milliseconds: 100)),
              child: const Text('First load, 100 ms'),
            ),
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () => _firstLoad(const Duration(seconds: 2)),
              child: const Text('First load, 2 s'),
            ),
            CoilButton(
              variant: CoilButtonVariant.ghost,
              onPressed: _reload,
              child: const Text('Reload'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Compare a fast 100 ms load (no skeleton flashes), a 2 s first '
          'load, and reloading content already on screen.',
          style: text.muted.caption,
        ),
      ],
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          CoilSkeleton(width: 40, height: 40),
          SizedBox(width: 12),
          Expanded(child: CoilSkeletonText(lines: 2)),
        ],
      ),
      SizedBox(height: 16),
      CoilSkeletonText(),
    ],
  );
}

class _Post extends StatelessWidget {
  const _Post();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox.square(
              dimension: 40,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.accent,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      CoilTheme.radiiOf(context).item,
                    ),
                  ),
                ),
                child: Center(child: Text('AL', style: text.body)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ada Lovelace',
                    style: text.body.copyWith(fontWeight: text.emphasis),
                  ),
                  Text('Posted 2 hours ago', style: text.muted.caption),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Notes on the Analytical Engine are done. The note on Bernoulli '
          'numbers turned out longer than the paper it annotates.',
          style: text.body,
        ),
      ],
    );
  }
}
