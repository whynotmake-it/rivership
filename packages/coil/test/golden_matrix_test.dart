// Every component across the golden matrix: light/dark × pointer/touch, each
// at text scale 1, 1.5 and 2, in RTL and in high contrast. Real fonts
// (Inter, loaded in flutter_test_config.dart), rendered at 2x.
import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_matrix.dart';
import 'src/select_harness.dart';
import 'src/test_icons.dart';

/// The component stories. Each builds the component at rest.
final Map<String, WidgetBuilder> _stories = {
  'button': (context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      CoilButton(
        onPressed: () {},
        leading: const TestIcon(TestGlyph.plus),
        child: const Text('New file'),
      ),
      CoilButton(
        onPressed: () {},
        variant: CoilButtonVariant.secondary,
        child: const Text('Cancel'),
      ),
      CoilButton(
        onPressed: () {},
        variant: CoilButtonVariant.tertiary,
        trailing: const TestIcon(TestGlyph.arrowRight),
        child: const Text('Next'),
      ),
    ],
  ),
  'button_states': (context) => MediaQuery(
    // The spinner is a loop, which would never settle.
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        CoilButton(
          onPressed: () {},
          loading: true,
          leading: const TestIcon(TestGlyph.plus),
          child: const Text('Saving'),
        ),
        CoilButton(
          onPressed: () {},
          loading: true,
          variant: CoilButtonVariant.secondary,
          child: const Text('Loading'),
        ),
        CoilButton(
          onPressed: () {},
          selected: true,
          variant: CoilButtonVariant.ghost,
          child: const Text('Open'),
        ),
        CoilButton.icon(
          onPressed: () {},
          variant: CoilButtonVariant.destructive,
          semanticLabel: 'Delete',
          icon: const TestIcon(TestGlyph.plus),
        ),
        CoilButton.icon(
          onPressed: () {},
          loading: true,
          variant: CoilButtonVariant.tertiary,
          semanticLabel: 'Add',
          icon: const TestIcon(TestGlyph.plus),
        ),
      ],
    ),
  ),
  'badge': (context) => SizedBox(
    width: 300,
    // A ghost badge inherits the surrounding text color.
    child: DefaultTextStyle.merge(
      style: TextStyle(color: CoilTheme.of(context).colors.foreground),
      child: const Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CoilBadge(child: Text('Draft')),
          CoilBadge(color: CoilBadgeColor.brand, child: Text('New')),
          CoilBadge(color: CoilBadgeColor.green, child: Text('Paid')),
          CoilBadge(color: CoilBadgeColor.rose, child: Text('Failed')),
          CoilBadge(
            variant: CoilBadgeVariant.dot,
            color: CoilBadgeColor.amber,
            child: Text('Pending'),
          ),
          CoilBadge(variant: CoilBadgeVariant.dot, child: Text('Archived')),
          CoilBadge(
            variant: CoilBadgeVariant.ghost,
            color: CoilBadgeColor.blue,
            child: Text('Syncing'),
          ),
          CoilBadge(
            size: CoilSize.compact,
            color: CoilBadgeColor.violet,
            child: Text('Beta'),
          ),
          CoilBadge(
            size: CoilSize.compact,
            variant: CoilBadgeVariant.dot,
            color: CoilBadgeColor.teal,
            child: Text('Live'),
          ),
        ],
      ),
    ),
  ),
  'skeleton': (context) => MediaQuery(
    // The pulse is a loop, which would never settle.
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: const SizedBox(
      width: 240,
      child: Row(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoilSkeleton(width: 40, height: 40),
          Expanded(child: CoilSkeletonText()),
        ],
      ),
    ),
  ),
  'checkbox': (context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CoilCheckbox(value: true, onChanged: (_) {}),
      const SizedBox(width: 12),
      CoilCheckbox(value: false, onChanged: (_) {}),
      const SizedBox(width: 12),
      CoilCheckbox(value: null, tristate: true, onChanged: (_) {}),
      const SizedBox(width: 12),
      const CoilCheckbox(value: false, onChanged: null),
    ],
  ),
  'switch': (context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CoilSwitch(value: true, onChanged: (_) {}, label: const Text('Wi-Fi')),
      CoilSwitch(value: false, onChanged: (_) {}, label: const Text('Sync')),
    ],
  ),
  'tabs': (context) => CoilTabs(
    tabs: const [
      CoilTab(value: 0, label: 'Overview', icon: TestIcon(TestGlyph.home)),
      CoilTab(value: 1, label: 'Analytics', icon: TestIcon(TestGlyph.heart)),
      CoilTab(value: 2, label: 'Settings', icon: TestIcon(TestGlyph.settings)),
    ],
    value: 1,
    onChanged: (_) {},
  ),
  'slider': (context) => SizedBox(
    width: 260,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        CoilSlider(
          value: .42,
          onChanged: (_) {},
          label: const Text('Volume'),
          valueFormatter: (v) => '${(v * 100).round()}%',
        ),
        CoilSlider(
          value: .5,
          divisions: 4,
          variant: CoilSliderVariant.pips,
          onChanged: (_) {},
          label: const Text('Quality'),
          valueFormatter: (v) => '${(v * 4).round()}',
        ),
        CoilSlider(
          value: .65,
          variant: CoilSliderVariant.pill,
          onChanged: (_) {},
          label: const Text('Zoom'),
          valueFormatter: (v) => '${(v * 100).round()}%',
        ),
        const CoilSlider(value: .3, onChanged: null),
      ],
    ),
  ),
  'tabs_overflow': (context) => SizedBox(
    width: 260,
    child: CoilTabs(
      tabs: [
        for (var i = 0; i < 8; i++) CoilTab(value: i, label: 'Section $i'),
      ],
      value: 3,
      onChanged: (_) {},
    ),
  ),
  'input': (context) => SizedBox(
    width: 240,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CoilInput(
          placeholder: Text('Search'),
          leading: TestIcon(TestGlyph.search),
        ),
        const SizedBox(height: 8),
        CoilInput(
          controller: TextEditingController(text: 'ada@example.com'),
          invalid: true,
        ),
      ],
    ),
  ),
  'textarea': (context) => SizedBox(
    width: 240,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CoilInput.multiline(placeholder: Text('Tell us more')),
        const SizedBox(height: 8),
        CoilInput.multiline(
          minLines: 1,
          controller: TextEditingController(
            text: 'Two lines of text that wrap',
          ),
          invalid: true,
        ),
      ],
    ),
  ),
  'field': (context) => SizedBox(
    width: 240,
    child: CoilFieldGroup(
      children: [
        const CoilField(
          label: Text('Name'),
          description: Text('As on your ID.'),
          isRequired: true,
          child: CoilInput(),
        ),
        CoilField(
          label: const Text('Email'),
          error: const Text('Enter an email address'),
          child: CoilInput(controller: TextEditingController(text: 'ada@')),
        ),
        const CoilFieldSeparator(label: Text('or')),
      ],
    ),
  ),
  'input_group': (context) => const SizedBox(
    width: 240,
    child: CoilInputGroup(
      children: [
        CoilField(
          label: Text('Search'),
          child: CoilInput(leading: TestIcon(TestGlyph.search)),
        ),
        CoilField(label: Text('Website'), child: CoilInput()),
      ],
    ),
  ),
  'input_copy': (context) => const SizedBox(
    width: 240,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoilField(
          label: Text('API key'),
          child: CoilInputCopy(
            value: 'sk-live-0123456789',
            icon: TestIcon(TestGlyph.plus),
          ),
        ),
        CoilInputCopy(
          value: 'npm i coil',
          variant: CoilInputCopyVariant.button,
          icon: TestIcon(TestGlyph.plus),
        ),
      ],
    ),
  ),
  'selection_groups': (context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 220,
        child: CoilCheckboxGroup(
          values: const {0, 1},
          onChanged: (_) {},
          options: const [
            CoilOption(value: 0, label: 'Email'),
            CoilOption(value: 1, label: 'Push'),
            CoilOption(value: 2, label: 'SMS'),
          ],
        ),
      ),
      const SizedBox(height: 8),
      CoilToggleGroup(
        values: const {0, 1},
        onChanged: (_) {},
        options: const [
          CoilOption(value: 0, label: 'Bold'),
          CoilOption(value: 1, label: 'Italic'),
          CoilOption(value: 2, label: 'Underline'),
        ],
      ),
    ],
  ),
  'radio_group': (context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 220,
        child: CoilRadioGroup(
          value: 1,
          onChanged: (_) {},
          options: const [
            CoilOption(value: 0, label: 'Free'),
            CoilOption(value: 1, label: 'Team'),
            CoilOption(value: 2, label: 'Enterprise', enabled: false),
          ],
        ),
      ),
    ],
  ),
  'select': (context) => SizedBox(
    width: 220,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoilSelect<String>(options: fruits, value: 'banana', onChanged: (_) {}),
        const SizedBox(height: 8),
        CoilSelect<String>(options: fruits, value: null, onChanged: (_) {}),
      ],
    ),
  ),
};

void main() {
  for (final MapEntry(key: name, value: story) in _stories.entries) {
    matrixGoldenTest(name, story);
  }

  // The open select in both presentations, light and dark.
  for (final (name, colors) in [
    ('light', CoilColors.light),
    ('dark', CoilColors.dark),
  ]) {
    testWidgets('select popover open ($name, pointer)', (tester) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(
          home: const SelectDemo(),
          tier: CoilTier.pointer,
          colors: colors,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('select')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/matrix/select_popover_$name.png'),
      );
    });

    testWidgets('select sheet open ($name, touch)', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          home: const SelectDemo(options: moreFruits),
          tier: CoilTier.touch,
          colors: colors,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('select')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/matrix/select_sheet_$name.png'),
      );
    });
  }
}
