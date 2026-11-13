import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _CommitIntent extends Intent {
  const _CommitIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

const _composingValue = TextEditingValue(
  text: 'にほ',
  selection: TextSelection.collapsed(offset: 2),
  composing: TextRange(start: 0, end: 2),
);

const _committedValue = TextEditingValue(
  text: '日本',
  selection: TextSelection.collapsed(offset: 2),
);

/// A bare [WidgetsApp] (no Material or Cupertino app), with a navigator so
/// the selection overlay has an [Overlay].
Widget _app(
  Widget child, {
  bool supportsShowingSystemContextMenu = false,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, _, _) => builder(context),
  ),
  builder: (context, navigator) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      supportsShowingSystemContextMenu: supportsShowingSystemContextMenu,
    ),
    child: navigator!,
  ),
  home: CoilTheme(
    data: CoilThemeData.light,
    child: Center(child: SizedBox(width: 240, child: child)),
  ),
);

void main() {
  group('CoilTextFieldCore IME', () {
    testWidgets(
      'Enter while composing goes to the IME, not to the shortcut or submit',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        var commits = 0;
        String? submitted;
        await tester.pumpWidget(
          _app(
            CoilTextFieldCore(
              controller: controller,
              onSubmitted: (v) => submitted = v,
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): _CommitIntent(),
              },
              actions: {
                _CommitIntent: CallbackAction<_CommitIntent>(
                  onInvoke: (_) => commits++,
                ),
              },
            ),
          ),
        );
        await tester.tap(find.byType(EditableText));
        await tester.pump();

        tester.testTextInput.updateEditingValue(_composingValue);
        await tester.pump();
        final handled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(commits, 0);
        expect(submitted, isNull);
        // Not handled: the platform passes the key on to the IME.
        expect(handled, isFalse);
        expect(controller.value.composing.isValid, isTrue);

        // The IME commits; now Enter reaches the shortcut and the text input
        // action submits.
        tester.testTextInput.updateEditingValue(_committedValue);
        await tester.pump();
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
        expect(commits, 1);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(submitted, '日本');
      },
    );

    testWidgets('arrow shortcuts are ignored while composing', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var moves = 0;
      // An ancestor's action: the core guards it too.
      await tester.pumpWidget(
        _app(
          Actions(
            actions: {
              _NextIntent: CallbackAction<_NextIntent>(
                onInvoke: (_) => moves++,
              ),
            },
            child: CoilTextFieldCore(
              controller: controller,
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.arrowDown): _NextIntent(),
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();

      tester.testTextInput.updateEditingValue(_composingValue);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(moves, 0);
      expect(controller.value.composing, const TextRange(start: 0, end: 2));

      tester.testTextInput.updateEditingValue(_committedValue);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(moves, 1);
    });

    testWidgets('keeps the composing region and reports changes', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      await tester.pumpWidget(
        _app(
          CoilTextFieldCore(
            controller: controller,
            placeholder: const Text('Name'),
            onChanged: changes.add,
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(find.text('Name'), findsOneWidget);

      tester.testTextInput.updateEditingValue(_composingValue);
      await tester.pump();
      expect(controller.value.composing, const TextRange(start: 0, end: 2));
      expect(changes, ['にほ']);
      expect(find.text('Name'), findsNothing);
    });
  });

  group('CoilTextFieldCore multi-line', () {
    testWidgets('Return inserts a newline and never submits', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? submitted;
      await tester.pumpWidget(
        _app(
          CoilTextFieldCore(
            controller: controller,
            minLines: 3,
            maxLines: 10,
            onSubmitted: (v) => submitted = v,
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      final config = tester.testTextInput.setClientArgs!;
      expect(
        (config['inputType'] as Map)['name'],
        'TextInputType.multiline',
      );
      expect(config['inputAction'], 'TextInputAction.newline');

      // The IME inserts the newline as an edit; the newline action itself
      // doesn't submit a multi-line field.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'one\n',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pump();
      expect(controller.text, 'one\n');
      expect(submitted, isNull);
    });

    testWidgets(
      'Enter during a composition neither sends nor adds a newline',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        var sends = 0;
        await tester.pumpWidget(
          _app(
            CoilTextFieldCore(
              controller: controller,
              maxLines: null,
              // A composer: Enter sends, Shift+Enter is left to the field.
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): _CommitIntent(),
              },
              actions: {
                _CommitIntent: CallbackAction<_CommitIntent>(
                  onInvoke: (_) => sends++,
                ),
              },
            ),
          ),
        );
        await tester.tap(find.byType(EditableText));
        await tester.pump();

        tester.testTextInput.updateEditingValue(_composingValue);
        await tester.pump();
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
        expect(sends, 0);
        expect(controller.text, 'にほ');
        expect(controller.value.composing.isValid, isTrue);

        // The IME commits on that Enter; the next Enter sends.
        tester.testTextInput.updateEditingValue(_committedValue);
        await tester.pump();
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
        expect(sends, 1);
        expect(controller.text, '日本');

        // Shift+Enter isn't the shortcut: it reaches the field.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        expect(sends, 1);
      },
    );

    testWidgets('grows from minLines to maxLines, then scrolls', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          CoilTextFieldCore(
            controller: controller,
            style: const TextStyle(fontSize: 10, height: 2),
            minLines: 3,
            maxLines: 5,
          ),
        ),
      );
      double height() => tester.getSize(find.byType(EditableText)).height;
      expect(height(), 60);
      controller.text = List.filled(4, 'line').join('\n');
      await tester.pump();
      expect(height(), 80);
      controller.text = List.filled(12, 'line').join('\n');
      await tester.pump();
      expect(height(), 100);
    });
  });

  group('CoilTextFieldCore platform input', () {
    testWidgets('passes autofill hints and keyboard settings', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const AutofillGroup(
            child: CoilTextFieldCore(
              autofillHints: [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      final config = tester.testTextInput.setClientArgs!;
      expect((config['autofill'] as Map)['hints'], [AutofillHints.email]);
      expect(
        (config['inputType'] as Map)['name'],
        'TextInputType.emailAddress',
      );
      expect(config['inputAction'], 'TextInputAction.next');
      expect(config['autocorrect'], isFalse);
    });

    testWidgets('obscured text hides the value everywhere', (tester) async {
      final controller = TextEditingController(text: 'hunter2');
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          CoilTextFieldCore(
            controller: controller,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      final config = tester.testTextInput.setClientArgs!;
      expect(config['obscureText'], isTrue);
      // Never autocorrected or suggested, whatever the caller asked.
      expect(config['autocorrect'], isFalse);
      expect(config['enableSuggestions'], isFalse);
      final node = tester.getSemantics(find.byType(EditableText));
      expect(node.flagsCollection.isObscured, isTrue);
      expect(node.value, isNot(contains('hunter2')));
      // Copy and cut are unavailable on obscured text.
      final state = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(state.copyEnabled, isFalse);
      expect(state.cutEnabled, isFalse);
      semantics.dispose();
    });
  });

  group('CoilTextFieldCore selection', () {
    testWidgets(
      'touch: tap places the caret, double-tap selects a word with handles',
      (tester) async {
        final controller = TextEditingController(text: 'hello world');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(CoilTextFieldCore(controller: controller)),
        );
        final field = tester.getRect(find.byType(EditableText));
        final onHello = field.centerLeft + const Offset(10, 0);
        await tester.tapAt(onHello);
        await tester.pump(const Duration(milliseconds: 500));
        expect(controller.selection.isCollapsed, isTrue);

        await tester.tapAt(onHello);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(onHello);
        await tester.pumpAndSettle();
        expect(
          controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5),
        );
        final state = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(state.selectionOverlay?.handlesAreVisible, isTrue);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );

    testWidgets(
      'mouse: drag selects and shows no touch handles',
      (tester) async {
        final controller = TextEditingController(text: 'hello world');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(CoilTextFieldCore(controller: controller)),
        );
        final field = tester.getRect(find.byType(EditableText));
        final gesture = await tester.startGesture(
          field.centerLeft + const Offset(1, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        await gesture.moveTo(field.centerLeft + const Offset(60, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.selection.isCollapsed, isFalse);
        expect(controller.selection.start, 0);
        final state = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(state.selectionOverlay?.handlesAreVisible ?? false, isFalse);
      },
      variant: TargetPlatformVariant.desktop(),
    );
  });

  group('CoilTextFieldCore context menu', () {
    testWidgets(
      'iOS uses the system edit menu when supported',
      (tester) async {
        final controller = TextEditingController(text: 'one two');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            CoilTextFieldCore(controller: controller),
            supportsShowingSystemContextMenu: true,
          ),
        );
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        final state = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(state.showToolbar(), isTrue);
        await tester.pump();
        expect(find.byType(SystemContextMenu), findsOneWidget);
        state.hideToolbar();
        await tester.pump();
        expect(find.byType(SystemContextMenu), findsNothing);
      },
      skip: kIsWeb, // The browser's own menu shows on web.
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'iOS falls back to the Cupertino toolbar when unsupported',
      (tester) async {
        final controller = TextEditingController(text: 'one two');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(CoilTextFieldCore(controller: controller)),
        );
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        final state = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 3,
        );
        await tester.pump();
        expect(state.showToolbar(), isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(SystemContextMenu), findsNothing);
        // Labels from the default Cupertino localizations, supplied by the
        // core under a bare WidgetsApp.
        expect(find.text('Copy'), findsOneWidget);
      },
      skip: kIsWeb, // The browser's own menu shows on web.
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'long-press shows the Material toolbar under a bare WidgetsApp',
      (tester) async {
        final controller = TextEditingController(text: 'hello world');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(CoilTextFieldCore(controller: controller)),
        );
        // On the first word, not past the end of the text.
        final field = tester.getRect(find.byType(EditableText));
        await tester.longPressAt(field.centerLeft + const Offset(8, 0));
        await tester.pumpAndSettle();
        expect(controller.selection.isCollapsed, isFalse);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Select all'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      skip: kIsWeb, // The browser's own menu shows on web.
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });
}
