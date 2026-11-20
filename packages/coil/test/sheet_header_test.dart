import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);
final _android = TargetPlatformVariant.only(TargetPlatform.android);

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(CoilSheetPanel), matching: finder);

Rect _sheet(WidgetTester tester) => tester.getRect(find.byType(CoilSheetPanel));

Rect _close(WidgetTester tester) =>
    tester.getRect(find.byType(CoilSheetCloseButton));

/// The painted extent of the sheet title's text, not its box.
Rect _titleInk(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    _inSheet(find.text(text)),
  );
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  final origin = paragraph.localToGlobal(Offset.zero);
  var rect = boxes.first.toRect();
  for (final box in boxes.skip(1)) {
    rect = rect.expandToInclude(box.toRect());
  }
  return rect.shift(origin);
}

/// A phone with a select whose list opens in a sheet titled "Fruit".
Future<void> _openSelect(
  WidgetTester tester, {
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
}) async {
  useScreen(tester, TestScreen.phone);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  const colors = CoilColors.light;
  await tester.pumpWidget(
    WidgetsApp(
      color: colors.brand,
      // The direction above the navigator, so the sheet's route gets it.
      builder: (context, navigator) => Directionality(
        textDirection: direction,
        child: CoilAdaptiveScope(
          tier: CoilTier.touch,
          child: CoilTheme(
            data: CoilThemeData(typography: CoilTypography.allo()),
            child: ColoredBox(color: colors.background, child: navigator),
          ),
        ),
      ),
      onGenerateRoute: (settings) => PageRouteBuilder<void>(
        settings: settings,
        pageBuilder: (context, _, _) => const SelectDemo(options: moreFruits),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('select')));
  await tester.pumpAndSettle();
  expect(find.byType(CoilSheetPanel), findsOneWidget);
}

/// A route pushed with [builder] over a phone page, opened.
Future<void> _openModal(
  WidgetTester tester,
  WidgetBuilder builder, {
  bool dismissible = true,
}) async {
  useScreen(tester, TestScreen.phone);
  await tester.pumpWidget(
    testApp(
      tier: CoilTier.touch,
      home: Builder(
        builder: (context) => Center(
          child: CoilButton(
            onPressed: () => showCoilModal<void>(
              context: context,
              presentation: CoilModalPresentation.sheet,
              dismissible: dismissible,
              builder: builder,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'iOS: the close button leads, concentric with the corner, and the '
    'title is centered on its line',
    (tester) async {
      await _openSelect(tester);
      final sheet = _sheet(tester);
      final close = _close(tester);
      final center = CoilSheetPanel.headerCenterOf(
        tester.element(find.byType(CoilSheetPanel)),
      );
      // The corner's center: 36 in from the top and the leading edge.
      expect(center, CoilSheetRoute.glassRadius);
      expect(close.center.dx - sheet.left, closeTo(center, 0.01));
      expect(close.center.dy - sheet.top, closeTo(center, 0.01));
      expect(close.size, const Size.square(44), reason: 'the hit target');
      final title = _titleInk(tester, 'Fruit');
      expect(title.center.dx, closeTo(sheet.center.dx, 0.5));
      expect(title.center.dy, closeTo(close.center.dy, 1));
    },
    variant: _ios,
  );

  testWidgets(
    'Android: the title starts with the rows and the close button trails',
    (tester) async {
      await _openSelect(tester);
      final sheet = _sheet(tester);
      final close = _close(tester);
      expect(sheet.right - close.center.dx, closeTo(36, 0.01));
      expect(close.center.dy - sheet.top, closeTo(36, 0.01));
      final title = tester.getRect(_inSheet(find.text('Fruit')));
      final row = tester.getRect(_inSheet(find.text('Apple')));
      expect(title.left, row.left, reason: 'aligned with the rows’ text');
      expect(title.left - sheet.left, 16);
      expect(
        _titleInk(tester, 'Fruit').center.dy,
        closeTo(close.center.dy, 1),
      );
    },
    variant: _android,
  );

  for (final variant in [_ios, _android]) {
    testWidgets(
      'the close button closes the sheet like a dismissal',
      (tester) async {
        await _openSelect(tester);
        await tester.tap(find.byType(CoilSheetCloseButton));
        await tester.pumpAndSettle();
        expect(find.byType(CoilSheetPanel), findsNothing);
        // The value didn't change.
        expect(find.text('Banana'), findsOneWidget);
      },
      variant: variant,
    );
  }

  testWidgets(
    'RTL mirrors: on Android the close button sits at the left and the '
    'title at the right',
    (tester) async {
      await _openSelect(tester, direction: TextDirection.rtl);
      final sheet = _sheet(tester);
      final close = _close(tester);
      expect(close.center.dx - sheet.left, closeTo(36, 0.01));
      final title = tester.getRect(_inSheet(find.text('Fruit')));
      final row = tester.getRect(_inSheet(find.text('Apple')));
      expect(sheet.right - title.right, 16);
      expect(title.right, row.right);
    },
    variant: _android,
  );

  testWidgets(
    'RTL mirrors: on iOS the close button sits at the right',
    (tester) async {
      await _openSelect(tester, direction: TextDirection.rtl);
      final sheet = _sheet(tester);
      expect(sheet.right - _close(tester).center.dx, closeTo(36, 0.01));
    },
    variant: _ios,
  );

  for (final variant in [_ios, _android]) {
    testWidgets(
      'a long title ends in an ellipsis before the close button',
      (tester) async {
        useScreen(tester, TestScreen.phone);
        await tester.pumpWidget(
          testApp(
            tier: CoilTier.touch,
            home: Center(
              child: SizedBox(
                width: 240,
                child: CoilSelect<String>(
                  options: moreFruits,
                  value: 'apple',
                  onChanged: (_) {},
                  sheetTitle: const Text(
                    'Choose the fruit you would like delivered with every '
                    'weekly order',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Apple'));
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(
          _inSheet(find.textContaining('Choose the fruit')),
        );
        expect(paragraph.didExceedMaxLines, isTrue);
        final title = tester.getRect(_inSheet(find.textContaining('Choose')));
        final close = _close(tester);
        // A gap between the title's box and the button's hit target.
        expect(
          title.left >= close.right || title.right <= close.left,
          isTrue,
          reason: 'title $title, close $close',
        );
        expect(title.height, lessThan(30), reason: 'one line');
      },
      variant: variant,
    );
  }

  for (final variant in [_ios, _android]) {
    testWidgets(
      'at text scale 2 the title and button stay on one line, centered '
      'together',
      (tester) async {
        await _openSelect(tester, textScale: 2);
        expect(tester.takeException(), isNull);
        final close = _close(tester);
        expect(close.width, greaterThan(44), reason: 'grows with its glyph');
        expect(
          _titleInk(tester, 'Fruit').center.dy,
          closeTo(close.center.dy, 1),
        );
        // A bigger button keeps 12 from the edges, so its center moves in.
        expect(
          close.center.dy - _sheet(tester).top,
          closeTo(
            CoilSheetPanel.headerCenterOf(
              tester.element(find.byType(CoilSheetPanel)),
            ),
            0.01,
          ),
        );
      },
      variant: variant,
    );
  }

  testWidgets('the close button is a button named Close, reached by Tab and '
      'pressed by Enter', (tester) async {
    final semantics = tester.ensureSemantics();
    // A modal sheet: a select's list takes Tab as a dismissal.
    await _openModal(
      tester,
      (context) => const CoilSheetPanel(
        title: Text('Sheet'),
        child: SizedBox(height: 100),
      ),
    );
    expect(
      tester.getSemantics(find.byType(CoilSheetCloseButton)),
      matchesSemantics(
        label: 'Close',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    bool closeFocused() {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null) return false;
      var found = false;
      focused.visitAncestorElements((element) {
        found = element.widget is CoilSheetCloseButton;
        return !found;
      });
      return found;
    }

    var tabs = 0;
    while (!closeFocused() && tabs < 20) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      tabs++;
    }
    expect(closeFocused(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(CoilSheetPanel), findsNothing);
    semantics.dispose();
  });

  testWidgets('no title and no close button: no header, content at topGap', (
    tester,
  ) async {
    await _openModal(
      tester,
      (context) => const CoilSheetPanel(
        close: null,
        child: SizedBox(height: 100, key: ValueKey('content')),
      ),
    );
    final top =
        tester.getRect(find.byKey(const ValueKey('content'))).top -
        _sheet(tester).top;
    expect(top, CoilSheetPanel.topGap);
  });

  testWidgets('a sheet that cannot be dismissed hides the default button', (
    tester,
  ) async {
    await _openModal(
      tester,
      dismissible: false,
      (context) => const CoilSheetPanel(
        title: Text('Locked'),
        child: SizedBox(height: 100),
      ),
    );
    expect(find.byType(CoilSheetCloseButton), findsNothing);
    expect(find.text('Locked'), findsOneWidget);
  });

  testWidgets('a form dialog as a sheet has one close button; onClose runs', (
    tester,
  ) async {
    var closed = 0;
    await _openModal(
      tester,
      (context) => CoilDialog(
        title: const Text('Edit'),
        onClose: () => closed++,
        actions: [CoilButton(onPressed: () {}, child: const Text('Save'))],
        child: const SizedBox(height: 40),
      ),
    );
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.byType(CoilSheetCloseButton), findsOneWidget);
    await tester.tap(find.byType(CoilSheetCloseButton));
    await tester.pumpAndSettle();
    expect(closed, 1);
  });

  testWidgets('a form dialog sheet lines its body up with its title', (
    tester,
  ) async {
    await _openModal(
      tester,
      (context) => const CoilDialog(
        title: Text('Edit'),
        description: Text('One sentence.'),
      ),
    );
    final title = tester.getRect(_inSheet(find.text('Edit')));
    final body = tester.getRect(find.text('One sentence.'));
    expect(body.left, title.left);
  });

  testWidgets(
    'a settings dialog as a sheet has one close button and its title in '
    'the header',
    (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: Builder(
            builder: (context) => Center(
              child: CoilButton(
                onPressed: () => showCoilSettingsDialog<int>(
                  context: context,
                  title: const Text('Settings'),
                  sections: [
                    CoilSettingsSection(
                      value: 0,
                      label: const Text('General'),
                      semanticLabel: 'General',
                      builder: (context) => const SizedBox(height: 40),
                    ),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetCloseButton), findsOneWidget);
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      final title = tester.getRect(find.text('Settings'));
      final close = _close(tester);
      expect(title.center.dy, closeTo(close.center.dy, 1));
      await tester.tap(find.byType(CoilSheetCloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsNothing);
    },
    variant: _android,
  );

  testWidgets(
    'a command menu sheet ends its search line with the close button',
    (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: Builder(
            builder: (context) => Center(
              child: CoilButton(
                onPressed: () => showCoilCommandMenu(
                  context: context,
                  entries: [
                    CoilAction(
                      label: const Text('Inbox'),
                      searchText: 'Inbox',
                      onPressed: () {},
                    ),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetCloseButton), findsOneWidget);
      final sheet = _sheet(tester);
      final close = _close(tester);
      final field = tester.getRect(find.byType(CoilTextFieldCore));
      expect(close.center.dy - sheet.top, closeTo(36, 0.01));
      expect(sheet.right - close.center.dx, closeTo(36, 0.01));
      expect(field.center.dy, closeTo(close.center.dy, 1));
      expect(field.right, lessThan(close.left));
      await tester.tap(find.byType(CoilSheetCloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsNothing);
    },
    variant: _ios,
  );

  testWidgets(
    'a combobox sheet without a title puts the close button beside its '
    'field',
    (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: Center(
            child: SizedBox(
              width: 240,
              child: CoilCombobox<String>(
                options: moreFruits,
                value: null,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CoilCombobox<String>));
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetCloseButton), findsOneWidget);
      final sheet = _sheet(tester);
      final close = _close(tester);
      expect(close.center.dy - sheet.top, closeTo(36, 0.01));
      expect(sheet.right - close.center.dx, closeTo(36, 0.01));
    },
    variant: _android,
  );
}
