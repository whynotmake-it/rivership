import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

/// A menu with a submenu, opened from a button.
Widget _menu() => Align(
  alignment: const Alignment(-0.8, -0.8),
  child: CoilDropdown(
    entries: [
      CoilAction(
        label: const Text('Open'),
        searchText: 'Open',
        onPressed: () {},
      ),
      CoilSubmenu(
        label: const Text('Share'),
        searchText: 'Share',
        entries: [
          CoilAction(
            label: const Text('Email'),
            searchText: 'Email',
            onPressed: () {},
          ),
        ],
      ),
    ],
    builder: (context, menu) =>
        CoilButton(onPressed: menu.open, child: const Text('Actions')),
  ),
);

/// [child] under an app-level action for [T] that logs to [log] while
/// [enabled] says so.
Widget _overriding<T extends Intent>(
  Widget child,
  List<String> log, {
  bool Function()? enabled,
}) => Actions(
  actions: {T: _LogAction<T>(log, enabled ?? () => true)},
  child: child,
);

class _LogAction<T extends Intent> extends Action<T> {
  _LogAction(this.log, this.enabled);

  final List<String> log;
  final bool Function() enabled;

  @override
  bool isEnabled(T intent) => enabled();

  @override
  Object? invoke(T intent) {
    log.add(switch (intent) {
      final CoilSliderStepIntent step =>
        'step ${step.steps} ${step.increment.name}',
      final CoilSliderLimitIntent limit => 'limit ${limit.limit.name}',
      _ => '$T',
    });
    return null;
  }
}

Future<void> _openWithKeyboard(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

void main() {
  group('CoilDismissIntent', () {
    testWidgets('an app action above the menu replaces what Escape does', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      final log = <String>[];
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: _overriding<CoilDismissIntent>(_menu(), log),
        ),
      );
      await _openWithKeyboard(tester);
      expect(find.text('Open'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(log, ['CoilDismissIntent']);
      expect(find.text('Open'), findsOneWidget, reason: 'still open');
    });

    testWidgets('the override reaches a submenu nested in the menu', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      final log = <String>[];
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: _overriding<CoilDismissIntent>(_menu(), log),
        ),
      );
      await _openWithKeyboard(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(log, ['CoilDismissIntent']);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('a disabled override leaves coil closing the innermost popup', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      final log = <String>[];
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: _overriding<CoilDismissIntent>(
            _menu(),
            log,
            enabled: () => false,
          ),
        ),
      );
      await _openWithKeyboard(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // The submenu closes, not the menu around it.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsNothing);
      expect(find.text('Share'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Share'), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('a widget whose own action is off passes Escape to the coil '
        'popup around it', (tester) async {
      final log = <String>[];
      var open = true;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (outer) => Actions(
              actions: {
                CoilDismissIntent: CoilDefaultAction<CoilDismissIntent>(
                  context: outer,
                  onInvoke: (_) => log.add('outer'),
                ),
              },
              child: Builder(
                builder: (inner) => Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.escape):
                        CoilDismissIntent(),
                  },
                  child: Actions(
                    actions: {
                      CoilDismissIntent: CoilDefaultAction<CoilDismissIntent>(
                        context: inner,
                        isEnabled: (_) => open,
                        onInvoke: (_) => log.add('inner'),
                      ),
                    },
                    child: const Focus(autofocus: true, child: SizedBox()),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      open = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(log, ['inner', 'outer']);
    });
  });

  group('slider intents', () {
    Widget slider(List<String> log, ValueChanged<double> onChanged) => testApp(
      tier: CoilTier.pointer,
      home: Center(
        child: SizedBox(
          width: 240,
          child: _overriding<CoilSliderLimitIntent>(
            _overriding<CoilSliderStepIntent>(
              CoilSlider(
                value: 0.5,
                onChanged: onChanged,
                autofocus: true,
                label: const Text('Volume'),
              ),
              log,
            ),
            log,
          ),
        ),
      ),
    );

    testWidgets('an app action above a slider replaces its keys', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      final log = <String>[];
      final changes = <double>[];
      await tester.pumpWidget(slider(log, changes.add));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(log, ['step 1 step', 'step -1 page', 'limit max']);
      expect(changes, isEmpty);
    });

    testWidgets('without an override the keys move the value', (tester) async {
      useScreen(tester, TestScreen.desktop);
      final changes = <double>[];
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: Center(
            child: SizedBox(
              width: 240,
              child: CoilSlider(
                value: 0.5,
                onChanged: changes.add,
                autofocus: true,
                label: const Text('Volume'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(changes, [closeTo(0.51, 1e-9), 1.0]);
    });
  });
}
