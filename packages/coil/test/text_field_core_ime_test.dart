import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
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
