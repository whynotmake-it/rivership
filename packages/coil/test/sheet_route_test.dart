import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/paint_probe.dart';
import 'src/select_harness.dart';

const _content = ValueKey('content');

/// The app's home context, for pushing routes.
late BuildContext _home;

Widget _app({CoilThemeData? theme}) => testApp(
  colors: (theme ?? CoilThemeData.light).colors,
  tier: CoilTier.touch,
  home: Builder(
    builder: (context) {
      _home = context;
      return const SizedBox.expand();
    },
  ),
);

/// The sheet's surface around [of] (the first sheet's content by default).
Finder _surface([Finder? of]) => find
    .ancestor(
      of: of ?? find.byKey(_content),
      matching: find.byWidgetPredicate(
        (w) => w is CoilSurface && w.offset == CoilSurface.popoverOffset,
      ),
    )
    .first;

/// The sheet around [of]: its surface's clip, which has the sheet's size
/// (the surface itself runs on below the bottom edge).
Finder _sheet([Finder? of]) => find
    .descendant(of: _surface(of), matching: find.byType(ClipRSuperellipse))
    .first;

Future<CoilSheetRoute<String>> _push(
  WidgetTester tester, {
  BuildContext? from,
  Widget? child,
  bool barrierDismissible = true,
  String? barrierLabel,
}) async {
  final route = CoilSheetRoute<String>(
    context: from ?? _home,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    child:
        child ??
        const CoilSheetPanel(
          title: Text('Fruit'),
          child: SizedBox(key: _content, height: 200),
        ),
  );
  Navigator.of(from ?? _home).push(route).ignore();
  await tester.pumpAndSettle();
  return route;
}

const _footerKey = ValueKey('footer');
const _tallKey = ValueKey('tall');
const _tall = SizedBox(key: _tallKey, height: 2000);

void main() {
  testWidgets('a short sheet sits on the bottom edge, clear of the home '
      'indicator, at its content height', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(_app());
    await _push(tester);
    final content = tester.getRect(find.byKey(_content));
    expect(content.bottom, 844 - 34, reason: 'above the home indicator');
    final sheet = tester.getRect(_sheet());
    expect(sheet.bottom, 844);
    expect(sheet.width, 390, reason: 'full width on a phone');
    expect(sheet.top, lessThan(content.top));
    expect(sheet.top, greaterThan(400), reason: 'it hugs its content');
    // The top gap, the title and the content, nothing more.
    expect(sheet.height, lessThan(200 + 34 + 80));
  });

  testWidgets('tall content grows it up to the top safe area, and scrolls', (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(_app());
    await _push(
      tester,
      child: CoilSheetPanel(
        title: const Text('Fruit'),
        child: ListView(
          children: [
            for (var i = 0; i < 60; i++) SizedBox(key: ValueKey(i), height: 44),
          ],
        ),
      ),
    );
    final list = find.byType(ListView);
    final sheet = tester.getRect(_sheet(list));
    expect(sheet.top, 47, reason: 'the top safe area is larger than 5 %');
    expect(sheet.bottom, 844);
    await tester.drag(list, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.getRect(_sheet(list)), sheet, reason: 'the list scrolled');
    expect(find.byKey(const ValueKey(0)), findsNothing);
  });

  testWidgets('without a top safe area the cap is 5 % of the height', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(390, 600) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await _push(
      tester,
      child: CoilSheetPanel(child: ListView(children: const [_tall])),
    );
    expect(tester.getRect(_sheet(find.byKey(_tallKey))).top, 600 * 0.05);
  });

  testWidgets("it uses the theme's motion, surface, scrim and shape, with "
      'no blur', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(_app(theme: CoilThemeData.dark));
    final route = await _push(tester);
    final theme = CoilTheme.of(_home);
    final motion = CoilTheme.motionOf(_home);
    expect(route.motion, motion.gentle, reason: 'in and out alike');
    expect(route.barrierColor, theme.colors.scrim);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(route.backgroundColor, theme.colors.surface(1 + 2));
    expect(CoilSheetRoute.glassRadius, 36);
    const corners = BorderRadius.vertical(top: Radius.circular(36));
    expect(route.shape.borderRadius, corners);
    final surface = tester.widget<CoilSurface>(_surface());
    expect(surface.borderRadius, corners);
    expect(
      tester
          .widget<ClipRSuperellipse>(
            find
                .ancestor(
                  of: find.byKey(_content),
                  matching: find.byType(ClipRSuperellipse),
                )
                .last,
          )
          .borderRadius,
      corners,
      reason: 'the content is clipped to the corners',
    );
    // Content inside sits on the sheet's level.
    expect(CoilSurface.levelOf(tester.element(find.byKey(_content))), 3);
  });

  for (final theme in [CoilThemeData.light, CoilThemeData.dark]) {
    testWidgets('${theme.brightness.name}: sheets and dialogs share the '
        'scrim', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(_app(theme: theme));
      final sheet = (await _push(tester)).barrierColor!;
      Navigator.of(_home).pop();
      await tester.pumpAndSettle();
      final dialog = CoilModalRoute<void>(
        context: _home,
        presentation: CoilModalPresentation.centered,
        builder: (_) => const SizedBox(),
      );
      final scrim = CoilTheme.of(_home).colors.scrim;
      expect(dialog.barrierColor, scrim);
      expect(sheet, scrim);
      expect(scrim.a, theme.brightness == Brightness.dark ? 0.3 : 0.2);
    });
  }

  testWidgets('the corners follow tighter shape families', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.touch,
        home: CoilTheme.override(
          transform: (t) => t.copyWith(shape: CoilShape.sharp),
          child: Builder(
            builder: (context) {
              _home = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    final route = await _push(tester);
    final radius = route.shape.borderRadius;
    expect(
      (radius as BorderRadius).topLeft.x,
      lessThan(4),
      reason: 'a sharp theme gets near-square corners',
    );
  });

  group('dismiss', () {
    testWidgets('the scrim, Escape and a drag close it', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(_app());

      await _push(tester);
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      expect(find.byKey(_content), findsNothing, reason: 'the scrim');

      await _push(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_content), findsNothing, reason: 'Escape');

      await _push(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Fruit')),
      );
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_content), findsNothing, reason: 'a drag');
    });

    testWidgets('with barrierDismissible false the scrim and Escape '
        "don't", (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(_app());
      await _push(tester, barrierDismissible: false);
      await tester.tapAt(const Offset(200, 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_content), findsOneWidget);
    });

    testWidgets('a short drag springs back', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(_app());
      await _push(tester);
      final before = tester.getRect(find.byKey(_content));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Fruit')),
      );
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_content)), before);
    });
  });

  for (final theme in [CoilThemeData.light, CoilThemeData.dark]) {
    testWidgets('${theme.brightness.name}: dragged up past its rest, the '
        'sheet shows its own fill below it, never the page, and settles '
        'back', (tester) async {
      useScreen(tester, TestScreen.phone);
      // A loud page, so any of it showing below the sheet stands out.
      await tester.pumpWidget(
        testApp(
          colors: theme.colors,
          tier: CoilTier.touch,
          home: Builder(
            builder: (context) {
              _home = context;
              return const ColoredBox(color: Color(0xFFFF0000));
            },
          ),
        ),
      );
      await _push(tester);
      final boundary = find.byKey(appBoundary);
      final rest = tester.getRect(_sheet());
      // The sheet's fill as it shows, in the empty content.
      final fill = await colorAt(
        tester,
        boundary,
        tester.getCenter(find.byKey(_content)),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Fruit')),
      );
      var lifted = false;
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 16));
        final sheet = tester.getRect(_sheet());
        if (sheet.bottom >= rest.bottom) continue;
        lifted = true;
        // Between the lifted sheet's bottom edge and the window's, at the
        // middle and near the sides.
        for (final x in [8.0, rest.center.dx, rest.right - 8]) {
          for (final y in [sheet.bottom + 1, rest.bottom - 1]) {
            final color = await colorAt(tester, boundary, Offset(x, y));
            expect(
              isNear(color, fill),
              isTrue,
              reason: 'the sheet, not the page, at ($x, $y), $color',
            );
          }
        }
      }
      expect(lifted, isTrue, reason: 'the drag lifts the sheet');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(_sheet()), rest, reason: 'it settles back');
    });
  }

  testWidgets('snapping stops: it opens at half, a drag settles at full or '
      'back at half instead of closing, and shrink keeps a pinned footer on '
      'screen', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(_app());
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    // A full sheet is the reference for where the stops are.
    Future<CoilSheetRoute<String>> push({
      SheetSnappingConfig? snapping,
      DismissalMode mode = DismissalMode.slide,
    }) async {
      final route = CoilSheetRoute<String>(
        context: _home,
        snappingConfig: snapping ?? SheetSnappingConfig.full,
        dismissalMode: mode,
        child: CoilSheetPanel(
          title: const Text('Fruit'),
          footer: const SizedBox(key: _footerKey, height: 48),
          child: ListView(
            children: const [SizedBox(key: _content, height: 2000)],
          ),
        ),
      );
      Navigator.of(_home).push(route).ignore();
      await tester.pumpAndSettle();
      return route;
    }

    final full = await push();
    final fullTop = tester.getRect(_sheet()).top;
    Navigator.of(_home).pop();
    await tester.pumpAndSettle();
    expect(full.isActive, isFalse);

    const config = SheetSnappingConfig([0.5, 1.0], initialSnap: 0.5);
    final route = await push(snapping: config);
    final range = screenHeight - fullTop;
    final halfTop = fullTop + range / 2;
    double top() => tester.getRect(_sheet()).top;
    expect(top(), closeTo(halfTop, 1), reason: 'opens at the half stop');

    await tester.drag(find.text('Fruit'), Offset(0, -range * 0.3));
    await tester.pumpAndSettle();
    expect(top(), closeTo(fullTop, 1), reason: 'a drag up settles at full');

    await tester.drag(find.text('Fruit'), Offset(0, range * 0.4));
    await tester.pumpAndSettle();
    expect(top(), closeTo(halfTop, 1), reason: 'a drag down stops at half');
    expect(route.isActive, isTrue, reason: 'it did not close');

    // Slid down, the footer rides the sheet off the bottom; shrunk, it
    // stays on screen.
    expect(
      tester.getRect(find.byKey(_footerKey)).bottom,
      greaterThan(screenHeight),
    );
    Navigator.of(_home).pop();
    await tester.pumpAndSettle();
    await push(snapping: config, mode: DismissalMode.shrink);
    expect(
      tester.getRect(find.byKey(_footerKey)).bottom,
      lessThanOrEqualTo(screenHeight),
      reason: 'the pinned footer is on screen at the half stop',
    );
  });

  testWidgets('a sheet opened from a sheet slides over it with its own '
      'scrim', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(_app());
    final first = await _push(tester);
    final firstRect = tester.getRect(_sheet());
    final second = await _push(
      tester,
      from: tester.element(find.byKey(_content)),
      child: const CoilSheetPanel(
        child: SizedBox(key: ValueKey('second'), height: 100),
      ),
    );
    expect(first.barrierColor, second.barrierColor);
    expect(tester.getRect(_sheet()), firstRect, reason: 'no push-back');
    expect(
      tester.getRect(_sheet(find.byKey(const ValueKey('second')))).bottom,
      844,
    );
    // It sits two levels above the sheet it opened from.
    expect(
      CoilSurface.levelOf(tester.element(find.byKey(const ValueKey('second')))),
      5,
    );

    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('second')), findsNothing);
    expect(find.byKey(_content), findsOneWidget, reason: 'one at a time');
  });

  testWidgets('it rides on the keyboard', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(_app());
    await _push(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 2);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(_content)).bottom,
      844 - 300,
      reason: 'the keyboard covers the home indicator',
    );
  });

  testWidgets('a wide window centers it, clear of insets that reach only '
      'the window edges', (tester) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(874, 402) * 2
      ..padding = const FakeViewPadding(left: 62 * 2, right: 62 * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await _push(tester);
    final sheet = tester.getRect(_sheet());
    expect(sheet.width, CoilSheetRoute.maxWidth);
    expect(sheet.center.dx, 874 / 2);
    // The content isn't padded for the notch it doesn't reach.
    expect(tester.getRect(find.byKey(_content)).width, CoilSheetRoute.maxWidth);
  });

  testWidgets('screen readers get the scrim label and the title header', (
    tester,
  ) async {
    // Disposed in `finally`, not a tear-down: the handle check runs before
    // tear-downs.
    final semantics = tester.ensureSemantics();
    try {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(_app());
      await _push(tester, barrierLabel: 'Close fruit');
      expect(find.bySemanticsLabel('Close fruit'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Fruit')),
        isSemantics(label: 'Fruit', isHeader: true),
      );
    } finally {
      semantics.dispose();
    }
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('back closes it on ${platform.name}', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(_app());
      await _push(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(_content), findsNothing);
      // The binding checks this before tear-downs run.
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
