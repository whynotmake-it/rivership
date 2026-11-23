import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const skeletonEntry = CatalogEntry(
  slug: 'skeleton',
  title: 'Skeleton',
  group: CatalogGroup.leafControls,
  summary: 'Placeholders that appear after a grace period and pulse.',
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
        'Placeholders in the shape of what is loading. They wait 160 ms, so '
        'a fast load never flashes, and they never shimmer.',
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
        'A skeleton fades in after the 160 ms grace, then pulses between '
            'full and half opacity every 2 s. Reduced motion keeps the fade '
            'and drops the pulse.',
      ),
      CatalogNote(
        'Screen readers',
        'The blocks are skipped. The loading region announces its '
            'semanticLabel as a live region.',
      ),
      CatalogNote(
        'Do / Don’t',
        'Match the final layout’s line count and widths. Text lines vary '
            'between 55 and 82 % of the width, like real text.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Building blocks',
        description:
            'A block takes any size; text lines follow the line height of '
            'the text they stand in for.',
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

/// A post that loads: Reload shows its skeleton for a moment, then the two
/// cross-fade in a single cell, so the card never collapses.
class _FeedCard extends StatefulWidget {
  const _FeedCard();

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  var _loading = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() {
    _timer?.cancel();
    setState(() => _loading = true);
    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoilSkeletonSwitcher(
        loading: _loading,
        skeleton: const CoilSkeletonRegion(
          semanticLabel: 'Loading post',
          child: _PostSkeleton(),
        ),
        child: const _Post(),
      ),
      const SizedBox(height: 20),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: CoilButton(
          variant: CoilButtonVariant.secondary,
          leading: const CatalogIcon(Glyph.rotate),
          loading: _loading,
          onPressed: _loading ? null : _reload,
          child: const Text('Reload'),
        ),
      ),
    ],
  );
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
