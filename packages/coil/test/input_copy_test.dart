import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
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
  late List<String> haptics;
  var failClipboard = false;

  setUp(() {
    clipboard = [];
    announcements = [];
    haptics = [];
    failClipboard = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
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
          semanticLabel: 'Copy API key',
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

  testWidgets('in a field: the label is read with it and a label tap copies', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const CoilField(
          label: Text('Invite link'),
          child: CoilInputCopy(
            value: 'invite.example/abc',
            icon: TestIcon(TestGlyph.plus),
          ),
        ),
      ),
    );
    final row = find.byType(CoilInteraction);
    final node = tester.getSemantics(row).getSemanticsData();
    expect(node.label, contains('Invite link'));
    expect(node.label, contains('Copy'));
    expect(node.value, 'invite.example/abc');
    expect(node.flagsCollection.isButton, isTrue);
    expect(find.byType(TestIcon), findsOneWidget);

    await tester.tap(find.text('Invite link'));
    await tester.pumpAndSettle();
    expect(clipboard, ['invite.example/abc']);
    // The icon became the check.
    expect(find.byType(TestIcon), findsNothing);
    expect(
      tester.getSemantics(row).getSemanticsData().label,
      contains('Copied'),
    );
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

  testWidgets('reduced motion makes the swap instant', (
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

  testWidgets(
    'a copy plays a selection click on phones and nothing on desktop',
    (tester) async {
      await tester.pumpWidget(_app(const CoilInputCopy(value: 'abc')));
      await tester.tap(find.byType(CoilInputCopy));
      await tester.pumpAndSettle();
      final phone = {
        TargetPlatform.iOS,
        TargetPlatform.android,
      }.contains(debugDefaultTargetPlatformOverride);
      expect(
        haptics,
        phone ? ['HapticFeedbackType.selectionClick'] : isEmpty,
      );
      await tester.pump(CoilInputCopy.resetDelay);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('a theme motion change applies to the next swap', (
    tester,
  ) async {
    final slow = CoilThemeData.light.motion.copyWith(
      quickExit: const CupertinoMotion(duration: Duration(seconds: 1)),
    );
    final theme = ValueNotifier(CoilThemeData.light);
    addTearDown(theme.dispose);
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => withOverlay(
          ValueListenableBuilder(
            valueListenable: theme,
            builder: (context, data, _) => CoilTheme(
              data: data,
              child: const Center(
                child: SizedBox(
                  width: 300,
                  child: CoilInputCopy(
                    value: 'abc',
                    icon: TestIcon(TestGlyph.plus),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Future<bool> iconAfter300ms() async {
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

    expect(await iconAfter300ms(), isFalse);
    theme.value = CoilThemeData.light.copyWith(motion: slow);
    await tester.pump();
    expect(await iconAfter300ms(), isTrue);
  });

  group('copy feedback', () {
    final check = find.byWidgetPredicate(
      (w) => w is CoilDrawnGlyph && w.glyph == CoilGlyph.check,
    );
    final copyGlyph = find.byWidgetPredicate(
      (w) => w is CoilDrawnGlyph && w.glyph == CoilGlyph.copy,
    );

    /// How present the check is in the cross-fade, 0 to 1.
    double presence(WidgetTester tester) => tester
        .widget<CoilBlurFade>(
          find.ancestor(of: check, matching: find.byType(CoilBlurFade)).first,
        )
        .presence
        .value;

    double drawn(WidgetTester tester) =>
        tester.widget<CoilDrawnGlyph>(check).progress;

    testWidgets('with no icon, the action still shows a copy glyph', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const CoilInputCopy(value: 'abc')));
      expect(copyGlyph, findsOneWidget);
      expect(tester.getSize(copyGlyph).width, greaterThan(0));
    });

    testWidgets('spam: the check animates in once and each tap restarts the '
        'timer', (tester) async {
      var copied = 0;
      await tester.pumpWidget(
        _app(CoilInputCopy(value: 'abc', onCopied: () => copied++)),
      );
      await tester.tap(find.byType(CoilInputCopy));
      await tester.pumpAndSettle();
      expect(check, findsOneWidget);
      final shown = tester.element(check);
      expect(drawn(tester), 1);

      // Nine more taps, 150 ms apart: 1.35 s, well past where a single
      // copy would have started leaving at the end.
      for (var i = 0; i < 9; i++) {
        await tester.tap(find.byType(CoilInputCopy));
        await tester.pump();
        for (var f = 0; f < 10; f++) {
          await tester.pump(const Duration(milliseconds: 15));
          expect(check, findsOneWidget, reason: 'no second check enters');
          expect(
            tester.element(check),
            same(shown),
            reason: 'the check is never rebuilt from scratch',
          );
          expect(drawn(tester), 1, reason: 'the check never redraws');
          expect(presence(tester), closeTo(1, 0.001));
          expect(copyGlyph, findsNothing, reason: 'the icon never comes back');
        }
      }
      expect(clipboard, hasLength(10));
      expect(copied, 10);
      expect(announcements, ['Copied'], reason: 'announced once, on entry');

      // The 2 s run from the last tap.
      await tester.pump(
        CoilInputCopy.resetDelay - const Duration(milliseconds: 160),
      );
      expect(copyGlyph, findsNothing);
      expect(presence(tester), closeTo(1, 0.001));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(check, findsNothing);
      expect(copyGlyph, findsOneWidget);
    });

    testWidgets('a copy while the check leaves turns it around smoothly', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const CoilInputCopy(value: 'abc')));
      await tester.tap(find.byType(CoilInputCopy));
      await tester.pumpAndSettle();
      final shown = tester.element(check);

      await tester.pump(CoilInputCopy.resetDelay);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final leaving = presence(tester);
      expect(leaving, inExclusiveRange(0.05, 0.95), reason: 'mid-exit');
      expect(copyGlyph, findsOneWidget, reason: 'the icon is entering');

      await tester.tap(find.byType(CoilInputCopy));
      await tester.pump();
      var last = presence(tester);
      expect(last, closeTo(leaving, 0.1), reason: 'no snap');
      for (var f = 0; f < 30; f++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.element(check), same(shown), reason: 'same check');
        expect(drawn(tester), 1, reason: 'it stays drawn');
        final now = presence(tester);
        // A `quick` spring covers a third of the way in a frame; a restart
        // would drop to 0 or jump to 1.
        expect(now, greaterThan(leaving - 0.05), reason: 'no restart');
        expect(now - last, lessThan(0.4), reason: 'no jump');
        last = now;
      }
      await tester.pumpAndSettle();
      expect(presence(tester), closeTo(1, 0.001));
      expect(copyGlyph, findsNothing);
      await tester.pump(CoilInputCopy.resetDelay);
      await tester.pumpAndSettle();
    });

    testWidgets('a controller drives a copy icon anywhere', (tester) async {
      final controller = CoilCopyController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => CoilButton.icon(
              semanticLabel: 'Copy',
              onPressed: () => controller.copy('hello', context: context),
              icon: CoilCopyGlyph.listening(controller: controller),
            ),
          ),
        ),
      );
      expect(copyGlyph, findsOneWidget);
      await tester.tap(find.byType(CoilButton));
      await tester.pumpAndSettle();
      expect(clipboard, ['hello']);
      expect(announcements, ['Copied']);
      expect(check, findsOneWidget);
      expect(controller.value, CoilCopyStatus.copied);
      await tester.pump(CoilCopyController.defaultResetDelay);
      await tester.pumpAndSettle();
      expect(controller.value, CoilCopyStatus.idle);
      expect(copyGlyph, findsOneWidget);
    });
  });

  testWidgets('any clipboard failure reports a failed copy', (tester) async {
    final controller = CoilCopyController();
    addTearDown(controller.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (c) {
            context = c;
            return CoilCopyGlyph.listening(controller: controller);
          },
        ),
      ),
    );
    // A reply the codec can't read: a FormatException, not a
    // PlatformException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          SystemChannels.platform.name,
          (message) async => ByteData(0),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(SystemChannels.platform.name, null),
    );
    final status = await controller.copy('x', context: context);
    expect(status, CoilCopyStatus.failed);
    expect(controller.value, CoilCopyStatus.failed);
    await tester.pumpAndSettle();
    expect(announcements, ['Copy failed']);
    expect(
      find.byWidgetPredicate(
        (w) => w is CoilDrawnGlyph && w.glyph == CoilGlyph.cross,
      ),
      findsOneWidget,
    );
    await tester.pump(CoilCopyController.defaultResetDelay);
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion makes copy swap overrides instant', (
    tester,
  ) async {
    final controller = CoilCopyController();
    addTearDown(controller.dispose);
    const slow = CupertinoMotion(duration: Duration(seconds: 3));
    await tester.pumpWidget(
      _app(
        CoilCopyGlyph.listening(
          controller: controller,
          motions: {CoilCopyTrack.swap: slow, CoilCopyTrack.draw: slow},
        ),
        reduceMotion: true,
      ),
    );
    controller.show(CoilCopyStatus.copied);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final copy = find.byWidgetPredicate(
      (w) => w is CoilDrawnGlyph && w.glyph == CoilGlyph.copy,
    );
    expect(copy, findsNothing, reason: 'swapped at once');
    // Drawing the check is a fade, which reduced motion keeps.
    expect(
      tester
          .widget<CoilDrawnGlyph>(
            find.byWidgetPredicate(
              (w) => w is CoilDrawnGlyph && w.glyph == CoilGlyph.check,
            ),
          )
          .progress,
      lessThan(0.9),
    );
    await tester.pump(CoilCopyController.defaultResetDelay);
    await tester.pumpAndSettle();
  });

  testWidgets('input copy sheet', (tester) async {
    Widget rows(BuildContext context) => const SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          CoilField(
            label: Text('API key'),
            child: CoilInputCopy(
              value: 'sk-live-0123456789abcdef0123456789',
              icon: TestIcon(TestGlyph.plus),
            ),
          ),
          CoilInputCopy(
            value: 'https://coil.dev/invite/7f3a',
            variant: CoilInputCopyVariant.button,
            icon: TestIcon(TestGlyph.plus),
          ),
          CoilInputCopy(
            value: 'npm i coil',
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
