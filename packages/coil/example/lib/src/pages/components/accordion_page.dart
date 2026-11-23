import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const accordionEntry = CatalogEntry(
  slug: 'accordion',
  title: 'Accordion',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Panels that unfold on a spring, one or several at a time.',
  page: AccordionPage.new,
);

typedef _Question = ({String id, String question, String answer});

const _questions = <_Question>[
  (
    id: 'plan',
    question: 'Can I change my plan later?',
    answer:
        'Yes, any time from Billing. An upgrade starts at once and a '
        'downgrade at the end of the period.',
  ),
  (
    id: 'seats',
    question: 'How do seats work?',
    answer:
        'Every member of a workspace takes one seat. Guests can comment '
        'and never count.',
  ),
  (
    id: 'export',
    question: 'Can I export my data?',
    answer: 'Everything exports as CSV or JSON from Settings, Data.',
  ),
  (
    id: 'refund',
    question: 'What if it is not for me?',
    answer: 'Ask within 30 days and we refund the plan in full.',
  ),
];

List<CoilAccordionItem<String>> _items() => [
  for (final q in _questions)
    CoilAccordionItem(
      value: q.id,
      semanticLabel: q.question,
      label: Text(q.question),
      panel: Text(q.answer),
    ),
];

enum _Mode {
  single('Single'),
  multiple('Multiple');

  const _Mode(this.label);

  final String label;
}

class AccordionPage extends StatefulWidget {
  const AccordionPage({super.key});

  @override
  State<AccordionPage> createState() => _AccordionPageState();
}

class _AccordionPageState extends State<AccordionPage> {
  String? _heroOpen = 'plan';

  var _mode = _Mode.single;
  var _variant = CoilAccordionVariant.group;
  var _collapsible = true;
  String? _single = 'seats';
  var _multiple = <String>{'seats', 'export'};

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Accordion',
    summary:
        'Sections that fold their panel away. Single mode keeps one open, '
        'multiple lets you read several side by side.',
    hero: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Billing questions', style: CoilTheme.textOf(context).title),
        const SizedBox(height: 12),
        CoilAccordion<String>.single(
          value: _heroOpen,
          onChanged: (id) => setState(() => _heroOpen = id),
          items: _items(),
        ),
      ],
    ),
    usage: '''
CoilAccordion<String>.single(
  value: open,
  onChanged: (id) => setState(() => open = id),
  items: [
    CoilAccordionItem(
      value: 'plan',
      label: Text('Can I change my plan later?'),
      panel: Text('Yes, any time from Billing.'),
    ),
  ],
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Every trigger is a tab stop. Enter or Space toggles it, Up and Down '
            'move between triggers, Home and End jump to the ends.',
      ),
      CatalogNote(
        'Touch',
        'Triggers show a press fill only; labels stay at full strength '
            'instead of muted.',
      ),
      CatalogNote(
        'Motion',
        'The chevron turns a quarter on quick, the panel opens on standard '
            'with its text fading on fade.',
      ),
      CatalogNote(
        'Accessibility',
        'Each trigger is a button with an expanded state, and an open panel '
            'is labelled by its trigger. Pass a semanticLabel on each item.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description:
            'The group variant is narrow and shares one hover highlight, with '
            'a tint behind what is open.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Mode',
              value: _mode,
              values: _Mode.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _mode = v),
            ),
            DemoControl.choice(
              label: 'Variant',
              value: _variant,
              values: CoilAccordionVariant.values,
              labelOf: (v) => switch (v) {
                CoilAccordionVariant.plain => 'Plain',
                CoilAccordionVariant.group => 'Group',
              },
              onChanged: (v) => setState(() => _variant = v),
            ),
            if (_mode == _Mode.single)
              DemoControl.toggle(
                label: 'Collapsible',
                value: _collapsible,
                onChanged: (v) => setState(() => _collapsible = v),
              ),
          ],
        ),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: switch (_mode) {
            _Mode.single => CoilAccordion<String>.single(
              variant: _variant,
              collapsible: _collapsible,
              value: _single,
              onChanged: (id) => setState(() => _single = id),
              items: _items(),
            ),
            _Mode.multiple => CoilAccordion<String>.multiple(
              variant: _variant,
              values: _multiple,
              onChanged: (ids) => setState(() => _multiple = ids),
              items: _items(),
            ),
          },
        ),
      ),
    ],
  );
}
