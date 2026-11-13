import 'package:coil/carousel_dots.dart';
import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/coil_pattern.dart';
import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';

/// Applies `onChanged`, with a button after the dots so Tab can leave them.
class _Host extends StatefulWidget {
  const _Host({
    this.tier = CoilTier.pointer,
    this.direction = TextDirection.ltr,
    this.enabled = true,
    this.theme = CoilThemeData.light,
    this.motion,
    this.style,
    this.reducedMotion = false,
  });

  final CoilTier tier;
  final TextDirection direction;
  final bool enabled;
  final CoilThemeData theme;
  final CoilMotion? motion;
  final CoilCarouselDotsStyle? style;
  final bool reducedMotion;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int value = 1;
  final changes = <int>[];

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    debugShowCheckedModeBanner: false,
    builder: (context, navigator) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: widget.reducedMotion),
      child: Directionality(
        textDirection: widget.direction,
        child: CoilTheme(
          data: widget.theme.copyWith(tier: widget.tier),
          child: navigator!,
        ),
      ),
    ),
    onGenerateRoute: (settings) => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(
              key: const ValueKey('target'),
              child: CoilCarouselDots(
                count: 5,
                value: value,
                motion: widget.motion,
                style: widget.style,
                onChanged: widget.enabled
                    ? (v) => setState(() {
                        changes.add(v);
                        value = v;
                      })
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            CoilButton(onPressed: () {}, child: const Text('After')),
          ],
        ),
      ),
    ),
  );
}

final _target = find.byKey(const ValueKey('target'));
final _dots = find.byType(CoilCarouselDots);

/// Each dot's painted box, in reading order.
List<Rect> _dotRects(WidgetTester tester) => tester
    .renderObjectList<RenderBox>(
      find.descendant(of: _dots, matching: find.byType(ClipRSuperellipse)),
    )
    .map((box) => box.localToGlobal(Offset.zero) & box.size)
    .toList();

_HostState _host(WidgetTester tester) => tester.state(find.byType(_Host));

int? _lit(WidgetTester tester) => CoilHoverRegion.maybeOf(
  tester.element(find.byType(CoilHoverItem).first),
)?.activeIndex;

void main() {
  matrixGoldenTest(
    'carousel_dots',
    (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        CoilCarouselDots(count: 6, value: 1, onChanged: (_) {}),
        CoilCarouselDots(
          count: 6,
          value: 3,
          progress: 0.5,
          onChanged: (_) {},
        ),
      ],
    ),
    surface: const Size(1600, 900),
  );

  testWidgets('state sheet: rest, hover, focus, progress, disabled', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget cell(String label, Widget dots) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Builder(
          builder: (context) => Text(
            label,
            style: const CoilTypography().style(
              CoilMetrics.pointer.caption,
              color: CoilTheme.of(context).colors.mutedForeground,
            ),
          ),
        ),
        dots,
      ],
    );
    final sheet = await pumpSheet(
      tester,
      ThemedPair(
        title: 'CoilCarouselDots',
        direction: Axis.vertical,
        builder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 32,
          children: [
            cell(
              'rest',
              CoilCarouselDots(count: 6, value: 1, onChanged: (_) {}),
            ),
            cell(
              'hover',
              KeyedSubtree(
                key: ValueKey('hover-${CoilTheme.of(context).brightness}'),
                child: CoilCarouselDots(count: 6, value: 1, onChanged: (_) {}),
              ),
            ),
            cell(
              'focus',
              CoilCarouselDots(
                count: 6,
                value: 1,
                onChanged: (_) {},
                focusNode: CoilTheme.of(context).brightness == Brightness.light
                    ? focus
                    : null,
              ),
            ),
            cell(
              'progress 0.3',
              CoilCarouselDots(
                count: 6,
                value: 2,
                progress: 0.3,
                onChanged: (_) {},
              ),
            ),
            cell(
              'disabled',
              const CoilCarouselDots(count: 6, value: 1, onChanged: null),
            ),
          ],
        ),
      ),
      surface: const Size(820, 360),
    );
    // Keyboard focus on the light focus cell.
    await tester.sendKeyEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    focus.requestFocus();
    // A mouse over the fourth dot of the light hover cell (tests have one
    // mouse, so the dark cell rests).
    final dots = find.descendant(
      of: find.byKey(ValueKey('hover-${Brightness.light}')),
      matching: find.byType(ClipRSuperellipse),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(dots.at(3)));
    await settle(tester);
    await expectSheetGolden(tester, sheet, 'goldens/carousel_dots.png');
  });

  for (final direction in TextDirection.values) {
    for (final tier in CoilTier.values) {
      testWidgets('is adjustable (${tier.name}, ${direction.name})', (
        tester,
      ) async {
        await tester.pumpWidget(_Host(tier: tier, direction: direction));
        await expectCoilPattern(tester, _target, CoilPattern.adjustable);
      });
    }
  }

  testWidgets('screen readers hear the slide position and can step it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const _Host());
    expect(
      tester.getSemantics(_dots),
      matchesSemantics(
        label: 'Slides',
        value: 'Slide 2 of 5',
        increasedValue: 'Slide 3 of 5',
        decreasedValue: 'Slide 1 of 5',
        isSlider: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        hasFocusAction: true,
      ),
    );
    tester.semantics.performAction(
      find.semantics.byLabel('Slides'),
      SemanticsAction.increase,
    );
    await tester.pumpAndSettle();
    expect(_host(tester).value, 2);
    semantics.dispose();
  });

  testWidgets('arrows follow the reading direction; Home and End jump', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(direction: TextDirection.rtl));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_host(tester).value, 2, reason: 'Left is forward in RTL');
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(_host(tester).value, 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_host(tester).value, 4, reason: 'no wrap past the last slide');
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(_host(tester).value, 0);
  });

  testWidgets('pointer: clicking a dot picks it; only a mouse lights it', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    final rects = _dotRects(tester);
    expect(tester.getSize(_dots).height, 18, reason: 'the 18 px targets');

    await tester.tap(find.byType(ClipRSuperellipse).at(3));
    await tester.pumpAndSettle();
    expect(_host(tester).value, 3);
    expect(_lit(tester), isNull, reason: 'a touch never leaves a highlight');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(rects[0].center);
    await tester.pump();
    expect(_lit(tester), 0, reason: 'the highlight is on the hovered dot');
    await mouse.moveTo(rects[4].center);
    await tester.pump();
    expect(_lit(tester), 4, reason: 'the highlight glides to the next dot');
  });

  testWidgets('touch: one 44 px strip; tap or drag along it to scrub', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(tier: CoilTier.touch));
    final strip = tester.getRect(_dots);
    expect(strip.height, 44);
    // A tap above a dot, outside its 18 px target, still lands.
    final dots = _dotRects(tester);
    await tester.tapAt(Offset(dots[3].center.dx, strip.top + 2));
    await tester.pumpAndSettle();
    expect(_host(tester).value, 3);

    _host(tester).changes.clear();
    final finger = await tester.startGesture(
      strip.centerRight - const Offset(4, 0),
    );
    await finger.moveTo(
      Offset(_dotRects(tester)[1].center.dx, strip.center.dy),
    );
    await finger.moveTo(strip.centerLeft + const Offset(2, 0));
    await finger.up();
    await tester.pumpAndSettle();
    expect(_host(tester).value, 0, reason: 'scrubbed to the first dot');
    expect(
      _host(tester).changes,
      containsAllInOrder([1, 0]),
      reason: 'passing over dots reports each one',
    );
  });

  testWidgets('disabled: no tab stop and no taps', (tester) async {
    await tester.pumpWidget(const _Host(enabled: false));
    await tester.tap(find.byType(ClipRSuperellipse).at(3));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_host(tester).value, 1);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<CoilCarouselDots>(),
      isNull,
    );
  });

  group('motion', () {
    Future<double> pillWidthMidway(WidgetTester tester) async {
      await tester.tap(find.byType(ClipRSuperellipse).at(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      return _dotRects(tester)[3].width;
    }

    testWidgets('the pill springs to its width on standard', (tester) async {
      await tester.pumpWidget(const _Host());
      expect(await pillWidthMidway(tester), inExclusiveRange(6, 24));
      await tester.pumpAndSettle();
      expect(_dotRects(tester)[3].width, 24);
      expect(_dotRects(tester)[1].width, 6);
    });

    testWidgets('reduced motion makes it instant', (tester) async {
      await tester.pumpWidget(const _Host(reducedMotion: true));
      expect(await pillWidthMidway(tester), 24);
    });

    testWidgets('an instance motion override applies to the next change', (
      tester,
    ) async {
      final slow = CoilThemeData.light.motion.copyWith(
        standard: const CupertinoMotion(duration: Duration(seconds: 2)),
      );
      await tester.pumpWidget(_Host(motion: slow));
      await tester.tap(find.byType(ClipRSuperellipse).at(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dotRects(tester)[3].width, lessThan(20));
    });
  });

  testWidgets('style: fallback < theme < instance', (tester) async {
    await tester.pumpWidget(
      _Host(
        theme: CoilThemeData.light.withComponentStyle(
          const CoilCarouselDotsStyle(pillWidth: 30, dotSize: 8),
        ),
      ),
    );
    expect(_dotRects(tester)[1].width, 30);
    expect(_dotRects(tester)[0].width, 8);
    await tester.pumpWidget(
      _Host(
        theme: CoilThemeData.light.withComponentStyle(
          const CoilCarouselDotsStyle(pillWidth: 30, dotSize: 8),
        ),
        style: const CoilCarouselDotsStyle(pillWidth: 40),
      ),
    );
    await tester.pumpAndSettle();
    expect(_dotRects(tester)[1].width, 40);
    expect(_dotRects(tester)[0].width, 8);
  });
}
