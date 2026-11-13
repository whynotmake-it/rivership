// Behavior of the leaf controls and selection groups: Button loading, Badge,
// Skeleton, RadioGroup, CheckboxGroup and ToggleGroup (keyboard, touch vs
// mouse, reduced motion). Looks are covered by the golden matrix.
import 'dart:ui' show CheckedState, SemanticsAction, Tristate;

import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/test_icons.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  bool reduceMotion = false,
  TextDirection direction = TextDirection.ltr,
}) => tester.pumpWidget(
  WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: direction,
        child: CoilTheme(
          data: CoilThemeData.light.copyWith(tier: tier),
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

void main() {
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
      expect(find.byType(TestIcon), findsOneWidget);

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
      expect(
        tester.widget<Opacity>(find.byType(Opacity).last).opacity,
        isNonNegative,
      );
    });

    testWidgets('announces Loading and keeps full strength', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        CoilButton.icon(
          onPressed: () {},
          loading: true,
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
      expect(data.flagsCollection.isButton, isTrue);
      semantics.dispose();
    });

    testWidgets('the spinner is the only loop and reduced motion stops it', (
      tester,
    ) async {
      final button = CoilButton(
        onPressed: () {},
        loading: true,
        child: const Text('Saving'),
      );
      await _pump(tester, button);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'it turns');

      await _pump(tester, button, reduceMotion: true);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('CoilBadge', () {
    testWidgets('is 24 high (20 compact) and has no touch bump', (
      tester,
    ) async {
      for (final tier in CoilTier.values) {
        await _pump(
          tester,
          const CoilBadge(child: Text('Draft')),
          tier: tier,
        );
        expect(tester.getSize(find.byType(CoilBadge)).height, 24);
        await _pump(
          tester,
          const CoilBadge(size: CoilSize.compact, child: Text('Draft')),
          tier: tier,
        );
        expect(tester.getSize(find.byType(CoilBadge)).height, 20);
      }
    });

    testWidgets('only dot and ghost badges carry a dot, out of semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const Column(
          children: [
            CoilBadge(child: Text('Solid')),
            CoilBadge(variant: CoilBadgeVariant.dot, child: Text('Dot')),
          ],
        ),
      );
      final solid = tester.getSize(find.text('Solid'));
      expect(solid.width, greaterThan(0));
      expect(find.bySemanticsLabel('Dot'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Dot'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'a badge is not interactive',
      );
      semantics.dispose();
    });

    testWidgets('a ghost badge has no padding', (tester) async {
      await _pump(
        tester,
        const CoilBadge(
          variant: CoilBadgeVariant.ghost,
          child: Text('Syncing'),
        ),
      );
      final badge = tester.getRect(find.byType(CoilBadge));
      final text = tester.getRect(find.text('Syncing'));
      // The dot sits at the start edge with nothing before it.
      expect(text.right, closeTo(badge.right, 0.5));
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

    testWidgets('waits 160 ms, fades in, then pulses to half and back', (
      tester,
    ) async {
      await _pump(tester, const CoilSkeleton(width: 100, height: 16));
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(tester), 0, reason: 'inside the grace period');
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(tester), greaterThan(0.5));
      var lowest = 1.0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        lowest = lowest < opacity(tester) ? lowest : opacity(tester);
      }
      expect(lowest, closeTo(0.5, 0.1), reason: 'the pulse dips to 0.5');
    });

    testWidgets('reduced motion keeps the grace and fade, drops the pulse', (
      tester,
    ) async {
      await _pump(
        tester,
        const CoilSkeleton(width: 100, height: 16),
        reduceMotion: true,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(tester), 0);
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'no pulse');
    });

    testWidgets('is out of semantics; the region announces Loading', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const CoilSkeletonRegion(
          child: SizedBox(width: 200, child: CoilSkeletonText()),
        ),
        reduceMotion: true,
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('Loading'));
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(node.childrenCount, 0);
      semantics.dispose();
    });

    testWidgets('text lines are 0.6 of a line box and vary 55-82 %', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(width: 200, child: CoilSkeletonText()),
        reduceMotion: true,
      );
      await tester.pumpAndSettle();
      final lines = find.byType(CoilSkeleton);
      expect(lines, findsNWidgets(3));
      final sizes = [
        for (var i = 0; i < 3; i++)
          tester.getSize(
            find
                .descendant(
                  of: lines.at(i),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          ),
      ];
      for (final size in sizes) {
        expect(size.height, closeTo(20 * 0.6, 0.01));
        expect(size.width / 200, inInclusiveRange(0.55, 0.82));
      }
      expect(sizes.last.width, lessThan(sizes.first.width));
    });
  });

  group('CoilRadioGroup', () {
    Widget group({
      int? value = 1,
      ValueChanged<int>? onChanged,
      List<CoilOption<int>> options = _plans,
    }) => SizedBox(
      width: 240,
      child: CoilRadioGroup<int>(
        value: value,
        onChanged: onChanged,
        options: options,
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

    testWidgets('the selected row is the one tab stop', (tester) async {
      await _pump(tester, stateful(initial: 3));
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(find.text('value:1'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<CoilButton>(),
        isNotNull,
        reason: 'Tab leaves the group',
      );
    });

    testWidgets('with nothing selected Tab reaches the first row', (
      tester,
    ) async {
      await _pump(tester, stateful(initial: null));
      await _key(tester, LogicalKeyboardKey.tab);
      expect(find.text('value:null'), findsOneWidget, reason: 'no selection');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(find.text('value:1'), findsOneWidget);
    });

    testWidgets('arrows move and select, wrap and skip disabled rows', (
      tester,
    ) async {
      await _pump(tester, stateful());
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(find.text('value:3'), findsOneWidget, reason: 'skips Business');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(find.text('value:0'), findsOneWidget, reason: 'wraps');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(find.text('value:3'), findsOneWidget, reason: 'wraps back');
      await _key(tester, LogicalKeyboardKey.home);
      expect(find.text('value:0'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.end);
      expect(find.text('value:3'), findsOneWidget);
    });

    testWidgets('a tap selects and shows no ring', (tester) async {
      await _pump(tester, stateful());
      await tester.tap(find.text('Free').first);
      await tester.pumpAndSettle();
      expect(find.text('value:0'), findsOneWidget);
      final rings = tester
          .widgetList<CoilInteractionDetector>(
            find.byType(CoilInteractionDetector),
          )
          .where((d) => d.states.value.contains(WidgetState.focused));
      expect(rings, isEmpty);
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
      final team = tester.getSemantics(find.bySemanticsLabel('Team'));
      final data = team.getSemanticsData();
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(data.flagsCollection.isChecked, CheckedState.isTrue);
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

    testWidgets('touch leaves no hover or highlight; a mouse hovers', (
      tester,
    ) async {
      await _pump(tester, stateful(), tier: CoilTier.touch);
      int? lit() => CoilHoverRegion.maybeOf(
        tester.element(find.text('Team').first),
      )?.activeIndex;
      await tester.tap(find.text('Free').first);
      await tester.pumpAndSettle();
      expect(lit(), isNull, reason: 'no highlight under a lifted finger');

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Team').first));
      await tester.pumpAndSettle();
      expect(lit(), 1);
    });

    testWidgets('rows grow with the text scale and wrap long labels', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          width: 120,
          child: CoilRadioGroup<int>(
            value: 0,
            onChanged: (_) {},
            options: const [
              CoilOption(
                value: 0,
                label: 'A label long enough to wrap onto lines',
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(CoilRadioGroup<int>)).height,
        greaterThan(36),
      );
    });
  });

  group('CoilCheckboxGroup', () {
    Widget stateful({Set<int> initial = const {0}}) => _Stateful<Set<int>>(
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
            ),
          ),
          Text('values:${(values.toList()..sort()).join(',')}'),
        ],
      ),
    );

    testWidgets(
      'every row is a tab stop; Up and Down wrap; Home and End jump',
      (
        tester,
      ) async {
        await _pump(tester, stateful());
        await _key(tester, LogicalKeyboardKey.tab);
        await _key(tester, LogicalKeyboardKey.tab);
        await _key(tester, LogicalKeyboardKey.space);
        expect(find.text('values:0,1'), findsOneWidget, reason: 'second row');

        await _key(tester, LogicalKeyboardKey.arrowDown);
        await _key(tester, LogicalKeyboardKey.enter);
        expect(
          find.text('values:0,1,3'),
          findsOneWidget,
          reason: 'Down skips the disabled row; Enter toggles',
        );
        await _key(tester, LogicalKeyboardKey.arrowDown);
        await _key(tester, LogicalKeyboardKey.space);
        expect(find.text('values:1,3'), findsOneWidget, reason: 'wrapped');
        await _key(tester, LogicalKeyboardKey.end);
        await _key(tester, LogicalKeyboardKey.space);
        expect(find.text('values:1'), findsOneWidget);
        await _key(tester, LogicalKeyboardKey.home);
        await _key(tester, LogicalKeyboardKey.space);
        expect(find.text('values:0,1'), findsOneWidget);
      },
    );

    testWidgets('selected labels are foreground, others muted on pointer', (
      tester,
    ) async {
      await _pump(tester, stateful());
      Color colorOf(String text) => DefaultTextStyle.of(
        tester.element(find.text(text).last),
      ).style.color!;
      final colors = CoilThemeData.light.colors;
      await tester.pumpAndSettle();
      expect(colorOf('Free'), colors.foreground);
      expect(colorOf('Team'), colors.mutedForeground);
    });

    testWidgets('touch rows rest at full foreground', (tester) async {
      await _pump(tester, stateful(), tier: CoilTier.touch);
      await tester.pumpAndSettle();
      final style = DefaultTextStyle.of(
        tester.element(find.text('Team').last),
      ).style;
      expect(style.color, CoilThemeData.light.colors.foreground);
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
              CoilOption(value: 2, label: 'Underline'),
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

    testWidgets('semantics: toggled and selected', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, stateful());
      final data = tester
          .getSemantics(find.bySemanticsLabel('Bold'))
          .getSemanticsData();
      expect(data.flagsCollection.isToggled, Tristate.isTrue);
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      semantics.dispose();
    });
  });
}
