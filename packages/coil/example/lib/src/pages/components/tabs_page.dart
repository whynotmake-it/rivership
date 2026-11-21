import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const tabsEntry = CatalogEntry(
  slug: 'tabs',
  title: 'Tabs',
  group: CatalogGroup.groupedControls,
  summary: 'A selected pill that springs between peer views.',
  page: TabsPage.new,
);

enum _Pane {
  overview('Overview'),
  activity('Activity'),
  settings('Settings');

  const _Pane(this.label);

  final String label;
}

enum _Content {
  text('Text'),
  icons('Icons and text'),
  selected('Selected label only');

  const _Content(this.label);

  final String label;
}

enum _View {
  home('Home', Glyph.home),
  inbox('Inbox', Glyph.inbox),
  calendar('Calendar', Glyph.calendar),
  reports('Reports', Glyph.chart);

  const _View(this.label, this.glyph);

  final String label;
  final Glyph glyph;
}

class TabsPage extends StatefulWidget {
  const TabsPage({super.key});

  @override
  State<TabsPage> createState() => _TabsPageState();
}

class _TabsPageState extends State<TabsPage> {
  var _view = _View.inbox;
  var _content = _Content.icons;
  var _compact = false;
  var _month = 'Jun';

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Tabs',
    summary:
        'Two to six peer views behind one selected pill that springs from '
        'tab to tab.',
    hero: const _ProjectPanel(),
    usage: '''
CoilTabs<Pane>(
  value: pane,
  onChanged: (value) => setState(() => pane = value),
  tabs: const [
    CoilTab(value: Pane.overview, label: Text('Overview')),
    CoilTab(value: Pane.activity, label: Text('Activity')),
    CoilTab(value: Pane.settings, label: Text('Settings')),
  ],
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Roving focus: arrows move focus, Enter or Space selects, Home and '
            'End jump. Selection is manual, so arrowing past a tab does not '
            'switch the view.',
      ),
      CatalogNote(
        'Pointer',
        'Hovering grows a lighter pill out of the selected one and glides '
            'back on leave. Touch has no hover pill.',
      ),
      CatalogNote(
        'Motion',
        'The selected pill springs on the standard track. When labels show '
            'only on the selected tab, the label width springs open on the '
            'quick track.',
      ),
      CatalogNote(
        'Do / Don’t',
        'Do use it for 2 to 6 peer views. Don’t use it to move '
            'between the pages of a flow.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description:
            'With only the selected label showing, the others keep their '
            'icon.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Content',
              value: _content,
              values: _Content.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _content = v),
            ),
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
          ],
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoilTabs<_View>(
            size: _compact ? CoilSize.compact : null,
            value: _view,
            labels: _content == _Content.selected
                ? CoilTabLabels.selected
                : CoilTabLabels.always,
            onChanged: (value) => setState(() => _view = value),
            tabs: [
              for (final view in _View.values)
                CoilTab(
                  value: view,
                  label: Text(view.label),
                  icon: _content == _Content.text
                      ? null
                      : CatalogIcon(view.glyph),
                ),
            ],
          ),
        ),
      ),
      DemoSection(
        title: 'Overflow',
        description:
            "Tabs that don't fit scroll, with fading edges. The selected "
            'tab and the keyboard-focused tab scroll into view.',
        child: CoilTabs<String>(
          value: _month,
          onChanged: (value) => setState(() => _month = value),
          tabs: [
            for (final m in _months) CoilTab(value: m, label: Text(m)),
          ],
        ),
      ),
    ],
  );

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

/// A project page: three panes behind the tabs. Settings keep their state
/// while another tab shows.
class _ProjectPanel extends StatefulWidget {
  const _ProjectPanel();

  @override
  State<_ProjectPanel> createState() => _ProjectPanelState();
}

class _ProjectPanelState extends State<_ProjectPanel> {
  var _pane = _Pane.overview;
  var _autoDeploy = true;
  var _failureAlerts = true;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Rivership', style: text.title)),
            const CoilBadge(
              variant: CoilBadgeVariant.dot,
              color: CoilBadgeColor.green,
              child: Text('Live'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoilTabs<_Pane>(
            value: _pane,
            onChanged: (value) => setState(() => _pane = value),
            tabs: [
              for (final pane in _Pane.values)
                CoilTab(value: pane, label: Text(pane.label)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 148),
          child: switch (_pane) {
            _Pane.overview => const _Rows(
              rows: [
                ('Version', 'v2.4.0'),
                ('Region', 'Frankfurt'),
                ('Owner', 'Ada Lovelace'),
                ('Last deploy', '2 hours ago'),
              ],
            ),
            _Pane.activity => const _Rows(
              rows: [
                ('Ada', 'Deployed v2.4.0'),
                ('Grace', 'Merged “Springier sheets”'),
                ('Linus', 'Opened issue #214'),
              ],
            ),
            _Pane.settings => CoilFieldGroup(
              children: [
                CoilField(
                  label: const Text('Deploy on merge'),
                  description: const Text('Ship every merge to main.'),
                  orientation: CoilFieldOrientation.horizontal,
                  child: CoilSwitch(
                    value: _autoDeploy,
                    onChanged: (v) => setState(() => _autoDeploy = v),
                  ),
                ),
                CoilField(
                  label: const Text('Failure alerts'),
                  description: const Text(
                    'Email the owner when a build fails.',
                  ),
                  orientation: CoilFieldOrientation.horizontal,
                  child: CoilSwitch(
                    value: _failureAlerts,
                    onChanged: (v) => setState(() => _failureAlerts = v),
                  ),
                ),
              ],
            ),
          },
        ),
      ],
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final (label, value) in rows)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Text(label, style: text.muted.body),
              ),
              Expanded(child: Text(value, style: text.body)),
            ],
          ),
      ],
    );
  }
}
