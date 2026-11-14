import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';

const tabsEntry = CatalogEntry(
  slug: 'tabs',
  title: 'Tabs',
  group: CatalogGroup.groupedControls,
  summary: 'A selected pill that springs between peer views.',
  page: TabsPage.new,
);

enum _View {
  overview('Overview', Glyph.home, 'Three projects, two due this week.'),
  inbox('Inbox', Glyph.inbox, '12 unread messages from your team.'),
  calendar('Calendar', Glyph.calendar, 'Design review at 14:00.'),
  reports('Reports', Glyph.chart, 'Weekly active users up 8 %.');

  const _View(this.label, this.glyph, this.body);

  final String label;
  final Glyph glyph;
  final String body;
}

class TabsPage extends StatefulWidget {
  const TabsPage({super.key});

  @override
  State<TabsPage> createState() => _TabsPageState();
}

class _TabsPageState extends State<TabsPage> {
  var _view = _View.overview;
  var _iconView = _View.inbox;
  var _range = 'week';
  var _month = 'Jun';

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Tabs',
    summary:
        'For 2 to 6 peer views. With a keyboard, arrows move focus and '
        'Enter or Space selects. With a mouse, a lighter pill grows out of the '
        'selected one.',
    children: [
      DemoSection(
        title: 'Text tabs',
        child: DemoColumn(
          children: [
            CoilTabs<String>(
              value: _range,
              onChanged: (value) => setState(() => _range = value),
              tabs: const [
                CoilTab(value: 'day', label: Text('Day')),
                CoilTab(value: 'week', label: Text('Week')),
                CoilTab(value: 'month', label: Text('Month')),
              ],
            ),
            RoleText(
              'Showing the last $_range.',
              role: TypeRole.body,
              muted: true,
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'With icons',
        child: DemoColumn(
          children: [
            CoilTabs<_View>(
              value: _view,
              onChanged: (value) => setState(() => _view = value),
              tabs: [
                for (final view in _View.values.take(3))
                  CoilTab(
                    value: view,
                    label: Text(view.label),
                    icon: CatalogIcon(view.glyph),
                  ),
              ],
            ),
            RoleText(_view.body, role: TypeRole.body),
          ],
        ),
      ),
      DemoSection(
        title: 'Labels only when selected',
        description:
            'Unselected tabs show their icon; the label width springs open.',
        child: DemoColumn(
          children: [
            CoilTabs<_View>(
              value: _iconView,
              labels: CoilTabLabels.selected,
              onChanged: (value) => setState(() => _iconView = value),
              tabs: [
                for (final view in _View.values)
                  CoilTab(
                    value: view,
                    label: Text(view.label),
                    icon: CatalogIcon(view.glyph),
                  ),
              ],
            ),
            RoleText(_iconView.body, role: TypeRole.body),
          ],
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
      DemoSection(
        title: 'Compact',
        child: CoilTabs<String>(
          size: CoilSize.compact,
          value: _range,
          onChanged: (value) => setState(() => _range = value),
          tabs: const [
            CoilTab(value: 'day', label: Text('Day')),
            CoilTab(value: 'week', label: Text('Week')),
            CoilTab(value: 'month', label: Text('Month')),
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
