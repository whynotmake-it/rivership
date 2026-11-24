import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const revealEntry = CatalogEntry(
  slug: 'reveal',
  title: 'Reveal',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Panels that blur-fade in one after another as a screen settles.',
  page: RevealPage.new,
);

class RevealPage extends StatelessWidget {
  const RevealPage({super.key});

  @override
  Widget build(BuildContext context) => const CatalogPage(
    title: 'Reveal',
    summary:
        'A screen settling in, where the children blur-fade in one after '
        'another on the first build and then stay put. Nothing moves as you '
        'scroll.',
    hero: _RevealDemo(),
    usage: '''
CoilReveal(
  visible: loaded,
  builder: (context, children) => Column(spacing: 8, children: children),
  children: [
    for (final panel in panels) PanelCard(panel),
  ],
)''',
    notes: [
      CatalogNote(
        'Motion',
        'The first child shows at once and the rest follow a step apart: 60 '
            'ms on product, 40 on subtle and 100 on landing. Blocks stagger '
            'for three steps and bring the rest in with the fourth, while '
            'items stagger for seven.',
      ),
      CatalogNote(
        'Reduced motion',
        'The stagger drops to zero and the blur-fade only fades, so every '
            'child appears or disappears at once.',
      ),
      CatalogNote(
        'Accessibility',
        'Hidden children stay mounted, but they take no pointer, focus or '
            'semantics until they show again.',
      ),
      CatalogNote(
        "Do / Don't",
        'Wrap the main column or a list, and keep headers, sidebars and '
            'footers outside it so the frame stays still. Do not reveal '
            'things as you scroll.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Subtle',
        description:
            'Uses a shorter stagger between steps, for quieter screens.',
        child: _RevealDemo(preset: CoilRevealPreset.subtle),
      ),
      DemoSection(
        title: 'Landing',
        description:
            'Each child rises 12 px and scales up gently from 94%, 100 ms '
            'apart.',
        child: _RevealDemo(preset: CoilRevealPreset.landing),
      ),
      DemoSection(
        title: 'Items',
        description:
            'Rows stagger up to the eighth one, and anything after it arrives '
            'along with it.',
        child: _RevealDemo(steps: CoilRevealSteps.items),
      ),
      DemoSection(
        title: 'Loading',
        description:
            'A skeleton stands in while the data loads, and then the rows '
            'arrive one by one.',
        child: _LoadingDemo(),
      ),
    ],
  );
}

const _panels = [
  ('Revenue', r'$48,200 this month'),
  ('Active users', '1,284 today'),
  ('Churn', '2.1%, down from 2.4%'),
];

const _rows = [
  'Design review',
  'Sprint planning',
  'Release notes',
  'Customer call',
  'Retro',
  'Hiring sync',
  'Roadmap',
  'Budget',
  'Offsite',
];

/// A row of compact secondary buttons above a demo.
class _Controls extends StatelessWidget {
  const _Controls({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _Control extends StatelessWidget {
  const _Control({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CoilButton(
    variant: CoilButtonVariant.secondary,
    size: CoilSize.compact,
    onPressed: onPressed,
    child: Text(label),
  );
}

/// One preset with Replay and Show/Hide, as an app would drive it: Replay
/// builds the reveal anew with a new key, and Show/Hide flips `visible`.
class _RevealDemo extends StatefulWidget {
  const _RevealDemo({
    this.preset = CoilRevealPreset.product,
    this.steps = CoilRevealSteps.blocks,
  });

  final CoilRevealPreset preset;
  final CoilRevealSteps steps;

  @override
  State<_RevealDemo> createState() => _RevealDemoState();
}

class _RevealDemoState extends State<_RevealDemo> {
  var _run = 0;
  var _visible = true;

  @override
  Widget build(BuildContext context) {
    final items = widget.steps == CoilRevealSteps.items;
    return DemoColumn(
      children: [
        _Controls(
          children: [
            _Control(
              label: 'Replay',
              onPressed: () => setState(() {
                _run++;
                _visible = true;
              }),
            ),
            _Control(
              label: _visible ? 'Hide' : 'Show',
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ],
        ),
        CoilReveal(
          key: ValueKey(_run),
          visible: _visible,
          preset: widget.preset,
          steps: widget.steps,
          builder: items
              ? null
              : (context, children) => Column(spacing: 8, children: children),
          children: items
              ? [
                  for (final name in _rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(name),
                    ),
                ]
              : [
                  for (final (title, description) in _panels)
                    CoilCard(
                      title: Text(title),
                      description: Text(description),
                    ),
                ],
        ),
      ],
    );
  }
}

enum _Load { idle, loading, loaded }

/// The skeleton swap: Load shows skeletons until fake data arrives, whose
/// rows then reveal one by one. Reload does it again.
class _LoadingDemo extends StatefulWidget {
  const _LoadingDemo();

  @override
  State<_LoadingDemo> createState() => _LoadingDemoState();
}

class _LoadingDemoState extends State<_LoadingDemo> {
  /// How long the fake request takes.
  static const _latency = Duration(milliseconds: 1500);

  var _state = _Load.idle;
  Timer? _request;

  @override
  void dispose() {
    _request?.cancel();
    super.dispose();
  }

  void _load() {
    _request?.cancel();
    setState(() => _state = _Load.loading);
    _request = Timer(_latency, () {
      if (mounted) setState(() => _state = _Load.loaded);
    });
  }

  @override
  Widget build(BuildContext context) => DemoColumn(
    children: [
      _Controls(
        children: [
          _Control(
            label: _state == _Load.idle ? 'Load' : 'Reload',
            onPressed: _load,
          ),
        ],
      ),
      if (_state == _Load.idle)
        Text(
          'Nothing loaded yet.',
          style: CoilTheme.textOf(context).muted.body,
        )
      else
        CoilSkeletonSwitcher(
          loading: _state == _Load.loading,
          skeleton: const CoilSkeletonRegion(
            semanticLabel: 'Loading',
            child: CoilSkeletonText(lines: 5),
          ),
          child: CoilReveal(
            steps: CoilRevealSteps.items,
            children: [
              for (final name in _rows.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(name),
                ),
            ],
          ),
        ),
    ],
  );
}
