import 'dart:ui' show Tristate;

import 'package:coil/coil.dart';
import 'package:coil_cli/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';
import 'src/ink_centering.dart';
import 'src/test_icons.dart';

const _steps = [
  CoilThinkingStep(
    title: Text('Searched the docs'),
    leading: TestIcon(TestGlyph.search),
    sources: [Text('flutter.dev'), Text('api.flutter.dev')],
  ),
  CoilThinkingStep(
    title: Text('Compared two layouts'),
    detail: Text('The grid keeps cards aligned at every width.'),
  ),
  CoilThinkingStep(
    title: Text('Drew a sketch'),
    image: ColoredBox(
      color: Color(0xFF9DB7F5),
      child: SizedBox(width: 240, height: 64),
    ),
  ),
];

const _words = [Text('Thinking'), Text('Moonwalking'), Text('Planning')];

Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  bool reduceMotion = false,
  TextDirection direction = TextDirection.ltr,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  debugShowCheckedModeBanner: false,
  builder: (context, navigator) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: direction,
      child: CoilTheme(
        data: CoilThemeData.light.copyWith(tier: tier),
        child: navigator!,
      ),
    ),
  ),
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.topLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(key: const ValueKey('target'), child: child),
          CoilButton(onPressed: () {}, child: const Text('After')),
        ],
      ),
    ),
  ),
);

final _target = find.byKey(const ValueKey('target'));

/// Pumps [initial] in [_app] and returns a notifier that swaps the content
/// (the page route is built once, so pumping a new [_app] wouldn't).
Future<ValueNotifier<Widget>> _pumpLive(
  WidgetTester tester,
  Widget initial, {
  bool reduceMotion = false,
}) async {
  final content = ValueNotifier(initial);
  addTearDown(content.dispose);
  await tester.pumpWidget(
    _app(
      ValueListenableBuilder(
        valueListenable: content,
        builder: (context, child, _) => child,
      ),
      reduceMotion: reduceMotion,
    ),
  );
  return content;
}

/// Thinking steps that apply their own `onChanged`; [steps] can grow.
class _Steps extends StatefulWidget {
  const _Steps({this.steps = _steps, this.expanded = false});

  final List<CoilThinkingStep> steps;
  final bool expanded;

  @override
  State<_Steps> createState() => _StepsState();
}

class _StepsState extends State<_Steps> {
  late bool expanded = widget.expanded;

  @override
  Widget build(BuildContext context) => CoilThinkingSteps(
    label: const Text('Thought for 12s'),
    steps: widget.steps,
    expanded: expanded,
    onChanged: (next) => setState(() => expanded = next),
  );
}

final _trigger = find.ancestor(
  of: find.text('Thought for 12s').last,
  matching: find.byType(CoilInteraction),
);

Set<WidgetState> _states(WidgetTester tester) => tester
    .widget<CoilInteractionDetector>(
      find.descendant(
        of: _trigger,
        matching: find.byType(CoilInteractionDetector),
      ),
    )
    .states
    .value;

Widget _stepsStory(BuildContext context) => const SizedBox(
  width: 280,
  child: CoilThinkingSteps(
    label: Text('Thought for 12s'),
    steps: _steps,
    expanded: true,
    onChanged: _ignore,
  ),
);

void _ignore(bool _) {}

void main() {
  group('CoilThinkingSteps', () {
    matrixGoldenTest(
      'thinking_steps',
      _stepsStory,
      surface: const Size(2600, 3000),
    );

    testWidgets('thinking_steps_states sheet', (tester) async {
      final keys = [for (final s in SheetState.values) ValueKey(s)];
      final sheet = await pumpSheet(
        tester,
        SheetPanel(
          title: 'CoilThinkingSteps trigger',
          theme: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
          child: StateTable(
            rows: [
              SheetRow(
                'collapsed',
                (state) => CoilThinkingSteps(
                  key: keys[state.index],
                  label: const Text('Thought for 12s'),
                  steps: _steps,
                  expanded: false,
                  onChanged: state.isDisabled ? null : (_) {},
                ),
              ),
            ],
          ),
        ),
        surface: const Size(1400, 200),
      );
      Finder cell(SheetState state) => find
          .descendant(
            of: find.byKey(keys[state.index]),
            matching: find.byType(CoilInteraction),
          )
          .first;
      final touch = await tester.startGesture(
        tester.getCenter(cell(SheetState.pressed)),
        pointer: 7,
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(cell(SheetState.hover)),
      );
      await mouse.moveBy(const Offset(1, 0));
      // The sheet has no Navigator for Tab, so focus directly, then make
      // the keyboard the last input.
      Focus.of(
        tester.element(
          find.descendant(
            of: cell(SheetState.focus),
            matching: find.byType(CoilInteractionDetector),
          ),
        ),
      ).requestFocus();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await settle(tester);
      await expectSheetGolden(
        tester,
        sheet,
        'goldens/thinking_steps_states.png',
      );
      await touch.cancel();
      await mouse.removePointer();
    });

    for (final direction in TextDirection.values) {
      testWidgets('${direction.name}: the trigger is a disclosure', (
        tester,
      ) async {
        await tester.pumpWidget(_app(const _Steps(), direction: direction));
        await expectCoilPattern(tester, _target, CoilPattern.disclosure);
      });
    }

    testWidgets('steps show only while expanded', (tester) async {
      await tester.pumpWidget(_app(const _Steps()));
      expect(find.bySemanticsLabel('Searched the docs'), findsNothing);
      expect(
        tester
            .getSemantics(_trigger)
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        Tristate.isFalse,
      );

      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Searched the docs'), findsOne);
      expect(find.bySemanticsLabel('flutter.dev'), findsOne);
      expect(
        tester
            .getSemantics(_trigger)
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        Tristate.isTrue,
      );
    });

    testWidgets('a new step grows in; steps there at first show at once', (
      tester,
    ) async {
      const added = CoilThinkingStep(title: Text('Wrote the answer'));
      final first = _steps.take(1).toList();
      final content = await _pumpLive(
        tester,
        _Steps(steps: first, expanded: true),
      );
      await tester.pump();
      expect(
        tester.getSize(find.text('Searched the docs')).height,
        greaterThan(0),
      );
      final initial = tester.getSize(_target).height;
      await tester.pumpAndSettle();
      expect(tester.getSize(_target).height, initial, reason: 'no entrance');

      content.value = _Steps(steps: [...first, added], expanded: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final growing = tester.getSize(_target).height;
      await tester.pumpAndSettle();
      final grown = tester.getSize(_target).height;
      expect(growing, inExclusiveRange(initial, grown));
    });

    testWidgets('reduced motion: a new step takes its height at once', (
      tester,
    ) async {
      const added = CoilThinkingStep(title: Text('Wrote the answer'));
      final first = _steps.take(1).toList();
      final content = await _pumpLive(
        tester,
        _Steps(steps: first, expanded: true),
        reduceMotion: true,
      );
      await tester.pumpAndSettle();
      content.value = _Steps(steps: [...first, added], expanded: true);
      await tester.pump();
      await tester.pump();
      final height = tester.getSize(_target).height;
      await tester.pumpAndSettle();
      expect(tester.getSize(_target).height, height);
    });

    testWidgets('a touch presses the trigger and leaves nothing lit', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Steps(), tier: CoilTier.touch));
      final gesture = await tester.startGesture(tester.getCenter(_trigger));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_states(tester), {WidgetState.pressed});
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_states(tester), isEmpty);
    });

    inkCenteringTests({
      'thinking_steps/trigger': (ink) => CoilThinkingSteps(
        label: InkLabel(ink, const Text('HEH')),
        steps: const [],
        expanded: false,
        onChanged: (_) {},
        indicator: const SizedBox.square(dimension: 12),
      ),
    });
  });

  group('CoilThinkingIndicator', () {
    matrixGoldenTest(
      'thinking_indicator',
      (context) => const CoilThinkingIndicator(
        words: _words,
        leading: TestIcon(TestGlyph.settings),
      ),
      surface: const Size(1800, 900),
    );

    final word = find.byType(CoilThinkingIndicator);
    String announced(WidgetTester tester) =>
        tester.getSemantics(word).getSemanticsData().label;

    testWidgets('a polite live region that announces each new word', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const CoilThinkingIndicator(words: _words)));
      final data = tester.getSemantics(word).getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(data.label, 'Thinking');

      await tester.pump(const Duration(seconds: 4));
      expect(announced(tester), 'Moonwalking');
      await tester.pump(const Duration(seconds: 4));
      expect(announced(tester), 'Planning');
      await tester.pump(const Duration(seconds: 4));
      expect(announced(tester), 'Thinking', reason: 'the cycle wraps');
    });

    testWidgets('the cycle pauses while tickers are muted', (tester) async {
      final content = await _pumpLive(
        tester,
        const TickerMode(
          enabled: false,
          child: CoilThinkingIndicator(words: _words),
        ),
      );
      await tester.pump(const Duration(seconds: 8));
      expect(announced(tester), 'Thinking');

      content.value = const TickerMode(
        enabled: true,
        child: CoilThinkingIndicator(words: _words),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(announced(tester), 'Moonwalking');
    });

    testWidgets('new words never announce sooner than every 4 s', (
      tester,
    ) async {
      final content = await _pumpLive(
        tester,
        const CoilThinkingIndicator(words: _words),
      );
      await tester.pump(const Duration(seconds: 1));
      content.value = const CoilThinkingIndicator(
        words: [Text('Reading'), Text('Writing')],
      );
      await tester.pump();
      expect(announced(tester), 'Thinking');
      await tester.pump(const Duration(seconds: 2));
      expect(announced(tester), 'Thinking');
      await tester.pump(const Duration(seconds: 1));
      expect(announced(tester), 'Reading');
    });

    testWidgets('the longest word reserves the width', (tester) async {
      await tester.pumpWidget(_app(const CoilThinkingIndicator(words: _words)));
      final widths = <double>[];
      for (var i = 0; i < 3; i++) {
        widths.add(tester.getSize(word).width);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(widths.toSet(), hasLength(1));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(const CoilThinkingIndicator(words: [Text('Moonwalking')])),
      );
      await tester.pump();
      expect(tester.getSize(word).width, widths.first);
    });

    testWidgets('the incoming word rises into place', (tester) async {
      await tester.pumpWidget(_app(const CoilThinkingIndicator(words: _words)));
      final rest = tester.getTopLeft(find.text('Thinking').last).dy;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final rising = tester.getTopLeft(find.text('Moonwalking').last).dy;
      await tester.pumpAndSettle();
      expect(rising, greaterThan(rest));
      expect(tester.getTopLeft(find.text('Moonwalking').last).dy, rest);
    });

    testWidgets('reduced motion: words still change, crossfading in place', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const CoilThinkingIndicator(words: _words), reduceMotion: true),
      );
      final rest = tester.getTopLeft(find.text('Thinking').last).dy;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getTopLeft(find.text('Moonwalking').last).dy, rest);
      expect(announced(tester), 'Moonwalking');
    });

    inkCenteringTests({
      'thinking_indicator': (ink) => CoilThinkingIndicator(
        words: const [Text('HEH')],
        style: ink
            ? null
            : const CoilThinkingIndicatorStyle(
                textStyle: TextStyle(color: Color(0x00000000)),
              ),
      ),
    });
  });

  testWidgets('style: instance overrides the theme', (tester) async {
    const red = Color(0xFFFF0000);
    await tester.pumpWidget(
      _app(
        const CoilThinkingIndicator(
          words: _words,
          style: CoilThinkingIndicatorStyle(
            textStyle: TextStyle(color: red),
          ),
        ),
      ),
    );
    final color = DefaultTextStyle.of(
      tester.element(find.text('Thinking').last),
    ).style.color;
    expect(color, red);
  });
}
