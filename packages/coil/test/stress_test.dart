// A robustness sweep: every component under hostile content and hostile
// screens. It asserts only that nothing throws (no overflow, no layout or
// build errors); goldens cover how things look.
import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';
import 'src/test_icons.dart';

/// Content that tends to break layouts.
enum Hostile {
  /// Empty strings and no items.
  empty,

  /// Sentences that wrap many times, and 150 items.
  long,

  /// One 200-character word and a long URL: nothing to break a line at.
  unbroken,

  /// Emoji, CJK and Arabic mixed in one string.
  scripts;

  String get text => switch (this) {
    empty => '',
    long =>
      'A rather long piece of text that keeps going well past the edge of '
          'any phone, so that it has to wrap onto several lines, and then '
          'some more for good measure.',
    unbroken =>
      'https://example.com/${'W' * 120}/a-very-long-path?with=query&and='
          '${'x' * 60}',
    scripts => '👩‍👩‍👧‍👦 你好，世界 مرحبا بالعالم 🎉 東京都 السلام عليكم',
  };

  /// Shorter text for things that are usually one word: tabs, crumbs.
  String get short => switch (this) {
    long => 'Quite a long label for this',
    _ => text,
  };

  /// How many items a collection gets.
  int get count => switch (this) {
    empty => 0,
    long => 150,
    unbroken => 3,
    scripts => 12,
  };
}

/// One screen to pump a story on.
@immutable
class StressScreen {
  const StressScreen(
    this.name, {
    required this.size,
    required this.platform,
    this.textScale = 1,
    this.tier = CoilTier.touch,
    this.brightness = Brightness.light,
    this.direction = TextDirection.ltr,
  });

  final String name;
  final Size size;
  final TargetPlatform platform;
  final double textScale;
  final CoilTier tier;
  final Brightness brightness;
  final TextDirection direction;
}

const screens = [
  StressScreen(
    'iOS 320 2x',
    size: Size(320, 640),
    platform: TargetPlatform.iOS,
    textScale: 2,
  ),
  StressScreen(
    'Android 240 2x RTL dark',
    size: Size(240, 600),
    platform: TargetPlatform.android,
    textScale: 2,
    brightness: Brightness.dark,
    direction: TextDirection.rtl,
  ),
  StressScreen(
    'Android 360 3x short',
    size: Size(360, 360),
    platform: TargetPlatform.android,
    textScale: 3,
  ),
  StressScreen(
    'iOS 320 1x RTL',
    size: Size(320, 568),
    platform: TargetPlatform.iOS,
    direction: TextDirection.rtl,
  ),
  StressScreen(
    'pointer 240 2x short dark',
    size: Size(240, 240),
    platform: TargetPlatform.macOS,
    textScale: 2,
    tier: CoilTier.pointer,
    brightness: Brightness.dark,
  ),
  StressScreen(
    'pointer 1600',
    size: Size(1600, 900),
    platform: TargetPlatform.macOS,
    tier: CoilTier.pointer,
  ),
];

/// Where a story sits on the screen.
enum StressHost {
  /// In a vertical scroll view, as wide as the screen.
  scroll,

  /// Given the whole screen.
  fill,
}

const _trigger = ValueKey('stress-trigger');

/// Marks the widget [StressStory.open] taps.
Widget trigger(Widget child) => KeyedSubtree(key: _trigger, child: child);

/// A component under test.
class StressStory {
  const StressStory(
    this.name,
    this.build, {
    this.host = StressHost.scroll,
    this.open = false,
    this.knownBreakage = const {},
  });

  final String name;
  final Widget Function(BuildContext context, Hostile h) build;
  final StressHost host;

  /// Taps the [trigger] after pumping, to stress an overlay.
  final bool open;

  /// Screens this story is known to break on, by [StressScreen.name], with
  /// why. Those tests are skipped until the component is fixed.
  ///
  /// No story needs it today; it's kept for documenting known breakage.
  final Map<String, String> knownBreakage;
}

Widget _host(StressScreen screen, StressStory story, Hostile h) {
  final theme = screen.brightness == Brightness.light
      ? goldenLight
      : goldenDark;
  return WidgetsApp(
    color: const Color(0xFF000000),
    debugShowCheckedModeBanner: false,
    builder: (context, navigator) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(screen.textScale),
        platformBrightness: screen.brightness,
      ),
      child: Directionality(
        textDirection: screen.direction,
        child: CoilTheme(
          data: theme,
          child: CoilAdaptiveScope(tier: screen.tier, child: navigator!),
        ),
      ),
    ),
    onGenerateRoute: (_) => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => ColoredBox(
        color: CoilTheme.of(context).colors.background,
        child: switch (story.host) {
          StressHost.scroll => SingleChildScrollView(
            child: Builder(builder: (context) => story.build(context, h)),
          ),
          StressHost.fill => Builder(
            builder: (context) => story.build(context, h),
          ),
        },
      ),
    ),
  );
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Shows [story] with [h] on [screen] and opens it if it has an overlay.
/// Sets the view and the target platform; the caller resets the platform.
Future<void> pumpStory(
  WidgetTester tester,
  StressScreen screen,
  StressStory story,
  Hostile h,
) async {
  tester.view
    ..physicalSize = screen.size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = screen.platform;
  await tester.pumpWidget(_host(screen, story, h));
  await _frames(tester);
  if (!story.open) return;
  final target = find.byKey(_trigger);
  if (screen.tier == CoilTier.pointer) {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(target));
    await tester.pump();
    await mouse.down(tester.getCenter(target));
    await tester.pump();
    await mouse.up();
    await mouse.removePointer();
  } else {
    await tester.tap(target);
  }
  await _frames(tester);
}

/// Pumps [story] with every [Hostile] content on [screen] and fails with
/// every error it saw.
Future<void> stress(
  WidgetTester tester,
  StressScreen screen,
  StressStory story,
) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  try {
    for (final h in Hostile.values) {
      FlutterError.onError = (details) {
        final message = details.exceptionAsString().split('\n').first;
        // Where the failing widget was created, in coil's own source.
        final where = RegExp(
          r'lib/src/[\w/]+\.dart:\d+',
        ).firstMatch(details.toString())?.group(0);
        errors.add('${h.name}: $message${where == null ? '' : ' at $where'}');
      };
      try {
        await pumpStory(tester, screen, story, h);
      } on Object catch (error) {
        errors.add('${h.name}: threw ${error.toString().split('\n').first}');
      }
      // Unmount between contents so no state carries over.
      await tester.pumpWidget(const SizedBox());
      await _frames(tester);
    }
  } finally {
    FlutterError.onError = previous;
    debugDefaultTargetPlatformOverride = null;
  }
  expect(errors, isEmpty, reason: '${story.name} on ${screen.name}');
}

Widget _icon([TestGlyph glyph = TestGlyph.heart]) => TestIcon(glyph);

Text _t(String text) => Text(text);

List<CoilOption<int>> _options(Hostile h) => [
  for (var i = 0; i < h.count; i++)
    CoilOption(
      value: i,
      label: Text(i.isEven ? h.text : '${h.short} $i'),
      searchText: '${h.short} $i',
      icon: i % 3 == 0 ? _icon() : null,
    ),
];

List<CoilMenuEntry> _entries(Hostile h) => [
  if (h != Hostile.empty) CoilMenuLabel(_t(h.short)),
  for (var i = 0; i < h.count; i++)
    CoilAction(
      label: _t(i.isEven ? h.text : '${h.short} $i'),
      searchText: '${h.short} $i',
      leading: i % 3 == 0 ? _icon() : null,
      shortcut: i % 4 == 0 ? CoilKbd('⇧⌘K') : null,
      onPressed: () {},
    ),
  if (h.count > 2) const CoilMenuSeparator(),
  if (h.count > 2)
    CoilSubmenu(
      label: _t(h.text),
      entries: [CoilAction(label: _t(h.text), onPressed: () {})],
    ),
];

final stories = <StressStory>[
  StressStory(
    'banner',
    (context, h) => Column(
      spacing: 8,
      children: [
        CoilBanner(title: _t(h.text)),
        CoilBanner(
          icon: _icon(),
          title: _t(h.text),
          onDismissRequested: () {},
          actions: [
            CoilButton(onPressed: () {}, child: _t(h.short)),
            CoilButton(
              onPressed: () {},
              variant: CoilButtonVariant.ghost,
              child: const Text('Later'),
            ),
          ],
        ),
        CoilBanner(
          icon: _icon(),
          title: _t(h.text),
          description: _t(h.text),
          onDismissRequested: () {},
          actions: [
            for (var i = 0; i < h.count.clamp(0, 6); i++)
              CoilButton(onPressed: () {}, child: Text('${h.short} $i')),
          ],
        ),
        CoilBanner(
          placement: CoilBannerPlacement.fixed,
          status: CoilBannerStatus.destructive,
          variant: CoilBannerVariant.tinted,
          icon: _icon(),
          title: _t(h.text),
          onDismissRequested: () {},
          actions: [CoilButton(onPressed: () {}, child: _t(h.text))],
        ),
      ],
    ),
  ),
  StressStory(
    'button',
    (context, h) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        CoilButton(onPressed: () {}, child: _t(h.text)),
        CoilButton(
          onPressed: () {},
          leading: _icon(TestGlyph.plus),
          trailing: _icon(TestGlyph.arrowRight),
          variant: CoilButtonVariant.secondary,
          child: _t(h.text),
        ),
        CoilButton(
          onPressed: () {},
          loading: true,
          variant: CoilButtonVariant.tertiary,
          child: _t(h.text),
        ),
        CoilButton.icon(
          onPressed: () {},
          icon: _icon(),
          semanticLabel: h.text,
        ),
      ],
    ),
  ),
  StressStory(
    'badge and kbd',
    (context, h) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        CoilBadge(child: _t(h.text)),
        CoilBadge(variant: CoilBadgeVariant.values.last, child: _t(h.short)),
        CoilKbd(h == Hostile.empty ? '' : '⇧⌘${h.short}'),
        CoilKbd.keys([for (var i = 0; i < h.count.clamp(0, 12); i++) 'Ctrl']),
      ],
    ),
  ),
  StressStory(
    'skeleton',
    (context, h) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        CoilSkeletonText(lines: h.count.clamp(1, 20)),
        const CoilSkeleton(width: 2000, height: 40),
        const CoilSkeleton.text(widthFactor: 0.5),
      ],
    ),
  ),
  StressStory(
    'checkbox, switch, choice card',
    (context, h) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        CoilCheckbox(value: true, onChanged: (_) {}),
        CoilSwitch(value: true, onChanged: (_) {}, label: _t(h.text)),
        CoilChoiceCard(
          control: CoilCheckbox(value: false, onChanged: (_) {}),
          title: _t(h.text),
          description: _t(h.text),
        ),
      ],
    ),
  ),
  StressStory(
    'input and textarea',
    (context, h) => Column(
      spacing: 8,
      children: [
        CoilInput(
          controller: TextEditingController(text: h.text),
          placeholder: _t(h.text),
          leading: _icon(TestGlyph.search),
          trailing: CoilKbd('⌘K'),
        ),
        CoilInput(placeholder: _t(h.text)),
        CoilInput.multiline(
          controller: TextEditingController(text: h.text * 3),
          placeholder: _t(h.text),
        ),
        CoilInputGroup(
          children: [
            CoilField(label: _t(h.short), child: const CoilInput()),
            CoilField(label: _t(h.text), child: const CoilInput()),
          ],
        ),
      ],
    ),
  ),
  StressStory(
    'field',
    (context, h) => Column(
      spacing: 16,
      children: [
        CoilField(
          label: _t(h.text),
          description: _t(h.text),
          error: _t(h.text),
          errorIcon: _icon(TestGlyph.x),
          invalid: true,
          isRequired: true,
          child: CoilInput(placeholder: _t(h.text)),
        ),
        CoilField(
          orientation: CoilFieldOrientation.horizontal,
          label: _t(h.text),
          description: _t(h.text),
          child: CoilSwitch(value: false, onChanged: (_) {}),
        ),
        CoilFieldSet(
          legend: _t(h.text),
          description: _t(h.text),
          children: [
            CoilField(label: _t(h.short), child: const CoilInput()),
          ],
        ),
      ],
    ),
  ),
  StressStory(
    'checkbox group and radio group',
    (context, h) => Column(
      spacing: 16,
      children: [
        CoilCheckboxGroup(
          options: _options(h),
          values: const {0, 2},
          onChanged: (_) {},
        ),
        CoilRadioGroup(options: _options(h), value: 1, onChanged: (_) {}),
      ],
    ),
  ),
  StressStory(
    'slider',
    (context, h) => Column(
      spacing: 16,
      children: [
        CoilSlider(value: 0.4, onChanged: (_) {}, label: _t(h.text)),
        CoilSlider(
          value: 0.4,
          onChanged: (_) {},
          label: _t(h.text),
          variant: CoilSliderVariant.pill,
          valueDisplay: CoilSliderValueDisplay.editable,
          valueBuilder: (context, value) => _t('${h.short} $value'),
        ),
        CoilRangeSlider(
          values: const CoilRangeValues(0.2, 0.8),
          onChanged: (_) {},
          label: _t(h.text),
        ),
      ],
    ),
  ),
  StressStory(
    'toggle group',
    (context, h) => CoilToggleGroup(
      options: _options(h),
      values: const {1},
      onChanged: (_) {},
    ),
  ),
  StressStory(
    'tabs',
    (context, h) => CoilTabs(
      tabs: [
        for (var i = 0; i < h.count.clamp(1, 40); i++)
          CoilTab(
            value: i,
            label: _t('${h.short} $i'),
            icon: i.isEven ? _icon() : null,
          ),
      ],
      value: 0,
      onChanged: (_) {},
    ),
  ),
  StressStory(
    'select',
    (context, h) => trigger(
      CoilSelect<int>(
        options: _options(h),
        value: h.count > 0 ? 0 : null,
        onChanged: (_) {},
        placeholder: _t(h.text),
        icon: _icon(),
      ),
    ),
    open: true,
  ),
  StressStory(
    'multi select',
    (context, h) => trigger(
      CoilMultiSelect<int>(
        options: _options(h),
        values: {for (var i = 0; i < h.count.clamp(0, 20); i++) i},
        onChanged: (_) {},
        placeholder: _t(h.text),
      ),
    ),
    open: true,
  ),
  StressStory(
    'combobox',
    (context, h) => trigger(
      CoilCombobox<int>(
        options: _options(h),
        value: h.count > 0 ? 0 : null,
        onChanged: (_) {},
        placeholder: _t(h.text),
        empty: _t(h.text),
      ),
    ),
    open: true,
  ),
  StressStory(
    'multi combobox',
    (context, h) => trigger(
      CoilMultiCombobox<int>(
        options: _options(h),
        values: {for (var i = 0; i < h.count.clamp(0, 20); i++) i},
        onChanged: (_) {},
        placeholder: _t(h.text),
      ),
    ),
    open: true,
  ),
  StressStory(
    'dropdown',
    (context, h) => CoilDropdown(
      entries: _entries(h),
      search: CoilMenuSearch(placeholder: _t(h.text), empty: _t(h.text)),
      builder: (context, menu) => trigger(
        CoilButton(onPressed: menu.open, child: _t(h.short)),
      ),
    ),
    open: true,
  ),
  StressStory(
    'tooltip',
    (context, h) => Center(
      child: CoilTooltip(
        message: _t(h.text),
        shortcut: CoilKbd('⌘K'),
        child: trigger(CoilButton(onPressed: () {}, child: _t(h.short))),
      ),
    ),
    open: true,
  ),
  StressStory(
    'dialog',
    (context, h) => trigger(
      CoilButton(
        onPressed: () => showCoilDialog<void>(
          context: context,
          builder: (context) => CoilDialog(
            title: _t(h.text),
            description: _t(h.text),
            onClose: () {},
            actions: [
              CoilButton(
                onPressed: () {},
                variant: CoilButtonVariant.secondary,
                child: _t(h.short),
              ),
              CoilButton(onPressed: () {}, child: _t(h.text)),
            ],
            child: Column(
              children: [
                for (var i = 0; i < h.count.clamp(0, 40); i++)
                  Text('${h.text} $i'),
              ],
            ),
          ),
        ),
        child: const Text('Open'),
      ),
    ),
    open: true,
  ),
  StressStory(
    'form dialog',
    (context, h) => trigger(
      CoilButton(
        onPressed: () => showCoilDialog<void>(
          context: context,
          kind: CoilDialogKind.form,
          builder: (context) => CoilDialog(
            title: _t(h.text),
            description: _t(h.text),
            actions: [
              CoilButton(
                onPressed: () {},
                variant: CoilButtonVariant.ghost,
                child: _t(h.short),
              ),
              CoilButton(
                onPressed: () {},
                variant: CoilButtonVariant.secondary,
                child: _t(h.text),
              ),
              CoilButton(onPressed: () {}, child: _t(h.text)),
            ],
            child: Column(
              children: [
                for (var i = 0; i < h.count.clamp(0, 12); i++)
                  CoilField(label: _t(h.short), child: const CoilInput()),
              ],
            ),
          ),
        ),
        child: const Text('Open'),
      ),
    ),
    open: true,
  ),
  StressStory(
    'command menu',
    (context, h) => trigger(
      CoilButton(
        onPressed: () => showCoilCommandMenu(
          context: context,
          entries: _entries(h),
          placeholder: _t(h.text),
          empty: _t(h.text),
        ),
        child: const Text('Open'),
      ),
    ),
    open: true,
  ),
  StressStory(
    'settings dialog',
    (context, h) => trigger(
      CoilButton(
        onPressed: () => showCoilSettingsDialog<int>(
          context: context,
          title: _t(h.text),
          sections: [
            for (var i = 0; i < h.count.clamp(1, 30); i++)
              CoilSettingsSection(
                value: i,
                label: _t('${h.short} $i'),
                icon: _icon(),
                description: _t(h.text),
                builder: (context) => Column(
                  children: [
                    CoilSettingRow(
                      label: _t(h.text),
                      description: _t(h.text),
                      trailing: CoilSwitch(value: true, onChanged: (_) {}),
                    ),
                    CoilSettingRow(
                      label: _t(h.text),
                      trailing: CoilButton(
                        onPressed: () {},
                        child: _t(h.short),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        child: const Text('Open'),
      ),
    ),
    open: true,
  ),
  StressStory(
    'accordion',
    (context, h) => CoilAccordion<int>.single(
      value: 0,
      onChanged: (_) {},
      items: [
        for (var i = 0; i < h.count.clamp(0, 40); i++)
          CoilAccordionItem(
            value: i,
            label: _t(i.isEven ? h.text : '${h.short} $i'),
            leading: _icon(),
            panel: _t(h.text),
          ),
      ],
    ),
  ),
  StressStory(
    'card',
    (context, h) => Column(
      spacing: 8,
      children: [
        CoilCard(
          title: _t(h.text),
          description: _t(h.text),
          icon: _icon(),
          onDismissed: () {},
          actions: [
            CoilButton(onPressed: () {}, child: _t(h.short)),
            CoilButton(onPressed: () {}, child: _t(h.text)),
          ],
        ),
        CoilCard(
          title: _t(h.text),
          variant: CoilCardVariant.values.last,
          onPressed: () {},
          child: _t(h.text),
        ),
      ],
    ),
  ),
  StressStory(
    'table',
    (context, h) => CoilTable<int>(
      columns: [
        for (var c = 0; c < 4; c++)
          CoilTableColumn(
            label: _t(h.short),
            cellBuilder: (context, row) => Text('${h.text} $row'),
          ),
      ],
      rows: [for (var i = 0; i < h.count.clamp(0, 60); i++) i],
      empty: _t(h.text),
    ),
  ),
  StressStory(
    'data table',
    (context, h) => CoilDataTable<int>(
      controller: CoilDataTableController(
        rows: [for (var i = 0; i < h.count; i++) i],
        pageSize: 20,
      ),
      empty: _t(h.text),
      columns: [
        for (var c = 0; c < 3; c++)
          CoilDataColumn(
            label: _t(h.short),
            cellBuilder: (context, row) => Text('${h.text} $row'),
          ),
      ],
    ),
  ),
  StressStory(
    'breadcrumb',
    (context, h) => CoilBreadcrumb(
      crumbs: [
        for (var i = 0; i < h.count.clamp(1, 12); i++)
          CoilCrumb(
            label: _t('${h.short} $i'),
            leading: i == 0 ? _icon() : null,
            onPressed: () {},
          ),
      ],
    ),
  ),
  StressStory(
    'thinking',
    (context, h) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        CoilThinkingIndicator(words: [_t(h.text), _t(h.short)]),
        CoilThinkingSteps(
          label: _t(h.text),
          expanded: true,
          onChanged: (_) {},
          steps: [
            for (var i = 0; i < h.count.clamp(0, 30); i++)
              CoilThinkingStep(
                title: _t(h.text),
                detail: _t(h.text),
                sources: [CoilBadge(child: _t(h.short))],
              ),
          ],
        ),
      ],
    ),
  ),
  StressStory(
    'carousel dots',
    (context, h) => CoilCarouselDots(
      count: h.count.clamp(1, 150),
      value: 0,
      onChanged: (_) {},
    ),
  ),
  StressStory(
    'chat message',
    (context, h) => Column(
      spacing: 8,
      children: [
        for (final sender in CoilChatSender.values)
          CoilChatMessage(
            sender: sender,
            entrance: CoilChatMessageEntrance.values.last,
            time: _t(h.short),
            attachments: [
              CoilFileThumbnail(name: '${h.text}.pdf', onRemove: () {}),
            ],
            actions: [
              CoilChatMessageAction(
                label: _t(h.short),
                semanticLabel: 'Copy',
                icon: _icon(),
                onPressed: () {},
              ),
            ],
            child: _t(h.text),
          ),
      ],
    ),
  ),
  StressStory(
    'file thumbnail',
    (context, h) => Wrap(
      spacing: 8,
      children: [
        CoilFileThumbnail(name: h.text, onRemove: () {}),
        CoilFileThumbnail(name: '${h.text}.${h.short}', size: 300),
      ],
    ),
  ),
  StressStory(
    'input message',
    (context, h) => Align(
      alignment: Alignment.bottomCenter,
      child: CoilInputMessage(
        controller: TextEditingController(text: h.text * 4),
        onSend: (_) {},
        placeholder: _t(h.text),
        leading: CoilButton.icon(
          onPressed: () {},
          icon: _icon(TestGlyph.plus),
          semanticLabel: 'Attach',
        ),
        attachments: Wrap(
          children: [
            for (var i = 0; i < h.count.clamp(0, 8); i++)
              CoilFileThumbnail(name: '${h.short} $i'),
          ],
        ),
      ),
    ),
    host: StressHost.fill,
  ),
  StressStory(
    'ask user questions',
    (context, h) => CoilAskUserQuestions<int>(
      questions: [
        CoilQuestion.single(
          id: 'a',
          title: _t(h.text),
          options: [
            for (var i = 0; i < h.count.clamp(0, 30); i++)
              CoilQuestionOption(
                value: i,
                label: _t(h.text),
                description: _t(h.short),
              ),
          ],
        ),
        CoilQuestion.freeText(id: 'b', title: _t(h.text)),
      ],
    ),
  ),
  StressStory(
    'scroll area',
    (context, h) => SizedBox(
      height: 200,
      child: CoilScrollArea(
        child: Column(
          children: [for (var i = 0; i < h.count; i++) Text('${h.text} $i')],
        ),
      ),
    ),
  ),
  StressStory(
    'reveal',
    (context, h) => CoilReveal(
      children: [for (var i = 0; i < h.count.clamp(0, 30); i++) _t(h.text)],
    ),
  ),
  StressStory(
    'context menu',
    (context, h) => CoilContextMenu(
      entries: _entries(h),
      child: trigger(SizedBox(height: 120, child: Center(child: _t(h.text)))),
    ),
  ),
  StressStory(
    'calendar and date picker',
    (context, h) => Column(
      children: [
        CoilCalendar(selected: DateTime(2026, 11, 17), onSelected: (_) {}),
        trigger(
          CoilDatePicker(
            value: DateTime(2026, 11, 17),
            onChanged: (_) {},
            withTime: true,
            placeholder: _t(h.text),
          ),
        ),
      ],
    ),
    open: true,
    // The date picker belongs to another stream; reported, not fixed here.
  ),
  StressStory(
    'queued stack',
    (context, h) => SizedBox(
      height: 400,
      child: CoilQueuedStack(
        messages: [
          for (var i = 0; i < h.count.clamp(0, 20); i++)
            CoilQueuedMessage(id: i, semanticLabel: h.text, child: _t(h.text)),
        ],
        onChanged: (_) {},
        onEdit: (_) {},
        child: const SizedBox.expand(),
      ),
    ),
  ),
  StressStory(
    'sidebar',
    (context, h) => CoilSidebarScaffold(
      sidebar: CoilSidebar(
        header: _t(h.text),
        children: [
          CoilSidebarGroup(
            label: _t(h.text),
            child: CoilSidebarMenu(
              items: [
                for (var i = 0; i < h.count.clamp(0, 60); i++)
                  CoilSidebarItem(
                    label: _t('${h.text} $i'),
                    leading: _icon(),
                    trailing: CoilKbd('⌘$i'),
                    onPressed: () {},
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Center(child: _t(h.text)),
    ),
    host: StressHost.fill,
  ),
];

void main() {
  for (final story in stories) {
    group(story.name, () {
      for (final screen in screens) {
        testWidgets(
          screen.name,
          skip: story.knownBreakage.containsKey(screen.name),
          (tester) => stress(tester, screen, story),
        );
      }
    });
  }
}
