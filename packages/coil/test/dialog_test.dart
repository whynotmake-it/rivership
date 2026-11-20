import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

/// A button that opens a dialog and records how it closed.
class _Opener extends StatelessWidget {
  const _Opener({
    required this.results,
    this.kind = CoilDialogKind.confirmation,
    this.dismissible = true,
  });

  final List<Object?> results;
  final CoilDialogKind kind;
  final bool dismissible;

  @override
  Widget build(BuildContext context) => Center(
    child: CoilButton(
      onPressed: () async {
        final result = await showCoilDialog<String>(
          context: context,
          kind: kind,
          dismissible: dismissible,
          builder: (context) => CoilDialog(
            title: const Text('Delete file?'),
            description: const Text('This cannot be undone.'),
            onClose: () => Navigator.pop(context, 'closed'),
            actions: [
              CoilButton(
                variant: CoilButtonVariant.secondary,
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Cancel'),
              ),
              CoilButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        results.add(result);
      },
      child: const Text('Open'),
    ),
  );
}

/// A button that opens [dialog] as [kind].
class _Show extends StatelessWidget {
  const _Show(this.dialog, {this.kind = CoilDialogKind.form});

  final WidgetBuilder dialog;
  final CoilDialogKind kind;

  @override
  Widget build(BuildContext context) => Center(
    child: CoilButton(
      onPressed: () =>
          showCoilDialog<void>(context: context, kind: kind, builder: dialog),
      child: const Text('Open'),
    ),
  );
}

CoilButton _action(
  String label, {
  CoilButtonVariant variant = CoilButtonVariant.primary,
}) => CoilButton(variant: variant, onPressed: () {}, child: Text(label));

/// The button whose label is [label].
Finder _button(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(CoilButton));

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Escape closes it and focus returns to the trigger', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final results = <Object?>[];
    await tester.pumpWidget(testApp(home: _Opener(results: results)));
    // Focus the trigger with the keyboard, then open it with Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Delete file?'), findsOneWidget);
    expect(
      CoilSurface.levelOf(tester.element(find.text('Delete file?'))),
      5,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Delete file?'), findsNothing);
    expect(results, [null]);
    final trigger = Focus.of(tester.element(find.text('Open')));
    expect(trigger.hasFocus, isTrue);
  });

  testWidgets('an action and the close button pop with their value', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final results = <Object?>[];
    await tester.pumpWidget(testApp(home: _Opener(results: results)));
    await open(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(results, ['delete', 'closed']);
  });

  testWidgets('a non-dismissible dialog ignores the scrim and Escape', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final results = <Object?>[];
    await tester.pumpWidget(
      testApp(home: _Opener(results: results, dismissible: false)),
    );
    await open(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Delete file?'), findsOneWidget);
    expect(results, isEmpty);
  });

  group('on a phone', () {
    testWidgets('a form opens as a sheet, primary action first', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: const _Opener(results: [], kind: CoilDialogKind.form),
        ),
      );
      await open(tester);
      expect(find.byType(CoilSheetPanel), findsOneWidget);
      final delete = tester.getTopLeft(find.text('Delete'));
      final cancel = tester.getTopLeft(find.text('Cancel'));
      expect(delete.dy, lessThan(cancel.dy));
    });

    testWidgets('a confirmation stays centered', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: const _Opener(results: []),
        ),
      );
      await open(tester);
      expect(find.byType(CoilSheetPanel), findsNothing);
      expect(find.text('Delete file?'), findsOneWidget);
    });
  });

  group('actions', () {
    Widget form(BuildContext context, {int fields = 1}) => CoilDialog(
      title: const Text('Publish post'),
      actions: [
        _action('Cancel', variant: CoilButtonVariant.ghost),
        _action('Save draft', variant: CoilButtonVariant.secondary),
        _action('Publish'),
      ],
      child: Column(
        spacing: 16,
        children: [
          for (var i = 0; i < fields; i++)
            CoilField(label: Text('Field $i'), child: const CoilInput()),
        ],
      ),
    );

    testWidgets('in a phone sheet, they stretch to the content width, '
        'primary first', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: _Show(form)),
      );
      await open(tester);
      expect(find.byType(CoilSheetPanel), findsOneWidget);
      final field = tester.getRect(find.byType(CoilInput));
      final rects = [
        for (final label in ['Publish', 'Save draft', 'Cancel'])
          tester.getRect(_button(label)),
      ];
      for (final rect in rects) {
        expect(rect.left, field.left);
        expect(rect.right, field.right);
        // The touch tier's button height.
        expect(rect.height, 44);
      }
      // Primary on top, Cancel at the bottom, 8 apart.
      expect(rects[1].top - rects[0].bottom, 8);
      expect(rects[2].top - rects[1].bottom, 8);
    });

    testWidgets('in a phone sheet, they stay pinned above the home '
        'indicator while the body scrolls', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: _Show((context) => form(context, fields: 20)),
        ),
      );
      await open(tester);
      const screen = TestScreen.phone;
      final bottom = screen.size.height - screen.padding.bottom;
      final cancel = tester.getRect(_button('Cancel'));
      expect(cancel.bottom, bottom - 8);
      // The actions aren't in the scrolling body.
      final body = find.ancestor(
        of: find.text('Field 0'),
        matching: find.byType(SingleChildScrollView),
      );
      expect(
        find.descendant(of: body, matching: _button('Publish')),
        findsNothing,
      );
      await tester.drag(find.text('Field 3'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getRect(_button('Cancel')), cancel);
    });

    testWidgets('a centered confirmation on a phone stacks them too', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: _Show(
            kind: CoilDialogKind.confirmation,
            (context) => CoilDialog(
              title: const Text('Delete project?'),
              actions: [
                _action('Cancel', variant: CoilButtonVariant.secondary),
                _action('Delete', variant: CoilButtonVariant.destructive),
              ],
            ),
          ),
        ),
      );
      await open(tester);
      expect(find.byType(CoilSheetPanel), findsNothing);
      final delete = tester.getRect(_button('Delete'));
      final cancel = tester.getRect(_button('Cancel'));
      expect(delete.width, cancel.width);
      expect(delete.left, cancel.left);
      expect(delete.bottom, lessThan(cancel.top));
      // The dialog's padding is all that's left on either side.
      final title = tester.getRect(find.text('Delete project?'));
      expect(delete.left, title.left);
    });

    testWidgets('one action on a phone is full width', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: _Show(
            kind: CoilDialogKind.confirmation,
            (context) => CoilDialog(
              title: const Text('Export finished'),
              actions: [_action('OK')],
            ),
          ),
        ),
      );
      await open(tester);
      final ok = tester.getRect(_button('OK'));
      final title = tester.getRect(find.text('Export finished'));
      expect(ok.left, title.left);
      // The panel is the window less 16 a side, with 24 of padding.
      expect(ok.width, TestScreen.phone.size.width - 2 * (16 + 24));
    });

    testWidgets('on the pointer tier they stay a trailing row', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(tier: CoilTier.pointer, home: _Show(form)),
      );
      await open(tester);
      final field = tester.getRect(find.byType(CoilInput));
      final cancel = tester.getRect(_button('Cancel'));
      final draft = tester.getRect(_button('Save draft'));
      final publish = tester.getRect(_button('Publish'));
      expect({cancel.top, draft.top, publish.top}, hasLength(1));
      expect(draft.left - cancel.right, 8);
      expect(publish.left - draft.right, 8);
      expect(publish.right, field.right);
      // At their own width, not stretched.
      expect(publish.width, lessThan(field.width / 3));
    });

    testWidgets('long labels at 2x text ellipsize inside the sheet', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const long =
          'Publish this post to every subscriber right now, '
          'including the ones who joined today';
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: _Show(
            (context) => CoilDialog(
              title: const Text('Publish post'),
              actions: [
                _action('Cancel', variant: CoilButtonVariant.secondary),
                _action(long),
              ],
              child: const CoilField(
                label: Text('Title'),
                child: CoilInput(),
              ),
            ),
          ),
        ),
      );
      await open(tester);
      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byType(CoilInput));
      final button = tester.getRect(_button(long));
      expect(button.left, field.left);
      expect(button.right, field.right);
      final label = tester.renderObject<RenderParagraph>(find.text(long));
      expect(label.didExceedMaxLines, isTrue);
    });
  });

  group('CoilActionBar', () {
    Widget bar(CoilActionBarLayout? layout, {CoilTier? tier}) => testApp(
      tier: tier,
      home: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 300,
          child: CoilActionBar(
            layout: layout,
            actions: [
              _action('Cancel', variant: CoilButtonVariant.secondary),
              _action('OK'),
            ],
          ),
        ),
      ),
    );

    testWidgets('picks the stack on a phone and the row elsewhere', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(bar(null, tier: CoilTier.touch));
      expect(tester.getSize(_button('OK')).width, 300);
      expect(tester.getSize(_button('Cancel')).width, 300);

      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(bar(null, tier: CoilTier.pointer));
      expect(tester.getSize(_button('OK')).width, lessThan(100));
      expect(
        tester.getTopLeft(_button('OK')).dx,
        greaterThan(tester.getTopRight(_button('Cancel')).dx),
      );
    });

    testWidgets('stacks in any sheet route, even in a wide window', (
      tester,
    ) async {
      // A touch-tier window wider than a phone's (a tablet, a phone in
      // landscape): a row on the page.
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(900, 600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: Builder(
            builder: (context) => Center(
              child: CoilButton(
                onPressed: () => Navigator.of(context).push(
                  CoilSheetRoute<void>(
                    context: context,
                    child: CoilSheetPanel(
                      child: CoilActionBar(
                        actions: [
                          _action(
                            'Cancel',
                            variant: CoilButtonVariant.secondary,
                          ),
                          _action('OK'),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final ok = tester.getRect(_button('OK'));
      final cancel = tester.getRect(_button('Cancel'));
      expect(ok.width, cancel.width);
      expect(ok.width, greaterThan(200));
      expect(ok.bottom, lessThan(cancel.top));
    });

    testWidgets("spacing defaults to the tier's gap", (tester) async {
      useScreen(tester, TestScreen.desktop);
      for (final (tier, gap) in [
        (CoilTier.pointer, CoilMetrics.pointer.gap),
        (CoilTier.touch, CoilMetrics.touch.gap),
      ]) {
        await tester.pumpWidget(bar(CoilActionBarLayout.stack, tier: tier));
        final ok = tester.getRect(_button('OK'));
        final cancel = tester.getRect(_button('Cancel'));
        expect(cancel.top - ok.bottom, gap, reason: '$tier');
      }
    });

    testWidgets('a layout given overrides the choice', (tester) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(bar(CoilActionBarLayout.stack));
      final ok = tester.getRect(_button('OK'));
      final cancel = tester.getRect(_button('Cancel'));
      expect(ok.width, 300);
      expect(ok.bottom, lessThan(cancel.top));
    });
  });
}
