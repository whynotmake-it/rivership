import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/coil_pattern.dart';
import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';
import 'src/ink_centering.dart';
import 'src/test_icons.dart';

const _names = ['Home', 'Projects', 'Coil', 'Components', 'Breadcrumb'];

List<CoilCrumb> _crumbs([List<String> names = _names, List<String>? log]) => [
  for (final (i, name) in names.indexed)
    CoilCrumb(
      label: name,
      icon: i == 0 ? const TestIcon(TestGlyph.home) : null,
      onPressed: () => log?.add(name),
    ),
];

Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  TextDirection direction = TextDirection.ltr,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, navigator) => Directionality(
    textDirection: direction,
    child: CoilTheme(
      data: CoilThemeData.light.copyWith(tier: tier),
      child: navigator!,
    ),
  ),
  onGenerateRoute: (_) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KeyedSubtree(key: const ValueKey('target'), child: child),
          const SizedBox(height: 16),
          CoilButton(onPressed: () {}, child: const Text('After')),
        ],
      ),
    ),
  ),
);

final _target = find.byKey(const ValueKey('target'));
final _more = find.text('…');

/// Whether [label]'s crumb paints in the trail.
bool _shown(WidgetTester tester, String label) {
  final semantics = tester.ensureSemantics();
  final found = find.semantics.byLabel(label).evaluate().isNotEmpty;
  semantics.dispose();
  return found;
}

void main() {
  matrixGoldenTest(
    'breadcrumb',
    (context) => SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          CoilBreadcrumb(crumbs: _crumbs(['Home', 'Docs', 'Breadcrumb'])),
          CoilBreadcrumb(crumbs: _crumbs()),
        ],
      ),
    ),
    surface: const Size(2000, 1300),
  );

  testWidgets('breadcrumb sheet: hover, collapse, separator, menu', (
    tester,
  ) async {
    Widget panel(String name, CoilThemeData theme) => SheetPanel(
      title: name,
      theme: theme.copyWith(tier: CoilTier.pointer),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          CoilBreadcrumb(crumbs: _crumbs()),
          SizedBox(width: 260, child: CoilBreadcrumb(crumbs: _crumbs())),
          CoilBreadcrumb(
            crumbs: _crumbs(['Home', 'Docs', 'Breadcrumb']),
            separator: const Text('/'),
          ),
          CoilBreadcrumb(
            size: CoilSize.regular,
            crumbs: [
              ..._crumbs(['Home', 'Docs']),
              const CoilCrumb(label: 'Archived'),
              const CoilCrumb(label: 'Breadcrumb'),
            ],
          ),
        ],
      ),
    );
    final sheet = await pumpSheet(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          panel('light', CoilThemeData.light),
          panel('dark', CoilThemeData.dark),
        ],
      ),
      surface: const Size(1000, 340),
    );
    // A mouse over "Projects" in the light panel's first trail.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Projects').at(0)));
    await tester.pump();
    await settle(tester);
    await expectSheetGolden(tester, sheet, 'goldens/breadcrumb.png');
  });

  for (final (name, theme, tier, width) in [
    ('popover_light', CoilThemeData.light, CoilTier.pointer, 600.0),
    ('popover_dark', CoilThemeData.dark, CoilTier.pointer, 600.0),
    ('sheet_light', CoilThemeData.light, CoilTier.touch, 390.0),
    ('sheet_dark', CoilThemeData.dark, CoilTier.touch, 390.0),
  ]) {
    testWidgets('breadcrumb menu golden: $name', (tester) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = Size(width, 520) * 2;
      addTearDown(tester.view.reset);
      final names = [
        'Home',
        for (var i = 1; i <= (tier == CoilTier.touch ? 10 : 3); i++)
          'Folder with a long name $i',
        'Breadcrumb',
      ];
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          debugShowCheckedModeBanner: false,
          builder: (context, navigator) => CoilTheme(
            data: theme.copyWith(tier: tier),
            child: Builder(
              builder: (context) => ColoredBox(
                color: CoilTheme.of(context).colors.background,
                child: navigator,
              ),
            ),
          ),
          onGenerateRoute: (_) => PageRouteBuilder<void>(
            pageBuilder: (context, _, _) => Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: width - 32,
                  child: CoilBreadcrumb(crumbs: _crumbs(names)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(_more);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/breadcrumb_menu_$name.png'),
      );
    });
  }

  group('ink centering', () {
    // Hiding the label by color keeps the layout identical.
    CoilBreadcrumbStyle? hide({required bool ink}) => ink
        ? null
        : const CoilBreadcrumbStyle(
            label: WidgetStatePropertyAll(Color(0x00000000)),
          );
    inkCenteringTests({
      'breadcrumb/link': (ink) => CoilBreadcrumb(
        style: hide(ink: ink),
        crumbs: [
          CoilCrumb(label: 'HEH', onPressed: () {}),
          const CoilCrumb(label: 'HEH'),
        ],
      ),
      'breadcrumb/page': (ink) => CoilBreadcrumb(
        style: hide(ink: ink),
        crumbs: const [CoilCrumb(label: 'HEH')],
      ),
    });
  });

  for (final direction in TextDirection.values) {
    testWidgets('is a navigation trail (${direction.name})', (tester) async {
      await tester.pumpWidget(
        _app(CoilBreadcrumb(crumbs: _crumbs()), direction: direction),
      );
      await expectCoilPattern(tester, _target, CoilPattern.navigation);
    });
  }

  testWidgets('Enter follows the focused link', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_app(CoilBreadcrumb(crumbs: _crumbs(_names, log))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(log, ['Projects']);
  });

  testWidgets('the page is foreground text, links are muted', (tester) async {
    await tester.pumpWidget(_app(CoilBreadcrumb(crumbs: _crumbs())));
    final colors = CoilThemeData.light.colors;
    Color colorOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;
    expect(colorOf('Projects'), colors.mutedForeground);
    expect(colorOf('Breadcrumb'), colors.foreground);
  });

  group('collapse', () {
    Widget trail(double width, {List<String>? log}) => SizedBox(
      width: width,
      child: CoilBreadcrumb(crumbs: _crumbs(_names, log)),
    );

    testWidgets('a trail that fits shows every crumb and no "…"', (
      tester,
    ) async {
      await tester.pumpWidget(_app(trail(600)));
      for (final name in _names) {
        expect(_shown(tester, name), isTrue, reason: name);
      }
      expect(_shown(tester, 'Show hidden pages'), isFalse);
    });

    testWidgets('a narrow trail hides middle crumbs from view, Tab and '
        'semantics; the first, last link and page stay', (tester) async {
      await tester.pumpWidget(_app(trail(260)));
      expect(_shown(tester, 'Home'), isTrue);
      expect(_shown(tester, 'Show hidden pages'), isTrue);
      expect(_shown(tester, 'Projects'), isFalse);
      expect(_shown(tester, 'Components'), isTrue);
      expect(_shown(tester, 'Breadcrumb'), isTrue);
      expect(
        tester.getSize(find.byType(CoilBreadcrumb)).width,
        lessThanOrEqualTo(260),
      );

      final reached = <String>[];
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final context = FocusManager.instance.primaryFocus?.context;
        final text = context == null
            ? null
            : find
                  .descendant(
                    of: find.byWidget(context.widget),
                    matching: find.byType(Text),
                  )
                  .evaluate()
                  .map((e) => (e.widget as Text).data)
                  .firstOrNull;
        if (text != null) reached.add(text);
      }
      expect(reached.take(4), ['Home', '…', 'Components', 'After']);
    });

    testWidgets('resizing re-decides in the same frame', (tester) async {
      final width = ValueNotifier<double>(600);
      addTearDown(width.dispose);
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder(
            valueListenable: width,
            builder: (context, w, _) => trail(w),
          ),
        ),
      );
      expect(_shown(tester, 'Coil'), isTrue);
      width.value = 260;
      await tester.pump();
      expect(_shown(tester, 'Coil'), isFalse);
      expect(_shown(tester, 'Show hidden pages'), isTrue);
    });

    testWidgets('phones show the first crumb, "…" and the last two', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(CoilBreadcrumb(crumbs: _crumbs()), tier: CoilTier.touch),
      );
      expect(_shown(tester, 'Home'), isTrue);
      expect(_shown(tester, 'Projects'), isFalse);
      expect(_shown(tester, 'Coil'), isFalse);
      expect(_shown(tester, 'Components'), isTrue);
      expect(_shown(tester, 'Breadcrumb'), isTrue);
    });

    testWidgets('"…" lists the hidden crumbs by full name; a pick follows', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(_app(trail(260, log: log)));
      await tester.tap(_more);
      await tester.pumpAndSettle();
      // The hidden crumbs stay built in the trail; the menu adds its rows.
      expect(find.text('Projects'), findsNWidgets(2));
      expect(find.text('Coil'), findsNWidgets(2));
      await tester.tap(find.text('Coil').last);
      await tester.pumpAndSettle();
      expect(log, ['Coil']);
      expect(find.text('Coil'), findsOneWidget, reason: 'the menu closed');
    });

    testWidgets('the menu works from the keyboard; Escape returns focus', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(_app(trail(260, log: log)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsNWidgets(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
          matching: find.byType(CoilBreadcrumb),
        ),
        findsOneWidget,
        reason: 'focus is back on "…"',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, ['Coil'], reason: 'the menu starts on the first row');
    });

    testWidgets('a phone with many hidden crumbs opens a sheet', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          CoilBreadcrumb(
            crumbs: _crumbs([for (var i = 0; i < 13; i++) 'Step $i']),
          ),
          tier: CoilTier.touch,
        ),
      );
      await tester.tap(_more);
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsOneWidget);
    });
  });

  group('pointer vs touch', () {
    testWidgets('a mouse lights the crumb under it', (tester) async {
      await tester.pumpWidget(_app(CoilBreadcrumb(crumbs: _crumbs())));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Coil')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Coil')).style!.color,
        CoilThemeData.light.colors.foreground,
      );
    });

    testWidgets('a tap leaves nothing lit and no ring', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          CoilBreadcrumb(crumbs: _crumbs(_names, log)),
          tier: CoilTier.touch,
        ),
      );
      await tester.tap(find.text('Coil'));
      await tester.pumpAndSettle();
      expect(log, ['Coil']);
      expect(
        tester.widget<Text>(find.text('Coil')).style!.color,
        CoilThemeData.light.colors.mutedForeground,
      );
      expect(
        tester
            .widgetList<CoilFocusRing>(find.byType(CoilFocusRing))
            .any((r) => r.visible),
        isFalse,
      );
    });

    testWidgets('crumbs are 44 px targets on touch', (tester) async {
      await tester.pumpWidget(
        _app(CoilBreadcrumb(crumbs: _crumbs()), tier: CoilTier.touch),
      );
      final target = find
          .ancestor(
            of: find.text('Coil'),
            matching: find.byType(CoilInteraction),
          )
          .first;
      expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
    });
  });

  testWidgets('RTL starts the trail on the right', (tester) async {
    await tester.pumpWidget(
      _app(CoilBreadcrumb(crumbs: _crumbs()), direction: TextDirection.rtl),
    );
    expect(
      tester.getCenter(find.text('Home')).dx,
      greaterThan(tester.getCenter(find.text('Breadcrumb')).dx),
    );
  });

  testWidgets('style: fallback < theme < instance', (tester) async {
    const themed = Color(0xFF00FF00);
    const own = Color(0xFF0000FF);
    Widget app(CoilThemeData theme, {CoilBreadcrumbStyle? style}) => WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, _) => CoilTheme(
        data: theme,
        child: CoilBreadcrumb(crumbs: _crumbs(), style: style),
      ),
    );
    Color page() => tester.widget<Text>(find.text('Breadcrumb')).style!.color!;
    await tester.pumpWidget(app(CoilThemeData.light));
    expect(page(), CoilThemeData.light.colors.foreground);
    final theme = CoilThemeData.light.withComponentStyle(
      const CoilBreadcrumbStyle(label: WidgetStatePropertyAll(themed)),
    );
    await tester.pumpWidget(app(theme));
    expect(page(), themed);
    await tester.pumpWidget(
      app(
        theme,
        style: const CoilBreadcrumbStyle(label: WidgetStatePropertyAll(own)),
      ),
    );
    expect(page(), own);
  });
}
