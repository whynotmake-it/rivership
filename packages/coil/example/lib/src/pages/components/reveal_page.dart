import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const revealEntry = CatalogEntry(
  slug: 'reveal',
  title: 'Reveal',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'A screen settles in: its panels fade in one after another.',
  page: RevealPage.new,
);

class RevealPage extends StatefulWidget {
  const RevealPage({super.key});

  @override
  State<RevealPage> createState() => _RevealPageState();
}

class _RevealPageState extends State<RevealPage> {
  /// Bumped by Replay: a new key builds the demos again, so they reveal
  /// again.
  var _run = 0;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Reveal',
    summary:
        'Panels fade in a step apart on first build, then never move '
        'again. With reduced motion they all fade in at once.',
    children: [
      DemoColumn(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CoilButton(
              variant: CoilButtonVariant.secondary,
              size: CoilSize.compact,
              onPressed: () => setState(() => _run++),
              child: const Text('Replay'),
            ),
          ),
        ],
      ),
      for (final pace in CoilRevealPace.values)
        DemoSection(
          title: pace == CoilRevealPace.regular ? 'Blocks' : 'Blocks, subtle',
          child: CoilReveal(
            key: ValueKey(('blocks', pace, _run)),
            pace: pace,
            builder: (context, children) =>
                Column(spacing: 12, children: children),
            children: [
              for (final (title, description) in const [
                ('Revenue', r'$48,200 this month'),
                ('Active users', '1,284 today'),
                ('Churn', '2.1 %, down from 2.4 %'),
                ('Open tickets', '17'),
              ])
                CoilCard(title: Text(title), description: Text(description)),
            ],
          ),
        ),
      DemoSection(
        title: 'Items',
        child: CoilReveal(
          key: ValueKey(('items', _run)),
          steps: CoilRevealSteps.items,
          children: [
            for (final name in const [
              'Design review',
              'Sprint planning',
              'Release notes',
              'Customer call',
              'Retro',
              'Hiring sync',
              'Roadmap',
              'Budget',
              'Offsite',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(name),
              ),
          ],
        ),
      ),
    ],
  );
}
