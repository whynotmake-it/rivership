import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/coil_pattern.dart';
import 'src/select_harness.dart';
import 'src/test_icons.dart';

void main() {
  group('CoilKbd', () {
    test('splits a combination into keys', () {
      expect(CoilKbd.split('⇧⌘O'), ['⇧', '⌘', 'O']);
      expect(CoilKbd.split('Ctrl+K'), ['Ctrl', 'K']);
      expect(CoilKbd.split('['), ['[']);
      expect(CoilKbd.split('Ctrl++'), ['Ctrl', '+']);
    });

    testWidgets('reads as one label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(testApp(home: Center(child: CoilKbd('⌘K'))));
      expect(find.bySemanticsLabel('⌘ K'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('callout stack', () {
    Widget card(String title, ValueChanged<String> dismissed) => CoilCard(
      key: ValueKey(title),
      variant: CoilCardVariant.inline,
      title: Text(title),
      icon: const TestIcon(TestGlyph.heart),
      onDismissed: () => dismissed(title),
    );

    Future<void> pump(
      WidgetTester tester,
      CoilSidebarCalloutExpand expand,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(600, 800);
      addTearDown(tester.view.reset);
      final cards = ['One', 'Two', 'Three'];
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 240,
              child: StatefulBuilder(
                builder: (context, setState) => CoilSidebarCalloutStack(
                  expand: expand,
                  children: [
                    for (final title in cards)
                      card(title, (t) => setState(() => cards.remove(t))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    double pileHeight(WidgetTester tester) =>
        tester.getSize(find.byType(CoilSidebarCalloutStack)).height;

    testWidgets('at rest the front card shows with two peeking behind', (
      tester,
    ) async {
      await pump(tester, CoilSidebarCalloutExpand.onHover);
      final front = tester.getRect(find.text('One'));
      final card = tester.getSize(find.byType(CoilCard).first).height;
      expect(pileHeight(tester), card + 24);
      // The cards behind sit higher, under the front one.
      expect(tester.getRect(find.text('Two')).top, lessThan(front.top));
    });

    testWidgets('a hovering mouse fans it out, and leaving folds it', (
      tester,
    ) async {
      await pump(tester, CoilSidebarCalloutExpand.onHover);
      final rest = pileHeight(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('One')));
      await tester.pumpAndSettle();
      final card = tester.getSize(find.byType(CoilCard).first).height;
      expect(pileHeight(tester), 3 * card + 2 * 4);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(pileHeight(tester), rest);
    });

    testWidgets('banners never fan out', (tester) async {
      await pump(tester, CoilSidebarCalloutExpand.never);
      final rest = pileHeight(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.text('One')));
      await tester.pumpAndSettle();
      expect(pileHeight(tester), rest);
    });

    testWidgets('dismissing the front card brings the next forward', (
      tester,
    ) async {
      await pump(tester, CoilSidebarCalloutExpand.onHover);
      final front = tester.getRect(find.text('One'));
      // The dismiss button shows under a hovering mouse.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.text('One')));
      await tester.pumpAndSettle();
      final dismiss = tester.getCenter(find.bySemanticsLabel('Dismiss').first);
      await mouse.moveTo(dismiss);
      await tester.pumpAndSettle();
      await tester.tapAt(dismiss, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      // Leaving folds the pile again.
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.text('One'), findsNothing);
      expect(tester.getRect(find.text('Two')).top, front.top);
    });
  });

  group('settings dialog', () {
    final sections = [
      for (final name in ['General', 'Members'])
        CoilSettingsSection(
          value: name,
          label: name,
          description: '$name settings.',
          builder: (context) => CoilSettingsList(
            children: [
              CoilSettingRow(
                label: Text('$name row'),
                trailing: const SizedBox(width: 20, height: 20),
              ),
            ],
          ),
        ),
    ];

    Widget opener() => Builder(
      builder: (context) => Center(
        child: CoilButton(
          onPressed: () => showCoilSettingsDialog<String>(
            context: context,
            title: 'Settings',
            sections: sections,
          ),
          child: const Text('Open'),
        ),
      ),
    );

    testWidgets('wide, a sidebar picks the section', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(tier: CoilTier.pointer, home: opener()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('General row'), findsOneWidget);
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();
      expect(find.text('Members row'), findsOneWidget);
      expect(find.text('Members settings.'), findsOneWidget);
      expect(find.byType(CoilSelect<String>), findsNothing);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Members row'), findsNothing);
    });

    testWidgets('on a phone, a select picks the section in a sheet', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(testApp(tier: CoilTier.touch, home: opener()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(CoilSidebar), findsNothing);
      expect(find.byType(CoilSelect<String>), findsOneWidget);
      expect(find.text('General row'), findsOneWidget);
    });
  });

  testWidgets('a group label shows its chevron at rest on touch', (
    tester,
  ) async {
    Future<int> chevrons(CoilTier tier) async {
      await tester.pumpWidget(
        testApp(
          tier: tier,
          home: CoilSidebarGroup(
            label: 'Mail',
            onExpandedChanged: (_) {},
            child: const Text('Inbox'),
          ),
        ),
      );
      return find.byType(CoilDrawnGlyph).evaluate().length;
    }

    expect(await chevrons(CoilTier.pointer), 0);
    expect(await chevrons(CoilTier.touch), 1);
  });

  group('pattern', () {
    for (final direction in TextDirection.values) {
      testWidgets('a collapsible group label is a disclosure '
          '(${direction.name})', (tester) async {
        var open = true;
        await tester.pumpWidget(
          testApp(
            tier: CoilTier.pointer,
            home: Directionality(
              textDirection: direction,
              child: StatefulBuilder(
                builder: (context, setState) => CoilSidebarGroup(
                  key: const ValueKey('target'),
                  label: 'Mail',
                  expanded: open,
                  onExpandedChanged: (v) => setState(() => open = v),
                  child: const Text('Inbox'),
                ),
              ),
            ),
          ),
        );
        await expectCoilPattern(
          tester,
          find.descendant(
            of: find.byKey(const ValueKey('target')),
            matching: find.byType(CoilInteraction),
          ),
          CoilPattern.disclosure,
        );
      });

      testWidgets('an action is a button (${direction.name})', (tester) async {
        await tester.pumpWidget(
          testApp(
            tier: CoilTier.pointer,
            home: Directionality(
              textDirection: direction,
              child: Center(
                child: CoilSidebarAction(
                  key: const ValueKey('target'),
                  icon: const TestIcon(TestGlyph.plus),
                  semanticLabel: 'New thread',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        await expectCoilPattern(
          tester,
          find.byKey(const ValueKey('target')),
          CoilPattern.button,
        );
      });
    }
  });

  group('motion', () {
    Future<CoilSidebarController> pump(
      WidgetTester tester, {
      bool reduced = false,
      Map<CoilSidebarTrack<Object>, Motion>? motions,
    }) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);
      final controller = CoilSidebarController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(1200, 800),
              disableAnimations: reduced,
            ),
            child: CoilSidebarScaffold(
              controller: controller,
              motions: motions,
              sidebar: const CoilSidebar(children: [Text('Nav')]),
              body: const SizedBox.expand(key: ValueKey('page')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    double pageLeft(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const ValueKey('page'))).dx;

    testWidgets('folding glides, and reduced motion makes it instant', (
      tester,
    ) async {
      (await pump(tester)).open = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(pageLeft(tester), inExclusiveRange(0, 256));

      (await pump(tester, reduced: true)).open = false;
      await tester.pump();
      await tester.pump();
      expect(pageLeft(tester), 0);
    });

    testWidgets('motions override the width track', (tester) async {
      final controller = await pump(
        tester,
        motions: {CoilSidebarTrack.width: const Motion.instant()},
      );
      controller.open = false;
      await tester.pump();
      await tester.pump();
      expect(pageLeft(tester), 0);
    });
  });

  testWidgets('style: the instance wins over the theme over the fallback', (
    tester,
  ) async {
    Widget group({CoilSidebarStyle? style}) =>
        CoilSidebarGroup(label: 'Mail', style: style, child: const Text('x'));

    const themed = Color(0xFF00FF00);
    const own = Color(0xFFFF0000);
    await tester.pumpWidget(
      testApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              group(),
              CoilTheme(
                data: CoilTheme.of(context).withComponentStyle(
                  const CoilSidebarStyle(
                    labelColor: WidgetStatePropertyAll(themed),
                  ),
                ),
                child: Column(
                  children: [
                    group(),
                    group(
                      style: const CoilSidebarStyle(
                        labelColor: WidgetStatePropertyAll(own),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final colors = tester
        .widgetList<Text>(find.text('Mail'))
        .map((t) => t.style!.color)
        .toList();
    expect(colors, [CoilColors.light.mutedForeground, themed, own]);
  });
}
