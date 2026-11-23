import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const scrollAreaEntry = CatalogEntry(
  slug: 'scroll-area',
  title: 'ScrollArea',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'A scroller with a slim thumb and edges that fade.',
  page: ScrollAreaPage.new,
);

typedef _Release = ({String version, String date, String notes});

const _releases = <_Release>[
  (
    version: '2.4.0',
    date: '12 Nov',
    notes: 'Springier sheets, a drawer for phones and a dozen small fixes.',
  ),
  (
    version: '2.3.2',
    date: '4 Nov',
    notes: 'Fixes a focus ring that stayed behind after a menu closed.',
  ),
  (
    version: '2.3.1',
    date: '29 Oct',
    notes: 'Tables keep the active row when their data is sorted.',
  ),
  (
    version: '2.3.0',
    date: '21 Oct',
    notes: 'Adds the date picker, with ranges and a month that glides.',
  ),
  (
    version: '2.2.4',
    date: '14 Oct',
    notes: 'Select options scroll into view when the list opens.',
  ),
  (
    version: '2.2.3',
    date: '9 Oct',
    notes: 'Touch buttons keep their 44 hit target when compact.',
  ),
  (
    version: '2.2.0',
    date: '30 Sep',
    notes: 'Adds the command menu and the context menu.',
  ),
  (
    version: '2.1.2',
    date: '18 Sep',
    notes: 'Reduced motion now fades dialogs instead of scaling them.',
  ),
  (
    version: '2.1.0',
    date: '2 Sep',
    notes: 'Adds the sidebar, with a rail and a drawer.',
  ),
  (
    version: '2.0.0',
    date: '15 Aug',
    notes: 'Every control now runs on springs, and nothing scales on press.',
  ),
];

typedef _Member = ({String name, String role});

const _members = <_Member>[
  (name: 'Ada Lovelace', role: 'Engineering'),
  (name: 'Grace Hopper', role: 'Compilers'),
  (name: 'Margaret Hamilton', role: 'Flight software'),
  (name: 'Linus Torvalds', role: 'Kernel'),
  (name: 'Barbara Liskov', role: 'Languages'),
  (name: 'Ken Thompson', role: 'Systems'),
  (name: 'Radia Perlman', role: 'Networking'),
  (name: 'Donald Knuth', role: 'Algorithms'),
  (name: 'Frances Allen', role: 'Optimization'),
  (name: 'Dennis Ritchie', role: 'Languages'),
];

class ScrollAreaPage extends StatefulWidget {
  const ScrollAreaPage({super.key});

  @override
  State<ScrollAreaPage> createState() => _ScrollAreaPageState();
}

class _ScrollAreaPageState extends State<ScrollAreaPage> {
  var _axis = Axis.vertical;
  var _fades = true;
  var _scrollbar = true;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final horizontal = _axis == Axis.horizontal;
    return CatalogPage(
      title: 'ScrollArea',
      summary:
          'A region that scrolls the way the app does, with a slim scrollbar '
          'and edges that fade where there is more.',
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Release notes', style: text.title),
          const SizedBox(height: 12),
          SizedBox(
            height: 296,
            child: CoilScrollArea(
              semanticLabel: 'Release notes',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  for (final release in _releases)
                    MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  release.version,
                                  style: text.body.copyWith(
                                    fontWeight: text.emphasis,
                                  ),
                                ),
                              ),
                              Text(release.date, style: text.muted.caption),
                            ],
                          ),
                          Text(release.notes, style: text.muted.body),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      usage: '''
CoilScrollArea(
  semanticLabel: 'Release notes',
  child: Column(
    children: [
      for (final release in releases) ReleaseTile(release),
    ],
  ),
)''',
      notes: const [
        CatalogNote(
          'Pointer',
          'The 4 wide scrollbar widens to 6 on hover and hides 600 ms after '
              'scrolling stops. Edges fade in over up to 32 as content '
              'scrolls away.',
        ),
        CatalogNote(
          'Touch',
          'A thin overlay bar shows only while scrolling and cannot be '
              'grabbed. Physics and drag devices come from the ambient '
              'ScrollBehavior.',
        ),
        CatalogNote(
          'Keyboard',
          'A region that scrolls is a tab stop. Arrows scroll a line, Page '
              'Up and Down a page, Home and End jump to the ends.',
        ),
        CatalogNote(
          "Do / Don't",
          'Do not nest scroll areas on the same axis. Wrap a list you '
              'already have with CoilScrollArea.scrollable and share its '
              'controller.',
        ),
      ],
      children: [
        DemoSection(
          title: 'Playground',
          controls: DemoControls(
            children: [
              DemoControl.choice(
                label: 'Axis',
                value: _axis,
                values: const [Axis.vertical, Axis.horizontal],
                labelOf: (v) => v == Axis.vertical ? 'Vertical' : 'Horizontal',
                onChanged: (v) => setState(() => _axis = v),
              ),
              DemoControl.toggle(
                label: 'Edge fades',
                value: _fades,
                onChanged: (v) => setState(() => _fades = v),
              ),
              DemoControl.toggle(
                label: 'Scrollbar',
                value: _scrollbar,
                onChanged: (v) => setState(() => _scrollbar = v),
              ),
            ],
          ),
          child: SizedBox(
            height: 208,
            child: Center(
              child: SizedBox(
                height: horizontal ? 96 : 208,
                child: CoilScrollArea(
                  key: ValueKey(_axis),
                  axis: _axis,
                  semanticLabel: 'Members',
                  edgeFades: _fades ? CoilEdgeFades.auto : CoilEdgeFades.none,
                  scrollbar: _scrollbar
                      ? CoilScrollbarVisibility.auto
                      : CoilScrollbarVisibility.none,
                  child: horizontal
                      ? Row(
                          spacing: 8,
                          children: [
                            for (final member in _members)
                              SizedBox(
                                width: 184,
                                child: CoilCard(
                                  title: Text(member.name),
                                  description: Text(member.role),
                                ),
                              ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 12,
                          children: [
                            for (final member in _members)
                              Row(
                                children: [
                                  Expanded(child: Text(member.name)),
                                  Text(member.role, style: text.muted.caption),
                                ],
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
