import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/coil_pattern.dart';
import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';
import 'src/ink_centering.dart';
import 'src/test_icons.dart';

/// A host that owns the banner's [CoilBanner.visible] and hides it when the
/// banner asks, with buttons around it for focus checks.
class _Host extends StatefulWidget {
  const _Host({
    this.tier = CoilTier.pointer,
    this.reduceMotion = false,
    this.initiallyVisible = true,
    this.motions,
    this.hideOnDismiss = true,
  });

  final CoilTier tier;
  final bool reduceMotion;
  final bool initiallyVisible;
  final bool hideOnDismiss;
  final Map<CoilBannerTrack<Object>, Motion>? motions;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool visible = widget.initiallyVisible;
  int dismissed = 0;

  void show({required bool value}) => setState(() => visible = value);

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, navigator) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: widget.reduceMotion),
      child: CoilTheme(
        data: CoilThemeData.light.copyWith(tier: widget.tier),
        child: navigator!,
      ),
    ),
    onGenerateRoute: (_) => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoilButton(onPressed: () {}, child: const Text('Before')),
              CoilBanner(
                key: const ValueKey('banner'),
                visible: visible,
                motions: widget.motions,
                title: const Text('Update available'),
                onDismissRequested: () => setState(() {
                  dismissed++;
                  if (widget.hideOnDismiss) visible = false;
                }),
              ),
              CoilButton(onPressed: () {}, child: const Text('After')),
            ],
          ),
        ),
      ),
    ),
  );
}

final _banner = find.byKey(const ValueKey('banner'));
_HostState _host(WidgetTester tester) => tester.state(find.byType(_Host));
double _height(WidgetTester tester) => tester.getSize(_banner).height;

Widget _gallery() => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  spacing: 12,
  children: [
    CoilBanner(
      title: const Text('Your trial ends in 3 days'),
      icon: const TestIcon(TestGlyph.heart),
      onDismissRequested: () {},
    ),
    CoilBanner(
      status: CoilBannerStatus.warning,
      variant: CoilBannerVariant.tinted,
      icon: const TestIcon(TestGlyph.settings),
      title: const Text('Storage almost full'),
      description: const Text('Free up space to keep syncing your files.'),
      actions: [
        CoilButton(onPressed: () {}, child: const Text('Manage')),
        CoilButton(
          onPressed: () {},
          variant: CoilButtonVariant.ghost,
          child: const Text('Later'),
        ),
      ],
      onDismissRequested: () {},
    ),
    CoilBanner(
      status: CoilBannerStatus.destructive,
      variant: CoilBannerVariant.tinted,
      icon: const TestIcon(TestGlyph.x),
      title: const Text('Sync failed'),
      actions: [
        CoilButton(
          onPressed: () {},
          variant: CoilButtonVariant.secondary,
          child: const Text('Retry'),
        ),
      ],
    ),
  ],
);

void main() {
  matrixGoldenTest(
    'banner',
    (context) => SizedBox(width: 360, child: _gallery()),
    surface: const Size(2200, 3000),
  );

  testWidgets('banner sheet: statuses, variants, placements', (tester) async {
    Widget column(CoilBannerVariant variant) => SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          for (final status in CoilBannerStatus.values)
            CoilBanner(
              status: status,
              variant: variant,
              icon: const TestIcon(TestGlyph.heart),
              title: Text('${status.name} · ${variant.name}'),
            ),
        ],
      ),
    );
    Widget panel(String name, CoilThemeData theme) => SheetPanel(
      title: name,
      theme: theme.copyWith(tier: CoilTier.pointer),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          column(CoilBannerVariant.plain),
          column(CoilBannerVariant.tinted),
          SizedBox(
            width: 320,
            child: MediaQuery(
              data: const MediaQueryData(padding: EdgeInsets.only(top: 20)),
              child: CoilBanner(
                placement: CoilBannerPlacement.fixed,
                status: CoilBannerStatus.info,
                variant: CoilBannerVariant.tinted,
                icon: const TestIcon(TestGlyph.heart),
                title: const Text('fixed, 20 px safe area'),
                onDismissRequested: () {},
              ),
            ),
          ),
        ],
      ),
    );
    final sheet = await pumpSheet(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          panel('light', CoilThemeData.light),
          panel('dark', CoilThemeData.dark),
        ],
      ),
      surface: const Size(1100, 900),
    );
    await expectSheetGolden(tester, sheet, 'goldens/banner.png');
  });

  group('ink centering', () {
    inkCenteringTests({
      'banner/title': (ink) =>
          CoilBanner(title: InkLabel(ink, const Text('HEH'))),
      'banner/title+dismiss': (ink) => CoilBanner(
        title: InkLabel(ink, const Text('HEH')),
        onDismissRequested: () {},
      ),
    });
  });

  testWidgets('is a polite live region that is not a tab stop', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    await expectCoilPattern(tester, _banner, CoilPattern.liveRegion);
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('Update available')),
      matchesSemantics(
        label: 'Update available',
        isLiveRegion: true,
        children: [
          matchesSemantics(
            label: 'Dismiss',
            isButton: true,
            isFocusable: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        ],
      ),
    );
    semantics.dispose();
  });

  group('dismiss', () {
    testWidgets('the ✕ reports; the owner hiding it collapses the row', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host());
      final open = _height(tester);
      expect(open, greaterThan(0));
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pump();
      expect(_host(tester).dismissed, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_height(tester), inExclusiveRange(0, open), reason: 'closing');
      await tester.pumpAndSettle();
      expect(_height(tester), 0);

      final semantics = tester.ensureSemantics();
      expect(find.semantics.byLabel('Update available'), findsNothing);
      semantics.dispose();
    });

    testWidgets('focus on the ✕ moves on to what follows the banner', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host());
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<CoilButton>()),
      );
      expect(
        find.ancestor(
          of: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
          matching: _banner,
        ),
        findsOneWidget,
        reason: 'the ✕ has focus',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
          matching: find.widgetWithText(CoilButton, 'After'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a hidden banner animates in when shown: row, then fade', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host(initiallyVisible: false));
      expect(_height(tester), 0);
      _host(tester).show(value: true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_height(tester), greaterThan(0), reason: 'the row opens first');
      final opacity = tester.widget<Opacity>(
        find.descendant(of: _banner, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 0, reason: 'the banner fades in 80 ms later');
      await tester.pumpAndSettle();
      expect(_height(tester), greaterThan(0));
    });

    testWidgets('reduced motion snaps the row and keeps the fade', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host(reduceMotion: true));
      final open = _height(tester);
      _host(tester).show(value: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final opacity = tester.widget<Opacity>(
        find.descendant(of: _banner, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, inExclusiveRange(0, 1), reason: 'still fading');
      expect(_height(tester), open, reason: 'the row waits for the fade');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_height(tester), 0, reason: 'then closes at once');
    });

    testWidgets('per-track motions apply at runtime', (tester) async {
      await tester.pumpWidget(
        _Host(motions: {CoilBannerTrack.row: const Motion.instant()}),
      );
      _host(tester).show(value: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_height(tester), 0);
    });
  });

  group('swipe', () {
    testWidgets('a touch fling dismisses', (tester) async {
      await tester.pumpWidget(const _Host(tier: CoilTier.touch));
      await tester.fling(
        find.text('Update available'),
        const Offset(200, 0),
        1200,
      );
      expect(_host(tester).dismissed, 1);
      await tester.pumpAndSettle();
      expect(_height(tester), 0);
    });

    testWidgets('a short swipe springs back', (tester) async {
      await tester.pumpWidget(const _Host(tier: CoilTier.touch));
      final before = tester.getTopLeft(find.text('Update available'));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Update available')),
      );
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.getTopLeft(find.text('Update available')).dx,
        greaterThan(before.dx),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_host(tester).dismissed, 0);
      expect(tester.getTopLeft(find.text('Update available')), before);
    });

    testWidgets('a kept banner swings back after the fling', (tester) async {
      await tester.pumpWidget(
        const _Host(tier: CoilTier.touch, hideOnDismiss: false),
      );
      final before = tester.getTopLeft(find.text('Update available'));
      await tester.fling(
        find.text('Update available'),
        const Offset(200, 0),
        1200,
      );
      await tester.pumpAndSettle();
      expect(_host(tester).dismissed, 1);
      expect(tester.getTopLeft(find.text('Update available')), before);
    });

    testWidgets('a mouse drag does not swipe', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.fling(
        find.text('Update available'),
        const Offset(200, 0),
        1200,
        deviceKind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_host(tester).dismissed, 0);
    });
  });

  testWidgets('the ✕ is a 44 px target on touch', (tester) async {
    await tester.pumpWidget(const _Host(tier: CoilTier.touch));
    final size = tester.getSize(
      find
          .ancestor(
            of: find.byType(CustomPaint).last,
            matching: find.byType(CoilInteractionDetector),
          )
          .first,
    );
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('fixed banners pad below the top safe area', (tester) async {
    Future<double> titleTop(CoilBannerPlacement placement) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: 40)),
            child: Align(
              alignment: Alignment.topCenter,
              child: CoilBanner(
                placement: placement,
                title: const Text('Offline'),
              ),
            ),
          ),
        ),
      );
      return tester.getTopLeft(find.text('Offline')).dy;
    }

    final inline = await titleTop(CoilBannerPlacement.inline);
    expect(await titleTop(CoilBannerPlacement.fixed), inline + 40);
  });

  testWidgets('style: fallback < theme < instance', (tester) async {
    const themed = Color(0xFF00FF00);
    const own = Color(0xFF0000FF);
    Color fill() =>
        (tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(CoilBanner),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as ShapeDecoration)
            .color!;
    Widget app(CoilThemeData theme, {CoilBannerStyle? style}) => WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, _) => CoilTheme(
        data: theme,
        child: CoilBanner(title: const Text('Hi'), style: style),
      ),
    );
    await tester.pumpWidget(app(CoilThemeData.light));
    expect(fill(), CoilThemeData.light.colors.hover);
    final theme = CoilThemeData.light.withComponentStyle(
      const CoilBannerStyle(background: themed),
    );
    await tester.pumpWidget(app(theme));
    expect(fill(), themed);
    await tester.pumpWidget(
      app(theme, style: const CoilBannerStyle(background: own)),
    );
    expect(fill(), own);
  });
}
