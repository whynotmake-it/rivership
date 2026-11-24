import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';

/// What happens when the content inside a sheet scrolls.
final scrollCapabilities = <Capability>[
  Capability(
    title: 'Scroll handoff',
    description:
        'A list that scrolls, and hands the drag to the sheet at its '
        'top edge.',
    code: _handoffCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(
        context: context,
        child: const CapabilitySheet(
          title: 'Scroll handoff',
          hint:
              'Start a drag down when the list is already at the top to '
              'close the sheet. If you scroll back from further down, '
              'release and drag again.',
          code: _handoffCode,
          layout: CapabilitySheetLayout.fills,
          children: [_Rows(24)],
        ),
      ),
    ),
  ),
  Capability(
    title: 'Continuous handoff',
    description:
        'One fling down carries from the middle of the list into '
        'the sheet.',
    code: _continuousCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(
        context: context,
        dragHandoff: SheetDragHandoff.continuous,
        child: const CapabilitySheet(
          title: 'Continuous handoff',
          hint:
              'Fling down from the middle of the list: the list runs to '
              'its top and the same gesture carries on into the sheet.',
          code: _continuousCode,
          layout: CapabilitySheetLayout.fills,
          children: [_Rows(24)],
        ),
      ),
    ),
  ),
  Capability(
    title: 'Pages inside a sheet',
    description:
        'A PageView of lists, with vertical drags still reaching '
        'the sheet.',
    code: _pagesCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(context: context, child: const _PagesSheet()),
    ),
  ),
];

const _handoffCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    // The default: the sheet only takes a gesture that started
    // with the list already at its top.
    dragHandoff: SheetDragHandoff.gestureStart,
    child: YourList(),
  ),
);''';

const _continuousCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    // The sheet takes over as soon as the same gesture scrolls
    // the list to its top.
    dragHandoff: SheetDragHandoff.continuous,
    child: YourList(),
  ),
);''';

const _pagesCode = '''
PageView(
  // A PageView brings its own scroll behavior, which would
  // keep the sheet out of the gesture. Wrapping it in
  // ScrollDragBehavior hands vertical drags back to the sheet.
  scrollBehavior: ScrollDragBehavior(
    parent: ScrollConfiguration.of(context),
  ),
  controller: controller,
  children: [for (final page in pages) YourList(page)],
);''';

/// Numbered rows as one widget, so a const sheet can hold them.
class _Rows extends StatelessWidget {
  const _Rows(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: capabilityRows(count),
  );
}

/// Three pages of rows side by side, each scrolling on its own.
class _PagesSheet extends StatefulWidget {
  const _PagesSheet();

  @override
  State<_PagesSheet> createState() => _PagesSheetState();
}

class _PagesSheetState extends State<_PagesSheet> {
  static const _pages = 3;
  static const _rowsPerPage = 8;

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) => CapabilitySheet(
    title: 'Pages inside a sheet',
    hint:
        'Swipe sideways between pages, scroll a page, and drag down '
        'anywhere to close the sheet.',
    code: _pagesCode,
    layout: CapabilitySheetLayout.fixed,
    children: [
      SizedBox(
        height: 264,
        child: PageView(
          // A PageView takes its own scroll behavior; this one still
          // hands vertical drags to the sheet.
          scrollBehavior: CoilSheetRoute.scrollBehaviorOf(context),
          controller: _controller,
          onPageChanged: (page) => setState(() => _page = page),
          children: [
            for (var page = 0; page < _pages; page++)
              ListView(
                children: capabilityRows(
                  _rowsPerPage,
                  from: page * _rowsPerPage + 1,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: CoilCarouselDots(count: _pages, value: _page, onChanged: _goTo),
      ),
    ],
  );
}
