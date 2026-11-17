import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

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

void main() {
  testWidgets('a short sheet sits on the bottom edge, clear of the home '
      'indicator, at its content height', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(_app());
    await _push(tester);
    final content = tester.getRect(find.byKey(_content));
    expect(content.bottom, 844 - 34, reason: 'above the home indicator');
    final sheet = tester.getRect(find.byType(SheetBackground));
    expect(sheet.bottom, 844);
    expect(sheet.top, lessThan(content.top));
    expect(sheet.top, greaterThan(400), reason: 'it hugs its content');
  });

  testWidgets("it uses the theme's motion, surface, scrim and shape", (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(_app(theme: CoilThemeData.dark));
    final route = await _push(tester);
    final theme = CoilTheme.of(_home);
    final motion = CoilTheme.motionOf(_home);
    expect(route.motion, motion.gentle, reason: 'in and out alike');
    expect(
      route.barrierColor,
      StupidSimpleGlassSheetRoute<void>(child: const SizedBox()).barrierColor,
      reason: "the glass sheet's own scrim",
    );
    expect(route.blurBehindBarrier, isTrue);
    expect(route.backgroundColor, theme.colors.surface(1 + 2));
    expect(
      (route.shape as RoundedSuperellipseBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(36)),
    );
    // Content inside sits on the sheet's level.
    expect(CoilSurface.levelOf(tester.element(find.byKey(_content))), 3);
  });

  for (final theme in [CoilThemeData.light, CoilThemeData.dark]) {
    testWidgets('${theme.brightness.name}: dialogs, without the blur, dim a '
        'little more than sheets', (tester) async {
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
      expect(sheet.a, closeTo(0.15, 0.001));
      expect(scrim.a, greaterThan(sheet.a));
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
    final radius = (route.shape as RoundedSuperellipseBorder).borderRadius;
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

  testWidgets('a sheet opened from a sheet stacks on it; only the first '
      'dims the page', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(_app());
    final first = await _push(tester);
    final second = await _push(
      tester,
      from: tester.element(find.byKey(_content)),
      child: const CoilSheetPanel(
        child: SizedBox(key: ValueKey('second'), height: 100),
      ),
    );
    expect(first.barrierColor, isNotNull);
    expect(second.barrierColor, isNull);
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
    final sheet = tester.getRect(find.byType(SheetBackground));
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
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(_app());
      await _push(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(_content), findsNothing);
    });
  }
}
