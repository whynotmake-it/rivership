import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';
import 'src/test_icons.dart';

const _labels = ['Overview', 'Analytics', 'Reports', 'Settings'];
const _icons = [
  TestGlyph.home,
  TestGlyph.search,
  TestGlyph.heart,
  TestGlyph.settings,
];

List<CoilTab<int>> _tabs({bool icons = false}) => [
  for (final (i, label) in _labels.indexed)
    CoilTab(
      value: i,
      label: label,
      icon: icons ? TestIcon(_icons[i]) : null,
    ),
];

/// A menu-like list using the fluid hover primitive directly.
class _Menu extends StatelessWidget {
  const _Menu();

  @override
  Widget build(BuildContext context) {
    final sizes = CoilTheme.metricsOf(context);
    final colors = CoilTheme.of(context).colors;
    return SizedBox(
      width: 220,
      child: CoilHoverRegion(
        child: CoilHoverHighlight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, label) in _labels.indexed)
                CoilHoverItem(
                  index: i,
                  child: Builder(
                    builder: (context) {
                      final active = CoilHoverItem.isActive(context, i);
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
                              IconTheme(
                                data: IconThemeData(color: color, size: 16),
                                child: TestIcon(_icons[i]),
                              ),
                              Text(
                                label,
                                style: const CoilTypography().style(
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
      ),
    );
  }
}

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => CoilTheme(
    data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
    child: FocusScope(
      autofocus: true,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

void main() {
  group('CoilTabs', () {
    testWidgets('overview sheet', (tester) async {
      Widget tabs(
        SheetState s, {
        bool icons = false,
        CoilTabLabels labels = CoilTabLabels.always,
        CoilSize? size,
      }) => CoilTabs(
        tabs: _tabs(icons: icons),
        value: 0,
        onChanged: (_) {},
        labels: labels,
        size: size,
      );
      const columns = [SheetState.rest];
      final sheet = ThemedPair(
        title: 'Tabs',
        direction: Axis.vertical,
        builder: (context) => StateTable(
          columns: columns,
          rows: [
            SheetRow('text', tabs),
            SheetRow('icons', (s) => tabs(s, icons: true)),
            SheetRow(
              'active label',
              (s) => tabs(s, icons: true, labels: CoilTabLabels.selected),
            ),
            SheetRow(
              'compact',
              (s) => tabs(s, size: CoilSize.compact),
            ),
          ],
        ),
      );
      final finder = await pumpSheet(tester, sheet);
      await expectSheetGolden(tester, finder, 'goldens/tabs.png');
    });

    // Hover and focus per variant, posed with a real mouse and real keys.
    for (final (name, icons, labels, size) in [
      ('icons', true, CoilTabLabels.always, null),
      ('active_label', true, CoilTabLabels.selected, null),
      ('compact', false, CoilTabLabels.always, CoilSize.compact),
    ]) {
      testWidgets('hover and focus: $name', (tester) async {
        final sheet = await pumpSheet(
          tester,
          SheetPanel(
            title: 'Tabs $name: hover Reports, then focus Analytics',
            theme: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
            child: FocusScope(
              autofocus: true,
              child: CoilTabs(
                tabs: _tabs(icons: icons),
                value: 0,
                onChanged: (_) {},
                labels: labels,
                size: size,
              ),
            ),
          ),
          surface: const Size(700, 200),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        // Collapsed tabs have only their icon to point at.
        final reports = icons
            ? find.byType(TestIcon).at(2)
            : find.text('Reports').last;
        await mouse.moveTo(tester.getCenter(reports));
        await settle(tester);
        await expectSheetGolden(tester, sheet, 'goldens/tabs_hover_$name.png');
        await mouse.moveTo(const Offset(650, 190));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await settle(tester);
        await expectSheetGolden(tester, sheet, 'goldens/tabs_focus_$name.png');
      });
    }

    testWidgets('real mouse hover lights a tab, arrows move focus', (
      tester,
    ) async {
      var selected = 0;
      const liveKey = ValueKey('live-tabs');
      await tester.pumpWidget(
        _app(
          RepaintBoundary(
            key: liveKey,
            child: StatefulBuilder(
              builder: (context, setState) => CoilTabs(
                tabs: _tabs(),
                value: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
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
      expect(CoilHoverRegion.maybeOf(region)?.activeIndex, 2);

      // Capture the live hover state for the record.
      await expectSheetGolden(
        tester,
        find.byKey(liveKey),
        'goldens/tabs_live_hover.png',
      );

      await mouse.moveTo(const Offset(600, 500));
      await tester.pumpAndSettle();
      expect(CoilHoverRegion.maybeOf(region)?.activeIndex, isNull);

      // Keyboard: Tab enters on the selected tab, arrows move, Enter selects.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await expectSheetGolden(
        tester,
        find.byKey(liveKey),
        'goldens/tabs_live_focus.png',
      );
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

  group('CoilHoverRegion', () {
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
      await expectSheetGolden(
        tester,
        find.byKey(key),
        'goldens/fluid_hover_rest.png',
      );

      // Move to "Settings": capture mid-glide, then settled.
      await mouse.moveTo(tester.getCenter(find.text('Settings').first));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await expectSheetGolden(
        tester,
        find.byKey(key),
        'goldens/fluid_hover_gliding.png',
      );
      await tester.pumpAndSettle();

      // And the dark panel, to show both themes.
      await mouse.moveTo(tester.getCenter(find.text('Reports').last));
      await tester.pumpAndSettle();
      await expectSheetGolden(
        tester,
        find.byKey(key),
        'goldens/fluid_hover_dark.png',
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
      final first = CoilHoverRegion.maybeOf(ctx)!.session;
      await mouse.moveTo(tester.getCenter(find.text('Settings')));
      await tester.pump();
      expect(CoilHoverRegion.maybeOf(ctx)!.session, first);
      await mouse.moveTo(const Offset(500, 500));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Overview')));
      await tester.pump();
      expect(CoilHoverRegion.maybeOf(ctx)!.session, first + 1);
      await tester.pumpAndSettle();
    });
  });
}
