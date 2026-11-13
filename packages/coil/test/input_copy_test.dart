import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/golden_sheet.dart';
import 'src/test_icons.dart';

Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.touch,
  bool reduceMotion = false,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: KeyedSubtree(
      key: UniqueKey(),
      child: withOverlay(
        CoilTheme(
          data: CoilThemeData.light.copyWith(tier: tier),
          child: Center(child: SizedBox(width: 300, child: child)),
        ),
      ),
    ),
  ),
);

void main() {
  late List<String> clipboard;
  late List<String> announcements;
  var failClipboard = false;

  setUp(() {
    clipboard = [];
    announcements = [];
    failClipboard = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          if (failClipboard) {
            throw PlatformException(code: 'denied');
          }
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      })
      ..setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
        message,
      ) async {
        final map = message! as Map;
        if (map['type'] == 'announce') {
          announcements.add((map['data'] as Map)['message'] as String);
        }
        return null;
      });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(SystemChannels.platform, null)
      ..setMockDecodedMessageHandler<Object?>(
        SystemChannels.accessibility,
        null,
      );
  });

  testWidgets('a tap copies and shows "Copied" inline on touch, then resets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var copied = 0;
    await tester.pumpWidget(
      _app(
        CoilInputCopy(
          value: 'sk-1234',
          label: 'API key',
          icon: const TestIcon(TestGlyph.plus),
          variant: CoilInputCopyVariant.button,
          onCopied: () => copied++,
        ),
      ),
    );
    final row = find.byType(CoilInteraction);
    final before = tester.getSize(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(clipboard, ['sk-1234']);
    expect(copied, 1);
    expect(announcements, ['Copied']);
    // The label reads "Copied" in the row itself, and nothing shifts.
    expect(tester.getSemantics(row).label, 'Copied');
    expect(
      find.descendant(of: row, matching: find.text('Copied')),
      findsWidgets,
    );
    expect(tester.getSize(row), before);

    await tester.pump(CoilInputCopy.resetDelay);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(row).label, 'Copy API key');
    semantics.dispose();
  });

  testWidgets('the icon variant swaps to a check, labelled "Copied"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const CoilInputCopy(
          value: 'invite.example/abc',
          label: 'Invite link',
          icon: TestIcon(TestGlyph.plus),
        ),
      ),
    );
    final row = find.byType(CoilInteraction);
    expect(
      tester.getSemantics(row),
      isSemantics(
        label: 'Copy Invite link',
        value: 'invite.example/abc',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
      ),
    );
    expect(find.byType(TestIcon), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(clipboard, ['invite.example/abc']);
    expect(find.byType(TestIcon), findsNothing);
    expect(tester.getSemantics(row).label, 'Copied');
    semantics.dispose();
  });

  testWidgets('a refused copy says so and calls nothing', (tester) async {
    failClipboard = true;
    final semantics = tester.ensureSemantics();
    var copied = 0;
    await tester.pumpWidget(
      _app(
        CoilInputCopy(
          value: 'secret',
          variant: CoilInputCopyVariant.button,
          onCopied: () => copied++,
        ),
      ),
    );
    await tester.tap(find.byType(CoilInputCopy));
    await tester.pumpAndSettle();
    expect(copied, 0);
    expect(announcements, ['Copy failed']);
    expect(
      tester.getSemantics(find.byType(CoilInteraction)).label,
      'Copy failed',
    );
    semantics.dispose();
  });

  testWidgets('Enter and Space copy', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _app(CoilInputCopy(value: 'abc', focusNode: focus)),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(clipboard, ['abc', 'abc']);
  });

  testWidgets('disabled does nothing', (tester) async {
    await tester.pumpWidget(
      _app(const CoilInputCopy(value: 'abc', enabled: false)),
    );
    await tester.tap(find.byType(CoilInputCopy), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(clipboard, isEmpty);
  });

  testWidgets('reduced motion makes the swap instant; color still fades', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const CoilInputCopy(value: 'abc', icon: TestIcon(TestGlyph.plus)),
        reduceMotion: true,
      ),
    );
    await tester.tap(find.byType(CoilInputCopy));
    // The clipboard answers asynchronously; then the swap starts.
    await tester.pump();
    expect(clipboard, ['abc']);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    // The leaving icon is gone after a frame.
    expect(find.byType(TestIcon), findsNothing);
  });

  testWidgets('a per-instance motion slows the swap', (tester) async {
    Future<bool> iconAfter300ms(CoilMotion? motion) async {
      await tester.pumpWidget(
        _app(
          CoilInputCopy(
            value: 'abc',
            icon: const TestIcon(TestGlyph.plus),
            motion: motion,
          ),
        ),
      );
      await tester.tap(find.byType(CoilInputCopy));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 15));
      }
      final shown = find.byType(TestIcon).evaluate().isNotEmpty;
      await tester.pump(CoilInputCopy.resetDelay);
      await tester.pumpAndSettle();
      return shown;
    }

    expect(await iconAfter300ms(null), isFalse);
    expect(
      await iconAfter300ms(
        CoilThemeData.light.motion.copyWith(
          quickExit: const CupertinoMotion(duration: Duration(seconds: 1)),
        ),
      ),
      isTrue,
    );
  });

  testWidgets('input copy sheet', (tester) async {
    Widget rows(BuildContext context) => const SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          CoilInputCopy(
            value: 'sk-live-0123456789abcdef0123456789',
            label: 'API key',
            icon: TestIcon(TestGlyph.plus),
          ),
          CoilInputCopy(
            value: 'https://coil.dev/invite/7f3a',
            variant: CoilInputCopyVariant.button,
            icon: TestIcon(TestGlyph.plus),
          ),
          CoilInputCopy(
            value: 'npm i coil',
            label: 'Install',
            align: CoilInputCopyAlign.start,
            icon: TestIcon(TestGlyph.plus),
          ),
          CoilInputCopy(
            value: 'disabled',
            enabled: false,
            icon: TestIcon(TestGlyph.plus),
          ),
        ],
      ),
    );
    final finder = await pumpSheet(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tier in CoilTier.values)
            ThemedPair(
              title: 'InputCopy · ${tier.name}',
              tier: tier,
              builder: rows,
            ),
        ],
      ),
    );
    // Copy the second row so the sheet shows a result too.
    await tester.tap(find.text('https://coil.dev/invite/7f3a').first);
    await tester.pumpAndSettle();
    await expectSheetGolden(tester, finder, 'goldens/input_copy.png');
    await tester.pump(CoilInputCopy.resetDelay);
  });
}
