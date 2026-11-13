import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';
import 'src/ink_centering.dart';
import 'src/test_icons.dart';

const _width = 400.0;

Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  CoilThemeData theme = CoilThemeData.light,
  TextDirection direction = TextDirection.ltr,
  bool reducedMotion = false,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  debugShowCheckedModeBanner: false,
  builder: (context, navigator) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: Directionality(
      textDirection: direction,
      child: CoilTheme(
        data: theme.copyWith(tier: tier),
        child: _Content(content: child, child: navigator!),
      ),
    ),
  ),
  // The route is built once, so the content comes from above the navigator
  // and a new pumpWidget replaces it.
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _width,
        child: context.dependOnInheritedWidgetOfExactType<_Content>()!.content,
      ),
    ),
  ),
);

class _Content extends InheritedWidget {
  const _Content({required this.content, required super.child});

  final Widget content;

  @override
  bool updateShouldNotify(_Content oldWidget) => content != oldWidget.content;
}

class _Calls {
  final copied = <int>[];
  final retried = <int>[];
}

List<CoilChatMessageAction> _actions(_Calls calls) => [
  CoilChatMessageAction(
    label: 'Copy',
    icon: const TestIcon(TestGlyph.plus),
    onPressed: () => calls.copied.add(1),
  ),
  CoilChatMessageAction(
    label: 'Retry',
    icon: const TestIcon(TestGlyph.arrowRight),
    onPressed: () => calls.retried.add(1),
  ),
];

Widget _thumb() => Builder(
  builder: (context) => SizedBox.square(
    dimension: 80,
    child: ColoredBox(color: CoilTheme.of(context).colors.muted),
  ),
);

Widget _transcript({CoilChatMessageEntrance entrance = .none}) => Column(
  mainAxisSize: MainAxisSize.min,
  spacing: 12,
  children: [
    CoilChatMessage(
      sender: CoilChatSender.user,
      entrance: entrance,
      time: '10:42',
      attachments: [_thumb(), _thumb()],
      actions: _actions(_Calls()),
      child: const Text('Can you summarize the design doc?'),
    ),
    CoilChatMessage(
      sender: CoilChatSender.assistant,
      entrance: entrance,
      time: '10:43',
      actions: _actions(_Calls()),
      child: const Text(
        'Coil is a Flutter design system on Motor springs. Hover is never '
        'colored, and nothing stays lit where a finger lifted.',
      ),
    ),
  ],
);

/// The meta row's opacity: what the user sees of the actions.
double _metaOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(of: find.byType(CoilButton), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

void main() {
  matrixGoldenTest(
    'chat_message',
    (context) => SizedBox(width: 320, child: _transcript()),
    surface: const Size(2000, 2900),
  );

  testWidgets('state sheet: rest, hover, keyboard focus, compact', (
    tester,
  ) async {
    Widget cell(String label, Widget child) => Builder(
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            label,
            style: const CoilTypography().style(
              CoilMetrics.pointer.caption,
              color: CoilTheme.of(context).colors.mutedForeground,
            ),
          ),
          SizedBox(width: 260, child: child),
        ],
      ),
    );
    Widget user({Key? key, CoilSize? size}) => CoilChatMessage(
      key: key,
      sender: CoilChatSender.user,
      entrance: .none,
      size: size,
      time: '10:42',
      actions: _actions(_Calls()),
      child: const Text('Ship it on Friday?'),
    );
    final sheet = await pumpSheet(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tier in CoilTier.values)
            ThemedPair(
              title: 'CoilChatMessage · ${tier.name}',
              tier: tier,
              builder: (context) {
                final light =
                    CoilTheme.of(context).brightness == Brightness.light;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 24,
                  children: [
                    cell('rest', user()),
                    cell(
                      'hover',
                      user(
                        key: light && tier == CoilTier.pointer
                            ? const ValueKey('hover')
                            : null,
                      ),
                    ),
                    cell(
                      'compact',
                      user(size: CoilSize.compact),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      surface: const Size(1800, 760),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('hover'))));
    await settle(tester);
    await expectSheetGolden(tester, sheet, 'goldens/chat_message.png');
  });

  inkCenteringTests({
    'chat_message/user': (ink) => CoilChatMessage(
      sender: CoilChatSender.user,
      entrance: .none,
      child: InkLabel(ink, const Text('HEH')),
    ),
  });

  testWidgets('each message is a container labeled with sender and time', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_transcript()));
    expect(find.bySemanticsLabel('You, 10:42'), findsOneWidget);
    expect(find.bySemanticsLabel('Assistant, 10:43'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('user bubbles sit at the end, at most 80 % wide', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        _app(
          CoilChatMessage(
            sender: CoilChatSender.user,
            entrance: .none,
            child: Text('word ' * 60),
          ),
          direction: direction,
        ),
      );
      final text = tester.getRect(find.byType(Text));
      expect(text.width, lessThanOrEqualTo(_width * 0.8));
      final ltr = direction == TextDirection.ltr;
      // The text's end edge sits a bubble padding (14) from the row's end.
      expect(ltr ? _width - text.right : text.left, 14);
    }

    await tester.pumpWidget(
      _app(
        CoilChatMessage(
          sender: CoilChatSender.assistant,
          entrance: .none,
          child: Text('word ' * 60),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(Text)).width,
      greaterThan(_width * 0.8),
      reason: 'assistant text takes the full width',
    );
  });

  group('meta row', () {
    Widget message(_Calls calls) => CoilChatMessage(
      sender: CoilChatSender.user,
      entrance: .none,
      time: '10:42',
      actions: _actions(calls),
      child: const Text('Hello'),
    );

    testWidgets('pointer: shows on hover; a touch reveals nothing', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(_app(message(calls)));
      expect(_metaOpacity(tester), 0);

      // A finger can't hover: the actions stay hidden and untappable.
      await tester.tap(find.text('Hello'));
      await tester.tapAt(tester.getCenter(find.byType(CoilButton).first));
      await tester.pumpAndSettle();
      expect(_metaOpacity(tester), 0);
      expect(calls.copied, isEmpty);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.text('Hello')));
      await tester.pumpAndSettle();
      expect(_metaOpacity(tester), 1);
      await mouse.moveTo(tester.getCenter(find.byType(CoilButton).first));
      await mouse.down(tester.getCenter(find.byType(CoilButton).first));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(calls.copied, [1]);

      await mouse.moveTo(const Offset(_width - 1, 590));
      await tester.pumpAndSettle();
      expect(_metaOpacity(tester), 0, reason: 'hides when the mouse leaves');
    });

    testWidgets('pointer: shows while an action has keyboard focus', (
      tester,
    ) async {
      await tester.pumpWidget(_app(message(_Calls())));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_metaOpacity(tester), 1);
    });

    testWidgets('touch: always shows', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_app(message(calls), tier: CoilTier.touch));
      expect(_metaOpacity(tester), 1);
      await tester.tap(find.byType(CoilButton).last);
      expect(calls.retried, [1]);
    });

    testWidgets('shows while a screen reader runs', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_app(message(_Calls())));
      expect(_metaOpacity(tester), 1);
    });
  });

  testWidgets('a long press with a finger opens the actions as a menu', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final calls = _Calls();
    await tester.pumpWidget(
      _app(
        CoilChatMessage(
          sender: CoilChatSender.user,
          entrance: .none,
          actions: _actions(calls),
          child: const Text('Hello'),
        ),
        tier: CoilTier.touch,
      ),
    );
    await tester.longPress(find.text('Hello'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing, reason: 'a mouse long press');

    await tester.longPress(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(
      find.semantics.byPredicate(
        (node) => node.getSemanticsData().role == SemanticsRole.menu,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls.retried, [1]);
    expect(find.text('Retry'), findsNothing, reason: 'picking closes it');
    semantics.dispose();
  });

  testWidgets('labels name the sender', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const CoilChatMessage(
          sender: CoilChatSender.assistant,
          entrance: .none,
          time: '10:43',
          labels: CoilChatMessageLabels(assistant: 'Assistant IA'),
          child: Text('Bonjour'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Assistant IA, 10:43'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the long-press menu works from the keyboard', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _app(
        CoilChatMessage(
          sender: CoilChatSender.user,
          entrance: .none,
          actions: _actions(calls),
          child: const Text('Hello'),
        ),
        tier: CoilTier.touch,
      ),
    );
    await tester.longPress(find.text('Hello'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls.retried, [1]);
    expect(find.text('Retry'), findsNothing, reason: 'picking closes it');

    await tester.longPress(find.text('Hello'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing, reason: 'Escape closes it');
  });

  group('entrance', () {
    Widget message({CoilChatMessageEntrance entrance = .animated}) =>
        CoilChatMessage(
          sender: CoilChatSender.user,
          entrance: entrance,
          child: const Text('Hi'),
        );
    final box = find.byType(CoilChatMessage);
    double opacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find.descendant(of: box, matching: find.byType(Opacity)).first,
        )
        .opacity;

    testWidgets('fades in and opens its height on standard', (tester) async {
      await tester.pumpWidget(_app(message(entrance: .none)));
      final full = tester.getSize(box).height;
      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pumpWidget(_app(message()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getSize(box).height, inExclusiveRange(0, full));
      expect(opacity(tester), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(tester.getSize(box).height, full);
      expect(opacity(tester), 1);
    });

    testWidgets('reduced motion keeps only the fade', (tester) async {
      await tester.pumpWidget(_app(message(), reducedMotion: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final rest = tester.getSize(box).height;
      await tester.pumpAndSettle();
      expect(tester.getSize(box).height, rest, reason: 'no height spring');
      expect(opacity(tester), 1);
    });

    testWidgets('motions: overrides one track', (tester) async {
      await tester.pumpWidget(
        _app(
          CoilChatMessage(
            sender: CoilChatSender.user,
            motions: {
              CoilChatMessageTrack.opacity: CoilThemeData.light.motion.gentle,
            },
            child: const Text('Hi'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacity(tester), lessThan(1), reason: 'opacity is now gentle');
    });

    testWidgets('a motion override applies', (tester) async {
      final slow = CoilThemeData.light.motion.copyWith(
        fade: CoilThemeData.light.motion.gentle,
      );
      await tester.pumpWidget(
        _app(
          CoilChatMessage(
            sender: CoilChatSender.user,
            motion: slow,
            child: const Text('Hi'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacity(tester), lessThan(1), reason: 'fade is now gentle');
    });
  });

  testWidgets('style: fallback < theme < instance', (tester) async {
    Widget message({CoilChatMessageStyle? style}) => CoilChatMessage(
      sender: CoilChatSender.user,
      entrance: .none,
      style: style,
      child: Text('word ' * 60),
    );
    final themed = CoilThemeData.light.withComponentStyle(
      const CoilChatMessageStyle(maxWidthFactor: 0.5),
    );
    await tester.pumpWidget(_app(message(), theme: themed));
    expect(tester.getSize(find.byType(Text)).width, lessThanOrEqualTo(200));
    await tester.pumpWidget(
      _app(
        message(style: const CoilChatMessageStyle(maxWidthFactor: 1)),
        theme: themed,
      ),
    );
    expect(tester.getSize(find.byType(Text)).width, greaterThan(300));
  });
}
