import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

const _count = 12;

class _Host extends StatefulWidget {
  const _Host({
    this.width = 300,
    this.initial = 0,
    this.textDirection = TextDirection.ltr,
    this.tier = CoilTier.pointer,
  });

  final double width;
  final int initial;
  final TextDirection textDirection;
  final CoilTier tier;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int tab = widget.initial;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => Directionality(
      textDirection: widget.textDirection,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          // Pretend to be on [platform] for the scroll physics.
        ),
        child: CoilTheme(
          data: CoilThemeData.light.copyWith(tier: widget.tier),
          child: FocusScope(
            autofocus: true,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: widget.width,
                child: CoilTabs(
                  key: const ValueKey('tabs'),
                  tabs: [
                    for (var i = 0; i < _count; i++)
                      CoilTab(value: i, label: 'Tab number $i'),
                  ],
                  value: tab,
                  onChanged: (v) => setState(() => tab = v),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

ScrollPosition _position(WidgetTester tester) =>
    Scrollable.of(tester.element(find.text('Tab number 0').first)).position;

void main() {
  testWidgets('loose constraints: the strip hugs the tabs', (tester) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => CoilTheme(
          data: CoilThemeData.light,
          child: Align(
            alignment: Alignment.topLeft,
            child: CoilTabs(
              key: const ValueKey('tabs'),
              tabs: const [
                CoilTab(value: 0, label: 'One'),
                CoilTab(value: 1, label: 'Two'),
              ],
              value: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('tabs'))).width,
      lessThan(300),
    );
  });

  testWidgets('tabs that fit hug their content and do not scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(3000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const _Host(width: 2000));
    await tester.pump();
    expect(_position(tester).maxScrollExtent, 0);
  });

  testWidgets('many tabs in a narrow width scroll horizontally', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('tabs'))).width, 300);
    expect(_position(tester).maxScrollExtent, greaterThan(500));
    await tester.drag(find.text('Tab number 1').first, const Offset(-200, 0));
    await tester.pump();
    expect(_position(tester).pixels, greaterThan(100));
  });

  testWidgets('an initially selected far tab starts in view', (tester) async {
    await tester.pumpWidget(const _Host(initial: 10));
    await tester.pump();
    await tester.pump();
    final rect = tester.getRect(find.text('Tab number 10').first);
    expect(rect.right, lessThanOrEqualTo(300));
    expect(rect.left, greaterThanOrEqualTo(0));
  });

  testWidgets('selecting a tab scrolls it into view on a spring', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    await tester.pump();
    await tester.tap(find.text('Tab number 2').first);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    // Select a far tab with the keyboard: End then Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final start = _position(tester).pixels;
    expect(start, greaterThan(0), reason: 'focus scrolls the tab into view');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    final rect = tester.getRect(find.text('Tab number 11').first);
    expect(rect.right, lessThanOrEqualTo(300));
    expect(
      _position(tester).pixels,
      closeTo(_position(tester).maxScrollExtent, 1),
    );
  });

  testWidgets('keyboard roving still moves focus and selects', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      (tester.state(find.byType(_Host)) as _HostState).tab,
      1,
    );
  });

  testWidgets(
    'touch scroll physics follow the platform',
    (tester) async {
      await tester.pumpWidget(const _Host(tier: CoilTier.touch));
      await tester.pump();
      final g = await tester.startGesture(
        tester.getCenter(find.text('Tab number 1').first),
      );
      await g.moveBy(const Offset(40, 0));
      await tester.pump();
      await g.moveBy(const Offset(40, 0));
      await tester.pump();
      final overscrolls = _position(tester).pixels < 0;
      expect(overscrolls, defaultTargetPlatform == TargetPlatform.iOS);
      await g.up();
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('touch: no hover pill after a tap on a scrolled strip', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(tier: CoilTier.touch));
    await tester.pump();
    await tester.tap(find.text('Tab number 2').first);
    await settle(tester);
    final region = CoilHoverRegion.maybeOf(
      tester.element(find.text('Tab number 3').first),
    );
    expect(region?.activeIndex, isNull);
  });

  testWidgets('RTL strip scrolls and reveals', (tester) async {
    await tester.pumpWidget(
      const _Host(initial: 9, textDirection: TextDirection.rtl),
    );
    await tester.pump();
    await tester.pump();
    final rect = tester.getRect(find.text('Tab number 9').first);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(300));
  });

  testWidgets('hover follows the pointer on a scrolled strip', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pump();
    await tester.drag(find.text('Tab number 1').first, const Offset(-300, 0));
    await settle(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    final finder = find.text('Tab number 4').first;
    await mouse.moveTo(tester.getCenter(finder));
    await settle(tester);
    final region = CoilHoverRegion.maybeOf(tester.element(finder));
    expect(region?.activeIndex, isNotNull);
  });
}
