import 'package:fluid_functionalism/fluid_functionalism.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

const _labels = ['Overview', 'Analytics', 'Reports', 'Settings'];
const _icons = [
  FluidIcons.home,
  FluidIcons.search,
  FluidIcons.heart,
  FluidIcons.settings,
];

List<FluidTab> _tabs({bool icons = false}) => [
  for (final (i, label) in _labels.indexed)
    FluidTab(
      label: Text(label),
      icon: icons ? FluidIcon(_icons[i]) : null,
    ),
];

/// A menu-like list using the fluid hover primitive directly.
class _Menu extends StatelessWidget {
  const _Menu();

  @override
  Widget build(BuildContext context) {
    final sizes = FluidTheme.sizesOf(context);
    final colors = FluidTheme.of(context).colors;
    return SizedBox(
      width: 220,
      child: FluidHoverRegion(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, label) in _labels.indexed)
              FluidHoverItem(
                index: i,
                child: Builder(
                  builder: (context) {
                    final active = FluidHoverItem.isActive(context, i);
                    final color = active
                        ? colors.foreground
                        : colors.mutedForeground;
                    return SizedBox(
                      height: sizes.controlHeight,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: sizes.itemPaddingX,
                        ),
                        child: Row(
                          spacing: sizes.gap,
                          children: [
                            FluidIcon(_icons[i], color: color),
                            Text(
                              label,
                              style: FluidTypography.style(
                                sizes.body,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => FluidTheme(
    data: FluidThemeData.light.copyWith(tier: FluidTier.desktop),
    child: FocusScope(
      autofocus: true,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

void main() {
  group('FluidTabs', () {
    testWidgets('overview sheet', (tester) async {
      Widget tabs(
        SheetState s, {
        bool icons = false,
        bool activeLabel = false,
        FluidDensity? density,
      }) => FluidTabs(
        tabs: _tabs(icons: icons),
        selectedIndex: 0,
        onSelected: (_) {},
        activeLabel: activeLabel,
        density: density,
        // Keyboard focus lights the tab too, as on the web.
        debugHoveredIndex: switch (s) {
          SheetState.hover => 2,
          SheetState.focus => 1,
          _ => null,
        },
        debugFocusedIndex: s == SheetState.focus ? 1 : null,
      );
      const columns = [SheetState.rest, SheetState.hover, SheetState.focus];
      final sheet = ThemedPair(
        title: 'Tabs (hover → Reports, focus → Analytics)',
        direction: Axis.vertical,
        builder: (context) => StateTable(
          columns: columns,
          rows: [
            SheetRow('text', tabs),
            SheetRow('icons', (s) => tabs(s, icons: true)),
            SheetRow(
              'active label',
              (s) => tabs(s, icons: true, activeLabel: true),
            ),
            SheetRow(
              'compact',
              (s) => tabs(s, density: FluidDensity.compact),
            ),
          ],
        ),
      );
      final finder = await pumpSheet(tester, sheet);
      await expectLater(finder, matchesGoldenFile('goldens/tabs.png'));
    });

    testWidgets('real mouse hover lights a tab, arrows move focus', (
      tester,
    ) async {
      var selected = 0;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => FluidTabs(
              tabs: _tabs(),
              selectedIndex: selected,
              onSelected: (i) => setState(() => selected = i),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Reports').last));
      await tester.pumpAndSettle();
      final region = tester.element(find.text('Reports').last);
      expect(FluidHoverRegion.maybeOf(region)?.activeIndex, 2);

      // Capture the live hover state for the record.
      await expectLater(
        find.byType(FluidTabs),
        matchesGoldenFile('goldens/tabs_live_hover.png'),
      );

      await mouse.moveTo(const Offset(600, 500));
      await tester.pumpAndSettle();
      expect(FluidHoverRegion.maybeOf(region)?.activeIndex, isNull);

      // Keyboard: Tab enters on the selected tab, arrows move, Enter selects.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(selected, 0, reason: 'manual activation: arrows only move focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected, 3);
    });
  });

  group('FluidHoverRegion', () {
    testWidgets('highlight sheet (real mouse)', (tester) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(1200, 800) * 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: ThemedPair(
                title: 'Fluid hover',
                builder: (context) => const _Menu(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hover "Analytics" in the light panel and let it settle.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Analytics').first));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/fluid_hover_rest.png'),
      );

      // Move to "Settings": capture mid-glide, then settled.
      await mouse.moveTo(tester.getCenter(find.text('Settings').first));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/fluid_hover_gliding.png'),
      );
      await tester.pumpAndSettle();

      // And the dark panel, to show both themes.
      await mouse.moveTo(tester.getCenter(find.text('Reports').last));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/fluid_hover_dark.png'),
      );
    });

    testWidgets('a fresh session fades in instead of gliding', (tester) async {
      await tester.pumpWidget(_app(const _Menu()));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.text('Overview'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(500, 500));
      await mouse.moveTo(tester.getCenter(find.text('Reports').last));
      await tester.pump();
      final first = FluidHoverRegion.maybeOf(ctx)!.session;
      await mouse.moveTo(tester.getCenter(find.text('Settings')));
      await tester.pump();
      expect(FluidHoverRegion.maybeOf(ctx)!.session, first);
      await mouse.moveTo(const Offset(500, 500));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Overview')));
      await tester.pump();
      expect(FluidHoverRegion.maybeOf(ctx)!.session, first + 1);
      await tester.pumpAndSettle();
    });
  });
}
