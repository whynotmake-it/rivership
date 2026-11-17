import 'dart:async';

import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/select_harness.dart';
import 'src/test_icons.dart';

/// A drawer host whose open side lives in the harness, with a page that
/// can hold a horizontal carousel.
class _Host extends StatefulWidget {
  const _Host({
    this.end = true,
    this.carousel = false,
    this.reveal = CoilDrawerReveal.behind,
    this.drag,
    this.cornerRadius,
    this.fallbackCornerRadius = BorderRadius.zero,
    this.initial,
  });

  final bool end;
  final bool carousel;
  final CoilDrawerReveal reveal;
  final CoilDrawerDrag? drag;
  final BorderRadius? cornerRadius;
  final BorderRadius? fallbackCornerRadius;
  final CoilDrawerEdge? initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late CoilDrawerEdge? open = widget.initial;

  void set(CoilDrawerEdge? value) => setState(() => open = value);

  @override
  Widget build(BuildContext context) => CoilDrawer(
    open: open,
    onOpenChanged: set,
    reveal: widget.reveal,
    drag: widget.drag,
    look: widget.cornerRadius == null && widget.fallbackCornerRadius == null
        ? null
        : CoilDrawerLook.fallback(
            CoilTheme.of(context),
            reveal: widget.reveal,
          ).copyWith(
            cornerRadius: widget.cornerRadius,
            fallbackCornerRadius: widget.fallbackCornerRadius,
          ),
    startSemanticLabel: 'Navigation',
    endSemanticLabel: 'Details',
    start: Column(
      children: [
        const Text('Start panel'),
        CoilButton(onPressed: () {}, child: const Text('Start action')),
      ],
    ),
    end: widget.end ? const Center(child: Text('End panel')) : null,
    child: Column(
      key: const ValueKey('content'),
      children: [
        const SizedBox(height: 100),
        CoilButton(
          onPressed: () => set(CoilDrawerEdge.start),
          child: const Text('Open start'),
        ),
        if (widget.carousel)
          SizedBox(
            height: 200,
            child: ListView(
              key: const ValueKey('carousel'),
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < 6; i++)
                  SizedBox(width: 300, child: Text('Slide $i')),
              ],
            ),
          ),
        const Expanded(child: SizedBox.expand()),
      ],
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget host, {
  CoilTier tier = CoilTier.touch,
  TextDirection direction = TextDirection.ltr,
}) async {
  useScreen(tester, TestScreen.phone);
  await tester.pumpWidget(
    testApp(
      tier: tier,
      home: Directionality(textDirection: direction, child: host),
    ),
  );
  await tester.pumpAndSettle();
}

CoilDrawerEdge? _open(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host)).open;

/// The content's left edge.
double _contentLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('content'))).dx;

/// The content's clip radius (top left).
double _radius(WidgetTester tester) {
  final clip = tester.widget<ClipRSuperellipse>(
    find
        .ancestor(
          of: find.byKey(const ValueKey('content')),
          matching: find.byType(ClipRSuperellipse),
        )
        .first,
  );
  return (clip.borderRadius as BorderRadius).topLeft.x;
}

/// Drags from [from] by [dx] in small steps, so the drawer follows, and
/// lets go after holding still (a slow release) or right away.
Future<void> _drag(
  WidgetTester tester,
  Offset from,
  double dx, {
  bool slow = true,
}) async {
  final gesture = await tester.startGesture(from);
  const steps = 20;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(dx / steps, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (slow) await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await tester.pumpAndSettle();
}

/// The start panel's opacity.
double _panelOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.text('Start panel'),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

/// The start panel's content scale.
double _panelScale(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(
            of: find.text('Start panel'),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .entry(0, 0);

/// The decorations around the content, outermost first.
List<ShapeDecoration> _contentDecorations(WidgetTester tester) => [
  for (final box
      in tester
          .widgetList<DecoratedBox>(
            find.ancestor(
              of: find.byKey(const ValueKey('content')),
              matching: find.byType(DecoratedBox),
            ),
          )
          .toList()
          .reversed)
    if (box.decoration case final ShapeDecoration decoration) decoration,
];

/// The content's fill and shadow.
ShapeDecoration _edge(WidgetTester tester) => _contentDecorations(
  tester,
).firstWhere((d) => d.color != null);

/// The content's edge hairline.
BorderSide _hairline(WidgetTester tester) =>
    (_contentDecorations(tester).firstWhere((d) => d.color == null).shape
            as RoundedSuperellipseBorder)
        .side;

/// The color over the content while a panel shows.
Color _scrim(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.onDismiss != null,
            ),
            matching: find.byType(ColoredBox),
          )
          .first,
    )
    .color;

bool _shown(String text) => find.text(text).hitTestable().evaluate().isNotEmpty;

void main() {
  tearDown(CoilScreenRadius.debugReset);

  group('reveal from behind', () {
    testWidgets('opening slides the content aside to reveal the panel', (
      tester,
    ) async {
      await _pump(tester, const _Host());
      expect(_shown('Start panel'), isFalse);
      expect(_contentLeft(tester), 0);

      await tester.tap(find.text('Open start'));
      await tester.pumpAndSettle();
      expect(_contentLeft(tester), 320);
      expect(_shown('Start panel'), isTrue);
      expect(_shown('End panel'), isFalse);

      // A press on the content closes it.
      await tester.tapAt(const Offset(360, 400));
      await tester.pumpAndSettle();
      expect(_open(tester), isNull);
      expect(_contentLeft(tester), 0);
      expect(_shown('Start panel'), isFalse);
    });

    testWidgets('a drag anywhere on the content opens either side', (
      tester,
    ) async {
      await _pump(tester, const _Host());
      await _drag(tester, const Offset(200, 500), 220);
      expect(_open(tester), CoilDrawerEdge.start);
      expect(_contentLeft(tester), 320);

      // Dragging the panel back closes it.
      await _drag(tester, const Offset(200, 500), -220);
      expect(_open(tester), isNull);

      await _drag(tester, const Offset(200, 500), -220);
      expect(_open(tester), CoilDrawerEdge.end);
      expect(_contentLeft(tester), -320);
      expect(_shown('End panel'), isTrue);
    });

    testWidgets('the content follows the finger', (tester) async {
      await _pump(tester, const _Host());
      final gesture = await tester.startGesture(const Offset(100, 500));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      expect(_contentLeft(tester), 100);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_open(tester), isNull, reason: 'a short, slow drag settles back');
    });

    testWidgets('a light scrim, the panel fading in and a lifted edge follow '
        'the drag', (tester) async {
      await _pump(tester, const _Host());
      final colors = CoilTheme.of(tester.element(find.byType(_Host))).colors;
      final gesture = await tester.startGesture(const Offset(100, 500));
      for (var i = 0; i < 16; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      // Half of the 320 panel.
      expect(_contentLeft(tester), 160);
      // From 0.4, not 0: halfway is 0.7. It grows from 0.95 the same way.
      expect(_panelOpacity(tester), closeTo(0.7, 0.01));
      expect(_panelScale(tester), closeTo(0.975, 0.001));
      // Step 8's blurs, centered so they show at the side.
      final shadow = [
        for (final s in colors.shadow(8))
          if (s.blurRadius > 0)
            s.copyWith(offset: Offset.zero, spreadRadius: 0),
      ];
      expect(shadow, isNotEmpty);
      expect(_edge(tester).shadows, [
        for (final s in shadow)
          s.copyWith(color: s.color.withValues(alpha: s.color.a * 0.5)),
      ]);
      expect(
        _hairline(tester).color,
        colors.border.withValues(alpha: colors.border.a * 0.5),
      );
      expect(_scrim(tester).a, closeTo(0.035, 0.001), reason: 'half of 7 %');

      await gesture.moveBy(const Offset(200, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_open(tester), CoilDrawerEdge.start);
      expect(_panelOpacity(tester), 1);
      expect(_panelScale(tester), 1);
      expect(_edge(tester).shadows, shadow);
      expect(_hairline(tester).color, colors.border);
      expect(_scrim(tester).a, closeTo(0.07, 0.001));

      // A press on the content still closes it, and the edge goes away.
      await tester.tapAt(const Offset(360, 400));
      await tester.pumpAndSettle();
      expect(_open(tester), isNull);
      expect(_edge(tester).shadows, isEmpty);
      expect(_hairline(tester), BorderSide.none);
    });

    testWidgets('the panel grows from the edge the content leaves', (
      tester,
    ) async {
      Future<Alignment> anchorWhileOpening(
        Widget host,
        Offset drag,
        String text,
      ) async {
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, host);
        final gesture = await tester.startGesture(const Offset(200, 500));
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(drag);
          await tester.pump();
        }
        final transform = tester.widget<Transform>(
          find
              .ancestor(of: find.text(text), matching: find.byType(Transform))
              .first,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        return transform.alignment! as Alignment;
      }

      expect(
        await anchorWhileOpening(
          const _Host(),
          const Offset(10, 0),
          'Start panel',
        ),
        Alignment.centerRight,
        reason: 'a left panel grows from its right edge',
      );
      expect(
        await anchorWhileOpening(
          const _Host(),
          const Offset(-10, 0),
          'End panel',
        ),
        Alignment.centerLeft,
      );
    });

    testWidgets('reduced motion keeps the fade and drops the growth', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const _Host(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(100, 500));
      for (var i = 0; i < 16; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      expect(_panelScale(tester), 1);
      expect(_panelOpacity(tester), lessThan(1));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a short fling opens it, and one back closes it', (
      tester,
    ) async {
      await _pump(tester, const _Host());
      await tester.flingFrom(const Offset(100, 500), const Offset(80, 0), 1500);
      await tester.pumpAndSettle();
      expect(_open(tester), CoilDrawerEdge.start);

      await tester.flingFrom(
        const Offset(340, 500),
        const Offset(-80, 0),
        1500,
      );
      await tester.pumpAndSettle();
      expect(_open(tester), isNull);
      expect(_contentLeft(tester), 0);
    });

    testWidgets('a drag toward a side without a panel does nothing', (
      tester,
    ) async {
      await _pump(tester, const _Host(end: false));
      await _drag(tester, const Offset(300, 500), -220);
      expect(_open(tester), isNull);
      expect(_contentLeft(tester), 0);
    });

    testWidgets('right to left, the start panel is on the right', (
      tester,
    ) async {
      await _pump(tester, const _Host(), direction: TextDirection.rtl);
      await _drag(tester, const Offset(300, 500), -220);
      expect(_open(tester), CoilDrawerEdge.start);
      expect(_contentLeft(tester), -320);
      expect(tester.getTopRight(find.text('Start panel')).dx, greaterThan(70));

      await _drag(tester, const Offset(100, 500), 220);
      expect(_open(tester), isNull);
      await _drag(tester, const Offset(100, 500), 220);
      expect(_open(tester), CoilDrawerEdge.end);
    });

    testWidgets('only one side is open at a time', (tester) async {
      await _pump(tester, const _Host(initial: CoilDrawerEdge.start));
      expect(_contentLeft(tester), 320);
      tester.state<_HostState>(find.byType(_Host)).set(CoilDrawerEdge.end);
      await tester.pumpAndSettle();
      expect(_contentLeft(tester), -320);
      expect(_shown('Start panel'), isFalse);
      expect(_shown('End panel'), isTrue);
    });
  });

  group('horizontal scrollables', () {
    testWidgets('a carousel in the content keeps its drags', (tester) async {
      await _pump(tester, const _Host(carousel: true));
      final carousel = find.byKey(const ValueKey('carousel'));
      final at = tester.getCenter(carousel);
      await _drag(tester, at, -200);
      expect(_open(tester), isNull, reason: 'the carousel scrolled instead');
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: carousel, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.pixels, greaterThan(150));

      // Back toward its start: it scrolls back, and a drag that started
      // away from the edge never opens the drawer when it gets there.
      await _drag(tester, at, 400);
      expect(position.pixels, 0);
      expect(_open(tester), isNull);
      expect(_contentLeft(tester), 0);
    });

    testWidgets('at its edge it hands the drag to the drawer', (tester) async {
      await _pump(tester, const _Host(carousel: true));
      final at = tester.getCenter(find.byKey(const ValueKey('carousel')));
      await _drag(tester, at, 240);
      expect(_open(tester), CoilDrawerEdge.start);
      expect(_contentLeft(tester), 320);
    });

    testWidgets('scrolled to its far end, a drag opens the end panel', (
      tester,
    ) async {
      await _pump(tester, const _Host(carousel: true));
      final carousel = find.byKey(const ValueKey('carousel'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: carousel, matching: find.byType(Scrollable)),
          )
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await _drag(tester, tester.getCenter(carousel), -240);
      expect(_open(tester), CoilDrawerEdge.end);
      expect(position.pixels, position.maxScrollExtent);
    });
  });

  group('corner radius', () {
    testWidgets('the content takes the screen radius only while aside', (
      tester,
    ) async {
      CoilScreenRadius.debugReset();
      const channel = MethodChannel('corner_radius_plugin');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'getScreenRadius'
            ? {
                'topLeft': 47.33,
                'topRight': 47.33,
                'bottomLeft': 47.33,
                'bottomRight': 47.33,
              }
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await _pump(tester, const _Host());
      expect(CoilScreenRadius.value?.topLeft.x, 47.33);
      expect(_radius(tester), 0);

      final gesture = await tester.startGesture(const Offset(100, 500));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      expect(_radius(tester), 47.33, reason: 'moving');
      await gesture.up();
      await tester.pump();
      // Settling back: still rounded until it covers the panel again.
      expect(_radius(tester), 47.33);
      await tester.pumpAndSettle();
      expect(_contentLeft(tester), 0);
      expect(_radius(tester), 0, reason: 'snaps square once it covers');

      await tester.tap(find.text('Open start'));
      await tester.pumpAndSettle();
      expect(_radius(tester), 47.33, reason: 'open');
    });

    testWidgets('without a platform answer it uses the fallback', (
      tester,
    ) async {
      CoilScreenRadius.debugReset();
      await _pump(
        tester,
        const _Host(
          initial: CoilDrawerEdge.start,
          fallbackCornerRadius: BorderRadius.all(Radius.circular(12)),
        ),
      );
      expect(CoilScreenRadius.value, isNull);
      expect(_radius(tester), 12);
    });

    testWidgets('the default fallback is a phone radius on iOS and Android '
        'only', (tester) async {
      for (final (platform, radius) in [
        (TargetPlatform.iOS, 40.0),
        (TargetPlatform.android, 24.0),
        (TargetPlatform.macOS, 0.0),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        // The query fails here: no plugin is registered in tests.
        CoilScreenRadius.debugReset();
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          const _Host(
            initial: CoilDrawerEdge.start,
            fallbackCornerRadius: null,
          ),
        );
        expect(_radius(tester), radius, reason: '$platform');
      }
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a square screen stays square', (tester) async {
      CoilScreenRadius.debugReset(value: BorderRadius.zero);
      await _pump(
        tester,
        const _Host(initial: CoilDrawerEdge.start, fallbackCornerRadius: null),
      );
      expect(_radius(tester), 0);
    });

    testWidgets('an explicit radius wins', (tester) async {
      CoilScreenRadius.debugReset(
        value: const BorderRadius.all(Radius.circular(40)),
      );
      await _pump(
        tester,
        const _Host(
          initial: CoilDrawerEdge.end,
          cornerRadius: BorderRadius.all(Radius.circular(20)),
        ),
      );
      expect(_radius(tester), 20);
    });
  });

  group('gesture defaults', () {
    testWidgets('on the pointer tier drags only close', (tester) async {
      await _pump(tester, const _Host(), tier: CoilTier.pointer);
      await _drag(tester, const Offset(200, 500), 220);
      expect(_open(tester), isNull);
      await tester.tap(find.text('Open start'));
      await tester.pumpAndSettle();
      await _drag(tester, const Offset(200, 500), -220);
      expect(_open(tester), isNull);
    });

    testWidgets('CoilDrawerDrag.none ignores drags', (tester) async {
      await _pump(
        tester,
        const _Host(drag: CoilDrawerDrag.none, initial: CoilDrawerEdge.start),
      );
      await _drag(tester, const Offset(360, 500), -300);
      expect(_open(tester), CoilDrawerEdge.start);
    });

    testWidgets('on iOS, a pushed route keeps its back swipe', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      useScreen(tester, TestScreen.phone);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: Navigator(
            key: navigator,
            onGenerateRoute: (_) => PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => const SizedBox.expand(),
            ),
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => const _Host(),
            transitionDuration: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _drag(tester, const Offset(200, 500), 220);
      expect(_open(tester), isNull, reason: 'the swipe belongs to the route');
      await _drag(tester, const Offset(200, 500), -220);
      expect(_open(tester), CoilDrawerEdge.end);
      await _drag(tester, const Offset(200, 500), 220);
      expect(_open(tester), isNull, reason: 'closing still drags');
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('accessibility', () {
    testWidgets('focus moves into the panel and comes back; Escape closes', (
      tester,
    ) async {
      await _pump(tester, const _Host());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final before = FocusManager.instance.primaryFocus;
      expect(before?.context?.widget, isNotNull);

      tester.state<_HostState>(find.byType(_Host)).set(CoilDrawerEdge.start);
      await tester.pumpAndSettle();
      final inPanel = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.ancestor(
          of: find.byElementPredicate((e) => e == inPanel),
          matching: find.text('Start panel').first,
        ),
        findsNothing,
      );
      expect(FocusManager.instance.primaryFocus, isNot(before));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_open(tester), isNull);
      expect(FocusManager.instance.primaryFocus, before);
    });

    testWidgets('an app can take over Escape with CoilDismissIntent', (
      tester,
    ) async {
      var overridden = 0;
      var enabled = true;
      await _pump(
        tester,
        Actions(
          actions: {
            CoilDismissIntent: CallbackAction<CoilDismissIntent>(
              onInvoke: (_) => overridden++,
            ),
          },
          child: StatefulBuilder(
            builder: (context, setState) => Actions(
              actions: {
                if (!enabled) CoilDismissIntent: _Disabled<CoilDismissIntent>(),
              },
              child: const _Host(initial: CoilDrawerEdge.start),
            ),
          ),
        ),
      );
      expect(FocusManager.instance.primaryFocus, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(overridden, 1);
      expect(_open(tester), CoilDrawerEdge.start, reason: "the app's action");

      enabled = false;
      (tester.element(find.byType(StatefulBuilder)) as StatefulElement)
          .markNeedsBuild();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(overridden, 1);
      expect(
        _open(tester),
        isNull,
        reason: "a disabled override leaves coil's action",
      );
    });

    testWidgets('switching sides and closing returns focus to the trigger', (
      tester,
    ) async {
      await _pump(tester, const _Host());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final before = FocusManager.instance.primaryFocus;
      expect(before?.context?.widget, isNotNull);

      final host = tester.state<_HostState>(find.byType(_Host))
        ..set(CoilDrawerEdge.start);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, isNot(before));
      host.set(CoilDrawerEdge.end);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, isNot(before));
      host.set(null);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, before);
    });

    testWidgets('a nested drawer opening over another returns focus to the '
        'first trigger', (tester) async {
      final trigger = FocusNode(debugLabel: 'trigger');
      addTearDown(trigger.dispose);
      CoilDrawerEdge? outer;
      CoilDrawerEdge? inner;
      late StateSetter update;
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return CoilDrawer(
                open: outer,
                onOpenChanged: (open) => setState(() => outer = open),
                start: const Text('Outer panel'),
                child: CoilDrawer(
                  open: inner,
                  onOpenChanged: (open) => setState(() => inner = open),
                  end: const Text('Inner panel'),
                  child: Focus(
                    focusNode: trigger,
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),
      );
      trigger.requestFocus();
      await tester.pump();
      expect(trigger.hasPrimaryFocus, isTrue);

      update(() => inner = CoilDrawerEdge.end);
      await tester.pumpAndSettle();
      expect(trigger.hasFocus, isFalse);
      // The outer one opens: the inner one closes and hands over.
      update(() => outer = CoilDrawerEdge.start);
      await tester.pumpAndSettle();
      expect(inner, isNull);
      expect(trigger.hasFocus, isFalse);
      update(() => outer = null);
      await tester.pumpAndSettle();
      expect(trigger.hasPrimaryFocus, isTrue);
    });

    testWidgets('system back closes it', (tester) async {
      await _pump(tester, const _Host(initial: CoilDrawerEdge.end));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_open(tester), isNull);
    });

    testWidgets('screen readers reach only the open panel', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, const _Host());
      expect(find.semantics.byLabel('Open start'), findsOne);
      expect(find.semantics.byLabel('Start panel'), findsNothing);

      tester.state<_HostState>(find.byType(_Host)).set(CoilDrawerEdge.start);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Start panel'), findsOne);
      expect(find.semantics.byLabel('Open start'), findsNothing);
      expect(find.semantics.byLabel('End panel'), findsNothing);
      expect(
        tester.getSemantics(find.text('Start panel')),
        isNotNull,
      );
      semantics.dispose();
    });
  });

  group('controlled', () {
    testWidgets('an owner that ignores a drag leaves the drawer closed', (
      tester,
    ) async {
      final requests = <CoilDrawerEdge?>[];
      var presses = 0;
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: CoilDrawer(
            open: null,
            onOpenChanged: requests.add,
            start: const Text('Start panel'),
            child: Column(
              key: const ValueKey('content'),
              children: [
                const SizedBox(height: 100),
                CoilButton(
                  onPressed: () => presses++,
                  child: const Text('Press'),
                ),
                const Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _drag(tester, const Offset(200, 500), 260);
      expect(requests, [CoilDrawerEdge.start]);
      expect(_contentLeft(tester), 0, reason: 'back where the owner keeps it');
      expect(_shown('Start panel'), isFalse);
      await tester.tap(find.text('Press'));
      await tester.pumpAndSettle();
      expect(presses, 1, reason: 'the content still takes presses');
    });
  });

  group('look', () {
    test('the fallback look follows the reveal and the theme', () {
      final light = CoilDrawerLook.fallback(
        CoilThemeData.light,
        reveal: CoilDrawerReveal.behind,
      );
      expect(light.scrimColor, CoilDrawerLook.behindScrimLight);
      expect(light.scrimColor.a, closeTo(0.07, 0.001));
      expect(light.panelColor, CoilThemeData.light.colors.background);
      expect(light.contentColor, CoilThemeData.light.colors.background);
      expect(light.cornerRadius, isNull);
      expect(
        light.shadows,
        CoilDrawerLook.edgeShadows(CoilThemeData.light.colors),
      );
      final dark = CoilDrawerLook.fallback(
        CoilThemeData.dark,
        reveal: CoilDrawerReveal.behind,
      );
      expect(dark.scrimColor.a, closeTo(0.15, 0.001));
      final over = CoilDrawerLook.fallback(
        CoilThemeData.dark,
        reveal: CoilDrawerReveal.over,
      );
      expect(over.scrimColor, CoilThemeData.dark.colors.scrim);
      expect(over.panelColor, isNull, reason: "the raised surface's own");
      expect(
        light.copyWith(scrimColor: const Color(0x33000000)),
        isNot(light),
      );
      expect(
        CoilDrawerLook.fallback(
          CoilThemeData.light,
          reveal: CoilDrawerReveal.behind,
        ),
        light,
      );
    });

    testWidgets('a transition shrinks the content toward the far edge', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: CoilDrawer(
            open: CoilDrawerEdge.start,
            onOpenChanged: (_) {},
            transition: const CoilDrawerTransition(scale: 0.9),
            start: const Text('Start panel'),
            child: const SizedBox.expand(key: ValueKey('content')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(CoilDrawer));
      final rect = tester.getRect(find.byKey(const ValueKey('content')));
      expect(rect.left, 320);
      expect(rect.height, closeTo(size.height * 0.9, 0.5));
    });

    testWidgets("the sidebar style's drawer fields reach the drawer", (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: const CoilSidebarScaffold(
            sidebar: CoilSidebar(children: [Text('Nav')]),
            drawerTransition: CoilDrawerTransition(panelOpacity: 1),
            style: CoilSidebarStyle(
              drawerScrimColor: Color(0x33000000),
              drawerFallbackCornerRadius: BorderRadius.all(
                Radius.circular(9),
              ),
            ),
            body: SizedBox.expand(),
          ),
        ),
      );
      final element = tester.element(find.byType(CoilSidebarScaffold));
      final theme = CoilTheme.of(element);
      final fallback = CoilSidebarStyle.fallback(
        theme,
        CoilTheme.metricsOf(element),
      );
      expect(
        fallback.drawerFallbackCornerRadius,
        CoilDrawerLook.fallbackCornerRadiusFor(defaultTargetPlatform),
      );
      expect(fallback.drawerShadows, CoilDrawerLook.edgeShadows(theme.colors));
      expect(fallback.drawerScrimColor, isNull, reason: 'set by the reveal');

      final drawer = tester.widget<CoilDrawer>(find.byType(CoilDrawer));
      expect(drawer.look!.scrimColor, const Color(0x33000000));
      expect(
        drawer.look!.fallbackCornerRadius,
        const BorderRadius.all(Radius.circular(9)),
      );
      expect(drawer.look!.shadows, fallback.drawerShadows);
      expect(drawer.transition, const CoilDrawerTransition(panelOpacity: 1));
    });
  });

  group('motion', () {
    Future<void> pumpScaffold(
      WidgetTester tester, {
      required bool reduced,
    }) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduced),
              child: CoilSidebarScaffold(
                sidebar: const CoilSidebar(children: [Text('Nav')]),
                motions: {
                  CoilSidebarTrack.drawer: const Motion.linear(
                    Duration(seconds: 2),
                  ),
                },
                body: const Column(
                  children: [
                    CoilSidebarTrigger(
                      icon: TestIcon(TestGlyph.home),
                      openLabel: Text('Open navigation'),
                    ),
                    Expanded(child: SizedBox.expand(key: ValueKey('page'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Open navigation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    double pageLeft(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const ValueKey('page'))).dx;

    testWidgets("the drawer track's motion drives the slide", (tester) async {
      await pumpScaffold(tester, reduced: false);
      expect(pageLeft(tester), closeTo(80, 2), reason: 'a quarter of 2 s');
      await tester.pumpAndSettle();
    });

    testWidgets("a drawer's own motion tokens obey reduced motion", (
      tester,
    ) async {
      for (final reduced in [false, true]) {
        await tester.pumpWidget(const SizedBox());
        useScreen(tester, TestScreen.phone);
        late StateSetter update;
        CoilDrawerEdge? open;
        await tester.pumpWidget(
          testApp(
            tier: CoilTier.touch,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduced),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return CoilDrawer(
                      open: open,
                      onOpenChanged: (value) => setState(() => open = value),
                      motion: CoilTheme.of(context).motion.copyWith(
                        standard: const Motion.linear(Duration(seconds: 2)),
                      ),
                      start: const Text('Start panel'),
                      child: const SizedBox.expand(key: ValueKey('content')),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        update(() => open = CoilDrawerEdge.start);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          _contentLeft(tester),
          reduced ? 320 : closeTo(80, 2),
          reason: 'reduced: $reduced',
        );
        await tester.pumpAndSettle();
      }
    });

    testWidgets('reduced motion makes a custom drawer motion instant', (
      tester,
    ) async {
      await pumpScaffold(tester, reduced: true);
      expect(pageLeft(tester), 320);
    });
  });

  group('layers and state', () {
    testWidgets('a slide repaints neither the content nor the panel', (
      tester,
    ) async {
      final page = _CountingPainter();
      final side = _CountingPainter();
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: StatefulBuilder(
            builder: (context, setState) {
              CoilDrawerEdge? open;
              return CoilDrawer(
                open: open,
                onOpenChanged: (value) => setState(() => open = value),
                start: CustomPaint(painter: side, child: const SizedBox()),
                child: CustomPaint(
                  painter: page,
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pagePaints = page.paints;
      final gesture = await tester.startGesture(const Offset(100, 500));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      final sidePaints = side.paints;
      expect(sidePaints, greaterThan(0));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      expect(page.paints, pagePaints, reason: 'the page moves as a layer');
      expect(side.paints, sidePaints, reason: 'the panel fades as a layer');
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('changing the reveal keeps the content and panel state', (
      tester,
    ) async {
      var reveal = CoilDrawerReveal.behind;
      CoilDrawerEdge? open;
      late StateSetter update;
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return CoilDrawer(
                open: open,
                reveal: reveal,
                onOpenChanged: (value) => setState(() => open = value),
                start: const _Probe(key: ValueKey('panel probe')),
                child: Column(
                  children: [
                    const _Probe(key: ValueKey('page probe')),
                    Expanded(
                      child: ListView(
                        key: const ValueKey('list'),
                        children: [
                          for (var i = 0; i < 40; i++)
                            SizedBox(height: 50, child: Text('Row $i')),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey('list')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final page = tester.state(find.byKey(const ValueKey('page probe')));
      update(() => open = CoilDrawerEdge.start);
      await tester.pumpAndSettle();
      final panel = tester.state(find.byKey(const ValueKey('panel probe')));
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable)).position;
      final scrolled = position().pixels;
      expect(scrolled, greaterThan(0));

      for (final next in [CoilDrawerReveal.over, CoilDrawerReveal.behind]) {
        update(() => reveal = next);
        await tester.pumpAndSettle();
        expect(
          tester.state(find.byKey(const ValueKey('page probe'))),
          same(page),
          reason: '$next',
        );
        expect(
          tester.state(find.byKey(const ValueKey('panel probe'))),
          same(panel),
          reason: '$next',
        );
        expect(position().pixels, scrolled, reason: '$next');
      }
    });
  });

  group('over the content', () {
    testWidgets('the panel slides over a still page', (tester) async {
      await _pump(tester, const _Host(reveal: CoilDrawerReveal.over));
      await tester.tap(find.text('Open start'));
      await tester.pumpAndSettle();
      expect(_contentLeft(tester), 0);
      expect(_shown('Start panel'), isTrue);
      expect(tester.getTopLeft(find.text('Start panel')).dx, lessThan(320));
      await tester.tapAt(const Offset(360, 400));
      await tester.pumpAndSettle();
      expect(_open(tester), isNull);
    });
  });

  group('two nested sidebar scaffolds', () {
    Widget app() => const CoilSidebarScaffold(
      drawerLabel: 'Navigation',
      sidebar: CoilSidebar(children: [Text('Left nav')]),
      body: CoilSidebarScaffold(
        side: CoilSidebarSide.end,
        drawerLabel: 'Details',
        sidebar: CoilSidebar(children: [Text('Right details')]),
        body: Column(
          children: [
            Row(
              children: [
                CoilSidebarTrigger(
                  side: CoilSidebarSide.start,
                  icon: TestIcon(TestGlyph.home),
                  openLabel: Text('Open navigation'),
                ),
                Spacer(),
                CoilSidebarTrigger(
                  side: CoilSidebarSide.end,
                  icon: TestIcon(TestGlyph.home),
                  openLabel: Text('Open details'),
                ),
              ],
            ),
            Expanded(child: SizedBox.expand(key: ValueKey('page'))),
          ],
        ),
      ),
    );

    double pageLeft(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const ValueKey('page'))).dx;

    testWidgets('a drag opens the side it heads for', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(testApp(tier: CoilTier.touch, home: app()));
      await tester.pumpAndSettle();

      await _drag(tester, const Offset(200, 500), 220);
      expect(pageLeft(tester), 320);
      expect(_shown('Left nav'), isTrue);
      await _drag(tester, const Offset(360, 500), -220);
      expect(pageLeft(tester), 0);

      await _drag(tester, const Offset(200, 500), -220);
      expect(pageLeft(tester), -320);
      expect(_shown('Right details'), isTrue);
      expect(_shown('Left nav'), isFalse);
      await _drag(tester, const Offset(20, 500), 220);
      expect(pageLeft(tester), 0);
    });

    testWidgets('each trigger opens its side, and one closes the other', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(testApp(tier: CoilTier.touch, home: app()));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Open details'));
      await tester.pumpAndSettle();
      expect(pageLeft(tester), -320);

      // The outer one opens from its controller while the inner is open:
      // the inner closes.
      CoilSidebarScaffold.of(
        tester.element(find.text('Left nav', skipOffstage: false)),
      ).toggle();
      await tester.pumpAndSettle();
      expect(_shown('Left nav'), isTrue);
      expect(_shown('Right details'), isFalse);
      expect(pageLeft(tester), 320);

      await tester.tapAt(const Offset(360, 400));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Open navigation'));
      await tester.pumpAndSettle();
      expect(pageLeft(tester), 320);
    });
  });
}

/// An action that never handles its intent.
class _Disabled<T extends Intent> extends Action<T> {
  @override
  bool isEnabled(T intent) => false;

  @override
  Object? invoke(T intent) => null;
}

/// Counts its paints.
class _CountingPainter extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(_CountingPainter oldDelegate) => false;
}

/// A widget with state, to tell whether a rebuild kept it.
class _Probe extends StatefulWidget {
  const _Probe({super.key});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}
