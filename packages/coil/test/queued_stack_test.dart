import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';
import 'src/ink_centering.dart';
import 'src/test_icons.dart';

const _width = 400.0;

const _a = CoilQueuedMessage(id: 'a', text: 'Tighten the spacing');
const _b = CoilQueuedMessage(id: 'b', text: 'Match these mockups');
const _c = CoilQueuedMessage(id: 'c', text: 'Audit the color contrast');
const _d = CoilQueuedMessage(id: 'd', text: 'Ship it');

/// Owns the queue, as an app does, and records edits.
class _Host extends StatefulWidget {
  const _Host({required this.queue, this.edited});

  final List<CoilQueuedMessage> queue;
  final List<Object>? edited;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<CoilQueuedMessage> queue = widget.queue;

  @override
  void didUpdateWidget(_Host oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queue != widget.queue) queue = widget.queue;
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: CoilQueuedStack(
      messages: queue,
      onChanged: (next) => setState(() => queue = next),
      onEdit: (m) => widget.edited?.add(m.id),
      icon: const TestIcon(TestGlyph.arrowRight),
      editIcon: const TestIcon(TestGlyph.settings),
    ),
  );
}

Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  bool reducedMotion = false,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  debugShowCheckedModeBanner: false,
  builder: (context, navigator) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: CoilTheme(
      data: CoilThemeData.light.copyWith(tier: tier),
      child: _Content(content: child, child: navigator!),
    ),
  ),
  // The route is built once, so the content comes from above the navigator
  // and a new pumpWidget replaces it.
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _width,
        height: 400,
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

Future<void> _pump(
  WidgetTester tester,
  List<CoilQueuedMessage> queue, {
  CoilTier tier = CoilTier.pointer,
  bool reducedMotion = false,
  List<Object>? edited,
}) => tester.pumpWidget(
  _app(
    _Host(queue: queue, edited: edited),
    tier: tier,
    reducedMotion: reducedMotion,
  ),
);

/// What the user sees of a card: the product of every opacity above it.
double _opacity(WidgetTester tester, String text) {
  var opacity = 1.0;
  for (final o in tester.widgetList<Opacity>(
    find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
  )) {
    opacity *= o.opacity;
  }
  return opacity;
}

/// The bottom edge of a card's text on screen.
double _bottom(WidgetTester tester, String text) =>
    tester.getRect(find.text(text)).bottom;

/// The visible order of the cards, top to bottom.
List<String> _order(WidgetTester tester, List<String> texts) =>
    [...texts]
      ..sort((x, y) => _bottom(tester, x).compareTo(_bottom(tester, y)));

Future<TestGesture> _hover(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(find.text(_a.text)));
  await tester.pumpAndSettle();
  return mouse;
}

void main() {
  Widget story(BuildContext context) => const SizedBox(
    width: 360,
    child: CoilQueuedStack(
      messages: [_a, _b, _c, _d],
      onChanged: _ignore,
      onEdit: _ignore,
      icon: TestIcon(TestGlyph.arrowRight),
    ),
  );

  matrixGoldenTest('queued_stack', story, surface: const Size(2400, 1100));

  testWidgets('state sheet: folded, fanned out, attachments, compact', (
    tester,
  ) async {
    Widget thumb(Color color) => ColoredBox(color: color);
    Widget cell(String label, Widget child) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          label,
          style: const CoilTypography().style(
            CoilMetrics.pointer.caption,
            color: const Color(0xFF737373),
          ),
        ),
        SizedBox(width: 340, child: child),
      ],
    );
    final sheet = await pumpSheet(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tier in CoilTier.values)
            ThemedPair(
              title: 'CoilQueuedStack · ${tier.name}',
              tier: tier,
              builder: (context) => Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 24,
                children: [
                  cell(
                    'folded',
                    const CoilQueuedStack(
                      messages: [_a, _b, _c, _d],
                      onChanged: _ignore,
                      onEdit: _ignore,
                      icon: TestIcon(TestGlyph.arrowRight),
                    ),
                  ),
                  cell(
                    'fanned out (hover)',
                    CoilQueuedStack(
                      key: tier == CoilTier.pointer
                          ? const ValueKey('fanned')
                          : null,
                      messages: const [_a, _b, _c],
                      onChanged: _ignore,
                      onEdit: _ignore,
                      icon: const TestIcon(TestGlyph.arrowRight),
                      editIcon: const TestIcon(TestGlyph.settings),
                    ),
                  ),
                  cell(
                    'attachments',
                    CoilQueuedStack(
                      messages: [
                        CoilQueuedMessage(
                          id: 'files',
                          text: 'Use these',
                          attachments: [
                            for (final c in const [
                              Color(0xFF6B97FF),
                              Color(0xFFE5A04B),
                              Color(0xFF59B37A),
                              Color(0xFFB36BD6),
                              Color(0xFF999999),
                            ])
                              thumb(c),
                          ],
                        ),
                        const CoilQueuedMessage(
                          id: 'only',
                          text: '',
                          attachments: [SizedBox()],
                        ),
                      ],
                      onChanged: _ignore,
                      onEdit: _ignore,
                    ),
                  ),
                  cell(
                    'compact',
                    const CoilQueuedStack(
                      size: CoilSize.compact,
                      messages: [_a, _b],
                      onChanged: _ignore,
                      onEdit: _ignore,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      surface: const Size(3000, 700),
    );
    // A mouse over the first card of the light pointer stack fans it out
    // and shows that card's actions.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getBottomLeft(find.byKey(const ValueKey('fanned')).first) +
          const Offset(120, -20),
    );
    await settle(tester);
    await expectSheetGolden(tester, sheet, 'goldens/queued_stack.png');
  });

  inkCenteringTests({
    'queued_stack/card': (ink) => SizedBox(
      width: 400,
      child: CoilQueuedStack(
        messages: const [CoilQueuedMessage(id: 'ink', text: 'HEH')],
        onChanged: _ignore,
        onEdit: _ignore,
        style: CoilQueuedStackStyle(
          textStyle: TextStyle(color: ink ? null : const Color(0x00000000)),
        ),
      ),
    ),
  });

  group('motion', () {
    testWidgets('a queued card fades in and rises into place', (
      tester,
    ) async {
      await _pump(tester, const [_a]);
      await _hover(tester);
      await _pump(tester, const [_a, _b]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final midOpacity = _opacity(tester, _b.text);
      final midBottom = _bottom(tester, _b.text);
      expect(midOpacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_opacity(tester, _b.text), 1);
      expect(
        _bottom(tester, _b.text),
        lessThan(midBottom),
        reason: 'it rises from below its place',
      );
    });

    testWidgets('a removed card fades out, then leaves', (tester) async {
      await _pump(tester, const [_a, _b]);
      await _hover(tester);
      await _pump(tester, const [_a]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(_opacity(tester, _b.text), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text(_b.text), findsNothing);
    });

    testWidgets('a reorder slides the cards past each other', (tester) async {
      await _pump(tester, const [_a, _b, _c]);
      await _hover(tester);
      final texts = [_a.text, _b.text, _c.text];
      expect(_order(tester, texts), [_c.text, _b.text, _a.text]);
      final aBefore = _bottom(tester, _a.text);
      final cBefore = _bottom(tester, _c.text);

      await _pump(tester, const [_c, _b, _a]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final aMid = _bottom(tester, _a.text);
      expect(aMid, lessThan(aBefore), reason: 'moving, not jumping');
      expect(aMid, greaterThan(cBefore));
      await tester.pumpAndSettle();
      expect(_order(tester, texts), [_a.text, _b.text, _c.text]);
      expect(_bottom(tester, _a.text), cBefore);
    });

    testWidgets('queueing behind the folded pile makes it recoil', (
      tester,
    ) async {
      await _pump(tester, const [_a, _b, _c]);
      await tester.pumpAndSettle();
      final rest = _bottom(tester, _a.text);
      await _pump(tester, const [_a, _b, _c, _d]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_bottom(tester, _a.text), lessThan(rest));
      await tester.pumpAndSettle();
      expect(_bottom(tester, _a.text), rest);
    });

    testWidgets('reduced motion: cards move at once and still fade', (
      tester,
    ) async {
      await _pump(tester, const [_a, _b, _c], reducedMotion: true);
      await _hover(tester);
      final cBefore = _bottom(tester, _c.text);
      await _pump(tester, const [_c, _b, _a], reducedMotion: true);
      await tester.pump();
      expect(_bottom(tester, _a.text), cBefore, reason: 'no slide');

      await _pump(tester, const [_c, _b, _a, _d], reducedMotion: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(_opacity(tester, _d.text), inExclusiveRange(0, 1));
    });

    testWidgets('runtime motion overrides apply per track', (tester) async {
      await tester.pumpWidget(
        _app(
          CoilQueuedStack(
            messages: const [_a, _b],
            onChanged: _ignore,
            onEdit: _ignore,
            motions: {
              CoilQueuedStackTrack.opacity: const CupertinoMotion(
                duration: Duration(seconds: 2),
              ),
            },
          ),
        ),
      );
      await tester.pumpWidget(
        _app(
          CoilQueuedStack(
            messages: const [_a, _b, _c],
            onChanged: _ignore,
            onEdit: _ignore,
            motions: {
              CoilQueuedStackTrack.opacity: const CupertinoMotion(
                duration: Duration(seconds: 2),
              ),
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Folded, the third card is fully visible once present; it's still
      // fading in on the slow override.
      expect(_opacity(tester, _c.text), lessThan(0.6));
    });
  });

  group('pointer', () {
    testWidgets('hover fans the pile out; leaving folds it', (tester) async {
      await _pump(tester, const [_a, _b]);
      await tester.pumpAndSettle();
      final folded = _bottom(tester, _a.text) - _bottom(tester, _b.text);
      expect(folded, closeTo(12, 1), reason: 'the second card peeks 12 px');

      final mouse = await _hover(tester);
      final fanned = _bottom(tester, _a.text) - _bottom(tester, _b.text);
      expect(fanned, greaterThan(40), reason: 'a card apart');

      await mouse.moveTo(const Offset(_width / 2, 2));
      await tester.pumpAndSettle();
      expect(
        _bottom(tester, _a.text) - _bottom(tester, _b.text),
        closeTo(12, 1),
      );
    });

    testWidgets('actions show on hover; double-click edits', (tester) async {
      final edited = <Object>[];
      await _pump(tester, const [_a, _b], edited: edited);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Remove'), findsNothing);

      final mouse = await _hover(tester);
      expect(find.bySemanticsLabel('Remove'), findsOneWidget);
      await mouse.moveTo(tester.getCenter(find.text(_a.text)));
      await tester.tapAt(
        tester.getCenter(find.text(_a.text)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(
        tester.getCenter(find.text(_a.text)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(edited, ['a']);
    });

    testWidgets('dragging a card reorders the queue', (tester) async {
      await _pump(tester, const [_a, _b, _c]);
      await _hover(tester);
      final pitch = _bottom(tester, _a.text) - _bottom(tester, _b.text);
      final drag = await tester.startGesture(
        tester.getCenter(find.text(_a.text)),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveBy(const Offset(0, -20));
      await drag.moveBy(Offset(0, -pitch * 1.2 + 20));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(_order(tester, [_a.text, _b.text, _c.text]), [
        _c.text,
        _a.text,
        _b.text,
      ]);
    });
  });

  group('touch', () {
    testWidgets('a tap fans the pile out until collapse; no hover', (
      tester,
    ) async {
      await _pump(tester, const [_a, _b], tier: CoilTier.touch);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Remove'),
        findsNWidgets(2),
        reason: 'actions always show on touch',
      );
      final folded = _bottom(tester, _a.text) - _bottom(tester, _b.text);

      await tester.tap(find.text(_a.text));
      await tester.pumpAndSettle();
      expect(
        _bottom(tester, _a.text) - _bottom(tester, _b.text),
        greaterThan(folded + 20),
      );

      await tester.tap(find.bySemanticsLabel('Collapse queued messages'));
      await tester.pumpAndSettle();
      expect(
        _bottom(tester, _a.text) - _bottom(tester, _b.text),
        closeTo(folded, 0.5),
        reason: 'nothing stays open where the finger lifted',
      );
    });

    testWidgets('remove takes the card out of the queue', (tester) async {
      await _pump(tester, const [_a, _b], tier: CoilTier.touch);
      await tester.tap(find.text(_a.text));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Remove').first);
      await tester.pumpAndSettle();
      expect(find.text(_a.text), findsNothing);
      expect(find.text(_b.text), findsOneWidget);
    });
  });

  group('keyboard', () {
    testWidgets('Tab fans out; Alt+arrows move; Delete removes; Enter edits', (
      tester,
    ) async {
      final edited = <Object>[];
      await _pump(tester, const [_a, _b, _c], edited: edited);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        _bottom(tester, _a.text) - _bottom(tester, _b.text),
        greaterThan(40),
        reason: 'focus inside fans it out',
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      final texts = [_a.text, _b.text, _c.text];
      expect(_order(tester, texts), [_c.text, _a.text, _b.text]);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(edited, ['a']);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(find.text(_a.text), findsNothing);
    });
  });

  testWidgets('cards read their place in the queue', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const [_a, _b]);
    expect(
      find.bySemanticsLabel('Queued message 1 of 2: ${_a.text}'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('2 queued messages'), findsOneWidget);
    semantics.dispose();
  });
}

void _ignore(Object? _) {}
