import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

/// How often the bubble was built.
int _bubbleBuilds = 0;

/// Places its child at [x], moving it in layout only.
class _At extends SingleChildLayoutDelegate {
  _At(this.x) : super(relayout: x);

  final ValueNotifier<double> x;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(x.value, (size.height - childSize.height) / 2);

  @override
  bool shouldRelayout(_At oldDelegate) => oldDelegate.x != x;
}

/// A thumb with a controlled tooltip, laid out at [x].
Widget _thumb({
  required Animation<double> presence,
  required ValueNotifier<double> x,
}) => testApp(
  tier: CoilTier.pointer,
  home: CustomSingleChildLayout(
    delegate: _At(x),
    child: CoilTooltipAnchor.controlled(
      presence: presence,
      content: const Text('42'),
      bubble: (context, presence, content) {
        _bubbleBuilds++;
        return FadeTransition(
          opacity: presence,
          child: CoilTooltipBubble(child: content),
        );
      },
      child: Semantics(
        label: 'Thumb',
        child: const SizedBox.square(key: ValueKey('thumb'), dimension: 20),
      ),
    ),
  ),
);

Finder get _bubble => find.byType(CoilTooltipBubble);

void main() {
  late AnimationController presence;
  late ValueNotifier<double> x;

  setUp(() {
    presence = AnimationController(vsync: const TestVSync());
    x = ValueNotifier(100);
    _bubbleBuilds = 0;
  });

  tearDown(() {
    presence.dispose();
    x.dispose();
  });

  testWidgets('a controlled bubble shows while its presence is above 0', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_thumb(presence: presence, x: x));
    expect(_bubble, findsNothing);

    presence.value = 0.5;
    await tester.pump();
    expect(_bubble, findsOneWidget);
    presence.value = 1;
    await tester.pump();
    final thumb = tester.getRect(find.byKey(const ValueKey('thumb')));
    final bubble = tester.getRect(_bubble);
    expect(bubble.center.dx, closeTo(thumb.center.dx, 0.01));
    expect(thumb.top - bubble.bottom, CoilTooltipAnchor.gap);

    presence.value = 0;
    await tester.pump();
    expect(_bubble, findsNothing);
  });

  testWidgets('a controlled bubble has no triggers of its own', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_thumb(presence: presence, x: x));
    final thumb = find.byKey(const ValueKey('thumb'));

    // Hovering doesn't open it.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(thumb));
    await tester.pump(CoilTooltipAnchor.hoverDelay * 2);
    expect(_bubble, findsNothing);

    // A press doesn't close it: the component shows it while pressed.
    presence.value = 1;
    await tester.pump();
    final finger = await tester.startGesture(tester.getCenter(thumb));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_bubble, findsOneWidget);
    await finger.up();
  });

  testWidgets('it follows a moving child every frame without rebuilding', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    presence.value = 1;
    await tester.pumpWidget(_thumb(presence: presence, x: x));
    await tester.pump();
    final builds = _bubbleBuilds;

    for (final to in [140.0, 141.5, 200.25]) {
      x.value = to;
      await tester.pump();
      final thumb = tester.getRect(find.byKey(const ValueKey('thumb')));
      expect(tester.getRect(_bubble).center.dx, closeTo(thumb.center.dx, 0.01));
    }
    expect(_bubbleBuilds, builds);
  });

  testWidgets('it adds nothing to semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    useScreen(tester, TestScreen.desktop);
    presence.value = 1;
    await tester.pumpWidget(_thumb(presence: presence, x: x));
    await tester.pump();
    expect(find.text('42'), findsOneWidget);
    expect(find.bySemanticsLabel('42'), findsNothing);
    final thumb = tester.getSemantics(find.bySemanticsLabel('Thumb'));
    expect(thumb.getSemanticsData().tooltip, isEmpty);
    semantics.dispose();
  });

  testWidgets('an open tooltip is announced once', (tester) async {
    final semantics = tester.ensureSemantics();
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: Center(
          child: CoilTooltip(
            message: const Text('Bold'),
            child: CoilButton.icon(
              onPressed: () {},
              semanticLabel: 'Bold button',
              icon: const SizedBox.square(dimension: 16),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(CoilButton)));
    await tester.pump(CoilTooltipAnchor.hoverDelay);
    await tester.pumpAndSettle();
    expect(find.text('Bold'), findsOneWidget);
    // The button carries it as its tooltip; the bubble isn't a node of its
    // own.
    expect(find.bySemanticsLabel('Bold'), findsNothing);
    final button = tester.getSemantics(find.bySemanticsLabel('Bold button'));
    expect(button.getSemanticsData().tooltip, 'Bold');
    semantics.dispose();
  });
}
