import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const cardEntry = CatalogEntry(
  slug: 'card',
  title: 'Card',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Surfaces with a title, media and an optional press or dismiss.',
  page: CardPage.new,
);

typedef _Project = ({String name, String edited, Glyph glyph});

const _projects = <_Project>[
  (name: 'Marketing site', edited: 'Edited 2 hours ago', glyph: Glyph.globe),
  (name: 'Mobile app', edited: 'Edited yesterday', glyph: Glyph.smartphone),
  (name: 'Quarterly report', edited: 'Edited 3 days ago', glyph: Glyph.chart),
  (name: 'Brand guidelines', edited: 'Edited last week', glyph: Glyph.palette),
];

const _albums = <_Project>[
  (name: 'Dune shoot', edited: '24 photos, shared with 3', glyph: Glyph.image),
  (name: 'Golden hour', edited: '18 photos, only you', glyph: Glyph.image),
];

class CardPage extends StatefulWidget {
  const CardPage({super.key});

  @override
  State<CardPage> createState() => _CardPageState();
}

enum _Layout {
  divided('Divided'),
  separated('Separated');

  const _Layout(this.label);

  final String label;

  CoilCardGroupLayout get layout => switch (this) {
    divided => CoilCardGroupLayout.divided,
    separated => CoilCardGroupLayout.separated,
  };
}

class _CardPageState extends State<CardPage> {
  var _archived = <String>{};
  String _status = 'Press a project to open it.';

  var _variant = CoilCardVariant.stacked;
  var _layout = _Layout.divided;
  var _columns = 2;
  var _dismissible = false;
  var _removed = <String>{};

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return CatalogPage(
      title: 'Card',
      summary:
          'A surface that is one button when it has an action, with an '
          'optional dismiss. Cards in a group share one hover highlight.',
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoilCardGroup(
            children: [
              for (final project in _projects)
                if (!_archived.contains(project.name))
                  CoilCard(
                    key: ValueKey(project.name),
                    variant: CoilCardVariant.inline,
                    icon: CatalogIcon(project.glyph),
                    title: Text(project.name),
                    description: Text(project.edited),
                    dismissLabel: 'Archive ${project.name}',
                    onPressed: () =>
                        setState(() => _status = 'Opened ${project.name}.'),
                    onDismissed: () => setState(() {
                      _archived = {..._archived, project.name};
                      _status = 'Archived ${project.name}.';
                    }),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              children: [
                Expanded(child: Text(_status, style: text.muted.caption)),
                if (_archived.isNotEmpty)
                  CoilButton(
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                    onPressed: () => setState(() {
                      _archived = {};
                      _status = 'Restored all projects.';
                    }),
                    child: const Text('Restore'),
                  ),
              ],
            ),
          ),
        ],
      ),
      usage: '''
CoilCardGroup(
  children: [
    CoilCard(
      variant: CoilCardVariant.inline,
      icon: Icon(Icons.public),
      title: Text('Marketing site'),
      description: Text('Edited 2 hours ago'),
      onPressed: () => open(site),
      onDismissed: () => archive(site),
    ),
  ],
)''',
      notes: const [
        CatalogNote(
          'Pointer',
          'A card with an action hovers with one highlight that glides across '
              'the group. The dismiss shows on hover or focus.',
        ),
        CatalogNote(
          'Touch',
          'The card shows a press fill and always shows its dismiss, with a '
              '44 hit target.',
        ),
        CatalogNote(
          'Motion',
          'Dismissing blur-fades the card while its height collapses on '
              'standard, and only then calls onDismissed. Remove the card '
              'there.',
        ),
        CatalogNote(
          "Do / Don't",
          'One primary action per card. Buttons in actions stay separate '
              'tab stops after it. Never nest cards.',
        ),
      ],
      children: [
        DemoSection(
          title: 'Playground',
          description:
              'Stacked puts the media on top at 16:9. Inline sets an icon '
              'tile or a square image beside the text.',
          controls: DemoControls(
            children: [
              DemoControl.choice(
                label: 'Variant',
                value: _variant,
                values: CoilCardVariant.values,
                labelOf: (v) => switch (v) {
                  CoilCardVariant.stacked => 'Stacked',
                  CoilCardVariant.inline => 'Inline',
                },
                onChanged: (v) => setState(() => _variant = v),
              ),
              DemoControl.choice(
                label: 'Layout',
                value: _layout,
                values: _Layout.values,
                labelOf: (v) => v.label,
                onChanged: (v) => setState(() => _layout = v),
              ),
              DemoControl.choice(
                label: 'Columns',
                value: _columns,
                values: const [1, 2],
                labelOf: (v) => '$v',
                onChanged: (v) => setState(() => _columns = v),
              ),
              DemoControl.toggle(
                label: 'Dismissible',
                value: _dismissible,
                onChanged: (v) => setState(() {
                  _dismissible = v;
                  _removed = {};
                }),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => CoilCardGroup(
              layout: _layout.layout,
              // Two columns need room; a phone keeps one.
              columns: constraints.maxWidth >= 480 ? _columns : 1,
              children: [
                for (final (index, project) in _albums.indexed)
                  if (!_removed.contains(project.name))
                    CoilCard(
                      key: ValueKey((project.name, _variant)),
                      variant: _variant,
                      icon: _variant == CoilCardVariant.inline
                          ? CatalogIcon(project.glyph)
                          : null,
                      media: _variant == CoilCardVariant.stacked
                          ? Image(
                              image: const AssetImage(
                                'assets/images/dunes.jpg',
                              ),
                              fit: BoxFit.cover,
                              alignment: Alignment(0, index == 0 ? -0.6 : 0.8),
                            )
                          : null,
                      title: Text(project.name),
                      description: Text(project.edited),
                      onPressed: () {},
                      onDismissed: _dismissible
                          ? () => setState(
                              () => _removed = {..._removed, project.name},
                            )
                          : null,
                      actions: [
                        CoilButton(
                          variant: CoilButtonVariant.ghost,
                          onPressed: () {},
                          child: const Text('Share'),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
