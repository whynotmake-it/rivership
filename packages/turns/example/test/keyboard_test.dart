import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turns_example/src/demos/ai_assistant_demo.dart';
import 'package:turns_example/src/demos/imessage_demo.dart';
import 'package:turns_example/src/demos/slack_demo.dart';
import 'package:turns_example/src/demos/whatsapp_demo.dart';

const _screen = Size(390, 844);
const _keyboardHeight = 300.0;

/// Hosts [demo] on a phone whose keyboard height is [keyboard].
Widget _phone(Widget demo, ValueListenable<double> keyboard) {
  final theme = CoilThemeData.light.copyWith(typography: CoilTypography.allo());
  return WidgetsApp(
    color: theme.colors.brand,
    debugShowCheckedModeBanner: false,
    pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, _, _) => builder(context),
    ),
    home: CoilTheme(
      data: theme,
      child: CoilAdaptiveScope(
        tier: CoilTier.touch,
        child: ValueListenableBuilder<double>(
          valueListenable: keyboard,
          builder: (context, height, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: EdgeInsets.only(bottom: height),
            ),
            child: child!,
          ),
          child: Builder(
            builder: (context) => ColoredBox(
              color: CoilTheme.of(context).colors.background,
              child: DefaultTextStyle(
                style: CoilTheme.textOf(context).body,
                child: demo,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final demos = <String, Widget>{
    'AI assistant': const AiAssistantDemo(),
    'iMessage': const IMessageDemo(),
    'WhatsApp': const WhatsAppDemo(),
    'Slack': const SlackDemo(),
  };

  for (final MapEntry(key: name, value: demo) in demos.entries) {
    testWidgets(
      '$name: the composer rides above the keyboard, sending on a phone '
      'closes it, and the sent message stays in view while it closes',
      (tester) async {
        tester.view
          ..physicalSize = _screen
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final keyboard = ValueNotifier<double>(0);
        addTearDown(keyboard.dispose);

        await tester.pumpWidget(_phone(demo, keyboard));
        await _frames(tester, 40);

        final composer = find.byType(CoilInputMessage);
        final field = find.descendant(
          of: composer,
          matching: find.byType(EditableText),
        );

        // The keyboard slides up under a focused composer.
        await tester.tap(field);
        for (var frame = 1; frame <= 10; frame++) {
          keyboard.value = _keyboardHeight * frame / 10;
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.getRect(composer).bottom,
            lessThanOrEqualTo(_screen.height - keyboard.value + 1),
            reason: 'composer under the keyboard while it opens',
          );
        }
        await _frames(tester, 30);

        const sent = 'Keyboard check from the test';
        await tester.enterText(field, sent);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('send')));
        await tester.pump();
        expect(
          tester.widget<EditableText>(field).focusNode.hasFocus,
          isFalse,
          reason: 'sending on a phone gives up the keyboard',
        );

        // The keyboard slides away while the message and its reply come in.
        for (var frame = 1; frame <= 10; frame++) {
          keyboard.value = _keyboardHeight * (10 - frame) / 10;
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.getRect(composer).bottom,
            lessThanOrEqualTo(_screen.height - keyboard.value + 1),
            reason: 'composer under the keyboard while it closes',
          );
        }
        await _frames(tester, 180);

        // The sent message is on screen, clear of the composer.
        final message = tester.getRect(find.textContaining(sent).last);
        expect(message.top, greaterThanOrEqualTo(0));
        expect(
          message.bottom,
          lessThanOrEqualTo(tester.getRect(composer).top + 1),
        );

        // Let the demo cancel its timers.
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester, 5);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
