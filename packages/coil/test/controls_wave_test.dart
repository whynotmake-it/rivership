// Behavior of the leaf controls and selection groups: Button loading, Badge,
// Skeleton, RadioGroup, CheckboxGroup and ToggleGroup (keyboard, touch vs
// mouse, reduced motion). Looks are covered by the golden matrix.
import 'dart:ui' show CheckedState, SemanticsAction, Tristate;

import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/test_icons.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  bool reduceMotion = false,
  TextDirection direction = TextDirection.ltr,
  CoilThemeData? theme,
}) => tester.pumpWidget(
  WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: direction,
        child: CoilTheme(
          data: (theme ?? CoilThemeData.light).copyWith(tier: tier),
          child: FocusScope(
            autofocus: true,
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    ),
  ),
);

const _plans = [
  CoilOption(value: 0, label: 'Free'),
  CoilOption(value: 1, label: 'Team'),
  CoilOption(value: 2, label: 'Business', enabled: false),
  CoilOption(value: 3, label: 'Enterprise'),
];

class _Stateful<T> extends StatefulWidget {
  const _Stateful({required this.initial, required this.builder});

  final T initial;
  final Widget Function(T value, ValueChanged<T> set) builder;

  @override
  State<_Stateful<T>> createState() => _StatefulState<T>();
}

class _StatefulState<T> extends State<_Stateful<T>> {
  late T value = widget.initial;

  @override
  Widget build(BuildContext context) =>
      widget.builder(value, (v) => setState(() => value = v));
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// A linear motion makes "how long did it take" easy to assert.
Motion _linear(int ms) => Motion.linear(Duration(milliseconds: ms));

/// The time everything takes to settle after [change].
Future<Duration> _settleTime(
  WidgetTester tester,
  Future<void> Function() change,
) async {
  await tester.pumpAndSettle();
  await change();
  var elapsed = Duration.zero;
  const step = Duration(milliseconds: 50);
  while (tester.binding.hasScheduledFrame &&
      elapsed < const Duration(seconds: 10)) {
    await tester.pump(step);
    elapsed += step;
  }
  return elapsed;
}

void main() {
  group('disabled controls', () {
    testWidgets('do not activate, hover, press or take focus', (tester) async {
      var activations = 0;
      final states = [for (var i = 0; i < 4; i++) WidgetStatesController()];
      addTearDown(() {
        for (final c in states) {
          c.dispose();
        }
      });
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoilButton(
              onPressed: null,
              statesController: states[0],
              child: const Text('Save'),
            ),
            CoilCheckbox(
              value: false,
              onChanged: null,
              statesController: states[1],
            ),
            CoilSwitch(
              value: false,
              onChanged: null,
              statesController: states[2],
            ),
            CoilCheckbox(
              value: true,
              tristate: true,
              onChanged: null,
              statesController: states[3],
            ),
            CoilButton(
              onPressed: () => activations++,
              child: const Text('After'),
            ),
          ],
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      for (final target in [
        find.byType(CoilButton).first,
        find.byType(CoilCheckbox).first,
        find.byType(CoilSwitch),
        find.byType(CoilCheckbox).last,
      ]) {
        await mouse.moveTo(tester.getCenter(target));
        await mouse.down(tester.getCenter(target));
        await tester.pump();
        await mouse.up();
        await tester.pump();
      }
      for (final c in states) {
        expect(c.value, isNot(contains(WidgetState.hovered)));
        expect(c.value, isNot(contains(WidgetState.pressed)));
      }
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(activations, 1, reason: 'Tab skips every disabled control');
    });
  });

  group('minimum press', () {
    testWidgets('a quick tap still shows its press for a moment', (
      tester,
    ) async {
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      await _pump(
        tester,
        CoilButton(
          onPressed: () {},
          statesController: states,
          child: const Text('Save'),
        ),
        tier: CoilTier.touch,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CoilButton)),
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 30));
      expect(states.value, contains(WidgetState.pressed));
      await tester.pump(const Duration(milliseconds: 200));
      expect(states.value, isNot(contains(WidgetState.pressed)));
    });
  });

  group('CoilButton loading', () {
    testWidgets('the spinner takes the leading slot and the width is locked', (
      tester,
    ) async {
      var presses = 0;
      Widget button({required bool loading}) => CoilButton(
        onPressed: () => presses++,
        loading: loading,
        leading: const TestIcon(TestGlyph.plus),
        child: const Text('Save'),
      );
      await _pump(tester, button(loading: false), reduceMotion: true);
      final idle = tester.getSize(find.byType(CoilButton));
      await _pump(tester, button(loading: true), reduceMotion: true);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(CoilButton)), idle);
      expect(find.byType(TestIcon), findsNothing, reason: 'the icon swapped');
      expect(find.text('Save'), findsOneWidget, reason: 'the label stays');
      await tester.tap(find.byType(CoilButton));
      expect(presses, 0, reason: 'a loading button blocks presses');
    });

    testWidgets('without a leading slot the spinner replaces the content', (
      tester,
    ) async {
      Widget button({required bool loading}) => CoilButton(
        onPressed: () {},
        loading: loading,
        child: const Text('Continue'),
      );
      await _pump(tester, button(loading: false), reduceMotion: true);
      final idle = tester.getSize(find.byType(CoilButton));
      await _pump(tester, button(loading: true), reduceMotion: true);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(CoilButton)), idle);
    });

    testWidgets('ignores Enter and Space while loading', (tester) async {
      var presses = 0;
      await _pump(
        tester,
        CoilButton(
          autofocus: true,
          onPressed: () => presses++,
          loading: true,
          child: const Text('Save'),
        ),
        reduceMotion: true,
      );
      await _key(tester, LogicalKeyboardKey.enter);
      await _key(tester, LogicalKeyboardKey.space);
      expect(presses, 0);
    });

    testWidgets('announces the loading label', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        CoilButton.icon(
          onPressed: () {},
          loading: true,
          loadingLabel: 'Loading',
          semanticLabel: 'Add',
          icon: const TestIcon(TestGlyph.plus),
        ),
        reduceMotion: true,
      );
      await tester.pumpAndSettle();
      final data = tester
          .getSemantics(find.byType(CoilButton))
          .getSemanticsData();
      expect(data.label, 'Add');
      expect(data.value, 'Loading');
      semantics.dispose();
    });

    testWidgets('the spinner turns; reduced motion stops it', (tester) async {
      final button = CoilButton(
        onPressed: () {},
        loading: true,
        child: const Text('Saving'),
      );
      await _pump(tester, button);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await _pump(tester, button, reduceMotion: true);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('CoilBadge', () {
    testWidgets('does not grow on touch, and compact is smaller', (
      tester,
    ) async {
      Future<double> height({required CoilTier tier, CoilSize? size}) async {
        await _pump(
          tester,
          CoilBadge(size: size, child: const Text('Draft')),
          tier: tier,
        );
        return tester.getSize(find.byType(CoilBadge)).height;
      }

      final pointer = await height(tier: CoilTier.pointer);
      expect(await height(tier: CoilTier.touch), pointer);
      expect(
        await height(tier: CoilTier.touch, size: CoilSize.compact),
        lessThan(pointer),
      );
    });

    testWidgets('is not interactive', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const CoilBadge(variant: CoilBadgeVariant.dot, child: Text('Dot')),
      );
      final data = tester
          .getSemantics(find.bySemanticsLabel('Dot'))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      semantics.dispose();
    });
  });

  group('CoilSkeleton', () {
    // The fade-in and the pulse are two nested opacities.
    double opacity(WidgetTester tester) => tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(CoilSkeleton),
            matching: find.byType(Opacity),
          ),
        )
        .fold(1, (product, o) => product * o.opacity);

    testWidgets('waits out the grace period, fades in, then pulses', (
      tester,
    ) async {
      await _pump(tester, const CoilSkeleton(width: 100, height: 16));
      await tester.pump(CoilSkeleton.grace ~/ 2);
      expect(opacity(tester), 0, reason: 'inside the grace period');
      await tester.pump(CoilSkeleton.grace + const Duration(seconds: 1));
      var lowest = 1.0;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        lowest = lowest < opacity(tester) ? lowest : opacity(tester);
      }
      expect(lowest, lessThan(1), reason: 'it pulses');
      expect(lowest, greaterThan(0), reason: 'and stays visible');
    });

    testWidgets('reduced motion keeps the grace and fade, drops the pulse', (
      tester,
    ) async {
      await _pump(
        tester,
        const CoilSkeleton(width: 100, height: 16),
        reduceMotion: true,
      );
      await tester.pump(CoilSkeleton.grace ~/ 2);
      expect(opacity(tester), 0);
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'no pulse');
    });

    testWidgets('is out of semantics; the region announces its label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const CoilSkeletonRegion(
          label: 'Loading',
          child: SizedBox(width: 200, child: CoilSkeletonText()),
        ),
        reduceMotion: true,
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.bySemanticsLabel('Loading'));
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(node.childrenCount, 0);
      semantics.dispose();
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('N skeleton lines are as tall as N lines of text '
          '(text scale $scale)', (tester) async {
        Future<double> height(Widget child) async {
          await _pump(
            tester,
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                  key: const ValueKey('box'),
                  width: 200,
                  child: child,
                ),
              ),
            ),
            reduceMotion: true,
          );
          await tester.pumpAndSettle();
          return tester.getSize(find.byKey(const ValueKey('box'))).height;
        }

        final style = const CoilTypography().style(CoilMetrics.pointer.body);
        final text = await height(
          Column(
            children: [
              for (var i = 0; i < 3; i++) Text('Line', style: style),
            ],
          ),
        );
        final skeleton = await height(const CoilSkeletonText());
        expect(skeleton, closeTo(text, 0.01));
      });
    }

    testWidgets('style: fallback < theme < instance', (tester) async {
      Color fill() => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(CoilSkeleton),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => (d.decoration as ShapeDecoration).color!)
          .first;
      const skeleton = CoilSkeleton(width: 40, height: 10);
      await _pump(tester, skeleton, reduceMotion: true);
      final fallback = fill();
      await _pump(
        tester,
        skeleton,
        reduceMotion: true,
        theme: CoilThemeData.light.withComponentStyle(
          const CoilSkeletonStyle(fill: Color(0xFF00FF00)),
        ),
      );
      expect(fill(), const Color(0xFF00FF00));
      expect(fill(), isNot(fallback));
      await _pump(
        tester,
        const CoilSkeleton(
          width: 40,
          height: 10,
          style: CoilSkeletonStyle(fill: Color(0xFFFF0000)),
        ),
        reduceMotion: true,
        theme: CoilThemeData.light.withComponentStyle(
          const CoilSkeletonStyle(fill: Color(0xFF00FF00)),
        ),
      );
      expect(fill(), const Color(0xFFFF0000));
    });
  });

  group('CoilRadioGroup', () {
    Widget group({
      int? value = 1,
      ValueChanged<int>? onChanged,
      CoilSize? size,
      CoilRadioGroupStyle? style,
    }) => SizedBox(
      width: 240,
      child: CoilRadioGroup<int>(
        value: value,
        onChanged: onChanged,
        options: _plans,
        size: size,
        style: style,
      ),
    );

    Widget stateful({int? initial = 1}) => _Stateful<int?>(
      initial: initial,
      builder: (value, set) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          group(value: value, onChanged: set),
          Text('value:$value'),
          CoilButton(onPressed: () {}, child: const Text('After')),
        ],
      ),
    );

    testWidgets('with nothing selected Tab reaches the first row without '
        'selecting it', (tester) async {
      await _pump(tester, stateful(initial: null));
      await _key(tester, LogicalKeyboardKey.tab);
      expect(find.text('value:null'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(find.text('value:1'), findsOneWidget);
    });

    testWidgets('arrows skip disabled rows', (tester) async {
      await _pump(tester, stateful());
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(find.text('value:3'), findsOneWidget, reason: 'skips Business');
    });

    testWidgets('a tap selects; a disabled row ignores taps', (tester) async {
      await _pump(tester, stateful());
      await tester.tap(find.text('Free').last);
      await tester.pumpAndSettle();
      expect(find.text('value:0'), findsOneWidget);
      await tester.tap(find.text('Business').last);
      await tester.pumpAndSettle();
      expect(find.text('value:0'), findsOneWidget);
    });

    testWidgets('a disabled group is skipped by Tab', (tester) async {
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            group(),
            CoilButton(onPressed: () {}, child: const Text('After')),
          ],
        ),
      );
      await _key(tester, LogicalKeyboardKey.tab);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<CoilButton>(),
        isNotNull,
      );
    });

    testWidgets('semantics: a radio group of checked radios', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, group(onChanged: (_) {}));
      final team = tester
          .getSemantics(find.bySemanticsLabel('Team'))
          .getSemanticsData();
      expect(team.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(team.flagsCollection.isChecked, CheckedState.isTrue);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Free'))
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        CheckedState.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('a long label wraps and grows its row', (tester) async {
      Future<double> height(String label) async {
        await _pump(
          tester,
          SizedBox(
            width: 120,
            child: CoilRadioGroup<int>(
              value: 0,
              onChanged: (_) {},
              options: [CoilOption(value: 0, label: label)],
            ),
          ),
        );
        return tester.getSize(find.byType(CoilRadioGroup<int>)).height;
      }

      expect(
        await height('A label long enough to wrap onto lines'),
        greaterThan(await height('Short')),
      );
    });

    testWidgets('a compact group draws a compact circle', (tester) async {
      Future<Size> circle(CoilSize size) async {
        await _pump(tester, group(size: size));
        return tester.getSize(find.byType(CoilRadioIndicator).first);
      }

      final regular = await circle(CoilSize.regular);
      expect((await circle(CoilSize.compact)).width, lessThan(regular.width));
    });

    testWidgets('style: instance wins over theme and fallback', (
      tester,
    ) async {
      Color dot() => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(CoilRadioIndicator),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<ShapeDecoration>()
          .map((d) => d.color)
          .whereType<Color>()
          .first;
      await _pump(tester, group(), reduceMotion: true);
      final fallback = dot();
      const themed = CoilRadioGroupStyle(dot: Color(0xFF00FF00));
      final theme = CoilThemeData.light.withComponentStyle(themed);
      await _pump(tester, group(), reduceMotion: true, theme: theme);
      expect(dot(), const Color(0xFF00FF00));
      expect(dot(), isNot(fallback));
      await _pump(
        tester,
        group(style: const CoilRadioGroupStyle(dot: Color(0xFFFF0000))),
        reduceMotion: true,
        theme: theme,
      );
      expect(dot(), const Color(0xFFFF0000));
    });

    testWidgets('reduced motion lands the selected fill at once', (
      tester,
    ) async {
      final slow = CoilThemeData.light.copyWith(
        motion: const CoilMotion().copyWith(standard: _linear(3000)),
      );
      Future<Duration> select({required bool reduce}) async {
        await _pump(tester, group(value: 0), theme: slow, reduceMotion: reduce);
        return _settleTime(
          tester,
          () =>
              _pump(tester, group(value: 3), theme: slow, reduceMotion: reduce),
        );
      }

      expect(
        await select(reduce: false),
        greaterThan(const Duration(seconds: 2)),
      );
      expect(await select(reduce: true), lessThan(const Duration(seconds: 1)));
    });
  });

  group('CoilCheckboxGroup', () {
    Widget stateful({Set<int> initial = const {0}, CoilSize? size}) =>
        _Stateful<Set<int>>(
          initial: initial,
          builder: (values, set) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 240,
                child: CoilCheckboxGroup<int>(
                  semanticLabel: 'Notify me',
                  values: values,
                  onChanged: set,
                  options: _plans,
                  size: size,
                ),
              ),
              Text('values:${(values.toList()..sort()).join(',')}'),
            ],
          ),
        );

    testWidgets('every row is a tab stop; arrows wrap; Home and End jump', (
      tester,
    ) async {
      await _pump(tester, stateful());
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.space);
      expect(find.text('values:0,1'), findsOneWidget, reason: 'second row');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(find.text('values:0,1,3'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.space);
      expect(find.text('values:1,3'), findsOneWidget, reason: 'wrapped');
      await _key(tester, LogicalKeyboardKey.end);
      await _key(tester, LogicalKeyboardKey.space);
      expect(find.text('values:1'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.home);
      await _key(tester, LogicalKeyboardKey.space);
      expect(find.text('values:0,1'), findsOneWidget);
    });

    testWidgets('a tap toggles a row; a disabled row ignores taps', (
      tester,
    ) async {
      await _pump(tester, stateful());
      await tester.tap(find.text('Team').last);
      await tester.pumpAndSettle();
      expect(find.text('values:0,1'), findsOneWidget);
      await tester.tap(find.text('Business').last);
      await tester.pumpAndSettle();
      expect(find.text('values:0,1'), findsOneWidget);
    });

    testWidgets('semantics: a labeled group of checked rows', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, stateful());
      expect(find.bySemanticsLabel('Notify me'), findsOneWidget);
      CheckedState state(String label) => tester
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData()
          .flagsCollection
          .isChecked;
      expect(state('Free'), CheckedState.isTrue);
      expect(state('Team'), CheckedState.isFalse);
      semantics.dispose();
    });

    testWidgets('a compact group draws compact boxes', (tester) async {
      Future<Size> box(CoilSize size) async {
        await _pump(tester, stateful(size: size));
        return tester.getSize(find.byType(CoilCheckboxIndicator).first);
      }

      final regular = await box(CoilSize.regular);
      expect((await box(CoilSize.compact)).width, lessThan(regular.width));
      await _pump(
        tester,
        CoilCheckbox(value: true, onChanged: (_) {}, size: CoilSize.compact),
      );
      expect(
        tester.getSize(find.byType(CoilCheckboxIndicator)).width,
        (await box(CoilSize.compact)).width,
      );
    });

    testWidgets('an unselected label is muted on pointer, not on touch', (
      tester,
    ) async {
      Color colorOf(String text) => DefaultTextStyle.of(
        tester.element(find.text(text).last),
      ).style.color!;
      await _pump(tester, stateful());
      await tester.pumpAndSettle();
      expect(colorOf('Team'), isNot(colorOf('Free')));
      await _pump(tester, stateful(), tier: CoilTier.touch);
      await tester.pumpAndSettle();
      expect(colorOf('Team'), colorOf('Free'));
    });
  });

  group('CoilToggleGroup', () {
    Widget stateful() => _Stateful<Set<int>>(
      initial: const {0},
      builder: (values, set) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoilToggleGroup<int>(
            values: values,
            onChanged: set,
            options: const [
              CoilOption(value: 0, label: 'Bold'),
              CoilOption(value: 1, label: 'Italic'),
              CoilOption(value: 2, label: 'Underline', enabled: false),
            ],
          ),
          Text('values:${(values.toList()..sort()).join(',')}'),
          CoilButton(onPressed: () {}, child: const Text('After')),
        ],
      ),
    );

    for (final direction in TextDirection.values) {
      testWidgets('one tab stop; arrows follow $direction; Space toggles', (
        tester,
      ) async {
        await _pump(tester, stateful(), direction: direction);
        await _key(tester, LogicalKeyboardKey.tab);
        await _key(
          tester,
          direction == TextDirection.ltr
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowLeft,
        );
        await _key(tester, LogicalKeyboardKey.space);
        expect(find.text('values:0,1'), findsOneWidget);
        await _key(tester, LogicalKeyboardKey.tab);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<CoilButton>(),
          isNotNull,
          reason: 'the group is one tab stop',
        );
      });
    }

    testWidgets('a tap toggles; a disabled toggle ignores taps', (
      tester,
    ) async {
      await _pump(tester, stateful());
      await tester.tap(find.text('Italic'));
      await tester.pumpAndSettle();
      expect(find.text('values:0,1'), findsOneWidget);
      await tester.tap(find.text('Underline'));
      await tester.pumpAndSettle();
      expect(find.text('values:0,1'), findsOneWidget);
    });

    testWidgets('semantics: selected toggle buttons', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, stateful());
      final data = tester
          .getSemantics(find.bySemanticsLabel('Bold'))
          .getSemanticsData();
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      semantics.dispose();
    });
  });

  group('groups on touch', () {
    testWidgets('leave no highlight under a lifted finger; a mouse hovers', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              child: CoilCheckboxGroup<int>(
                values: const {},
                onChanged: (_) {},
                options: _plans,
              ),
            ),
            CoilToggleGroup<int>(
              values: const {},
              onChanged: (_) {},
              options: const [
                CoilOption(value: 0, label: 'Bold'),
                CoilOption(value: 1, label: 'Italic'),
              ],
            ),
          ],
        ),
        tier: CoilTier.touch,
      );
      int? lit(String text) => CoilHoverRegion.maybeOf(
        tester.element(find.text(text).last),
      )?.activeIndex;
      for (final text in ['Team', 'Italic']) {
        await tester.tap(find.text(text).last);
        await tester.pumpAndSettle();
        expect(lit(text), isNull, reason: '$text: nothing stays lit');
      }
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Team').last));
      await tester.pumpAndSettle();
      expect(lit('Team'), 1);
    });
  });

  group('motions', () {
    // Each case builds its component in an "off" and an "on" state and
    // names the track that animates the change.
    final cases =
        <
          String,
          ({
            Widget Function({required bool on, Motion? instance}) build,
            Track<Object> track,
          })
        >{
          'checkbox glyph': (
            build: ({required on, instance}) => CoilCheckbox(
              value: on,
              onChanged: (_) {},
              motions: instance == null
                  ? null
                  : {CoilCheckboxTrack.glyph: instance},
            ),
            track: CoilCheckboxTrack.glyph,
          ),
          'switch thumb': (
            build: ({required on, instance}) => CoilSwitch(
              value: on,
              onChanged: (_) {},
              motions: instance == null
                  ? null
                  : {CoilSwitchTrack.thumb: instance},
            ),
            track: CoilSwitchTrack.thumb,
          ),
          'switch label': (
            build: ({required on, instance}) => CoilSwitch(
              value: on,
              onChanged: (_) {},
              label: const Text('Wi-Fi'),
              motions: instance == null
                  ? null
                  : {CoilSwitchTrack.label: instance},
            ),
            track: CoilSwitchTrack.label,
          ),
          'radio dot': (
            build: ({required on, instance}) => CoilRadioGroup<int>(
              value: on ? 1 : 0,
              onChanged: (_) {},
              options: _plans,
              motions: instance == null
                  ? null
                  : {CoilRadioGroupTrack.dot: instance},
            ),
            track: CoilRadioGroupTrack.dot,
          ),
          'checkbox group selection': (
            build: ({required on, instance}) => CoilCheckboxGroup<int>(
              values: on ? const {0, 1} : const {0},
              onChanged: (_) {},
              options: _plans,
              motions: instance == null
                  ? null
                  : {CoilCheckboxGroupTrack.selection: instance},
            ),
            track: CoilCheckboxGroupTrack.selection,
          ),
          'toggle group selection': (
            build: ({required on, instance}) => CoilToggleGroup<int>(
              values: on ? const {0, 1} : const {0},
              onChanged: (_) {},
              options: _plans,
              motions: instance == null
                  ? null
                  : {CoilToggleGroupTrack.selection: instance},
            ),
            track: CoilToggleGroupTrack.selection,
          ),
          'button fill': (
            build: ({required on, instance}) => CoilButton(
              onPressed: () {},
              selected: on,
              variant: CoilButtonVariant.ghost,
              motions: instance == null
                  ? null
                  : {CoilButtonTrack.fill: instance},
              child: const Text('Open'),
            ),
            track: CoilButtonTrack.fill,
          ),
        };

    for (final MapEntry(key: name, value: c) in cases.entries) {
      testWidgets('$name: instance beats theme beats token', (tester) async {
        Future<Duration> flip({Motion? theme, Motion? instance}) async {
          final data = CoilThemeData.light.copyWith(
            trackMotions: {if (theme != null) c.track: theme},
          );
          await _pump(
            tester,
            c.build(on: false, instance: instance),
            theme: data,
          );
          return _settleTime(
            tester,
            () => _pump(
              tester,
              c.build(on: true, instance: instance),
              theme: data,
            ),
          );
        }

        const long = Duration(milliseconds: 2500);
        expect(await flip(theme: _linear(3000)), greaterThan(long));
        expect(await flip(instance: _linear(3000)), greaterThan(long));
        expect(
          await flip(theme: _linear(3000), instance: _linear(500)),
          lessThan(const Duration(milliseconds: 1500)),
        );
      });
    }

    testWidgets('a theme motion change applies to the next animation', (
      tester,
    ) async {
      Widget radio(int value) => CoilRadioGroup<int>(
        value: value,
        onChanged: (_) {},
        options: _plans,
      );
      final slow = CoilThemeData.light.copyWith(
        motion: const CoilMotion().copyWith(standard: _linear(3000)),
      );
      await _pump(tester, radio(0));
      final fast = await _settleTime(tester, () => _pump(tester, radio(1)));
      await _pump(tester, radio(0), theme: slow);
      final slowed = await _settleTime(
        tester,
        () => _pump(tester, radio(1), theme: slow),
      );
      expect(slowed, greaterThan(fast + const Duration(seconds: 1)));
    });

    testWidgets('a skeleton fades in on its track motion', (tester) async {
      final data = CoilThemeData.light.copyWith(
        trackMotions: {CoilSkeletonTrack.appear: _linear(3000)},
      );
      Future<void> show() => _pump(
        tester,
        const CoilSkeleton(width: 40, height: 10),
        theme: data,
        reduceMotion: true,
      );
      expect(
        await _settleTime(tester, show),
        greaterThan(const Duration(milliseconds: 2500)),
      );
    });
  });
}
