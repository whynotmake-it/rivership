import 'package:coil/coil.dart';
import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';
import 'package:stupid_simple_sheet_example/shell/rows.dart';

/// A note with one share sheet, shown by coil's route, the iOS 26 glass
/// route or the iOS 18 Cupertino route.
class RouteStylesDemo extends StatefulWidget {
  /// Creates the demo.
  const RouteStylesDemo({super.key});

  @override
  State<RouteStylesDemo> createState() => _RouteStylesDemoState();
}

class _RouteStylesDemoState extends State<RouteStylesDemo> {
  var _style = _SheetStyle.coil;

  // Every style shrinks with its detent instead of sliding, so the footer
  // button stays on screen at 60 %.
  static const _snapping = SheetSnappingConfig([0.6, 1.0], initialSnap: 0.6);
  static const _dismissal = DismissalMode.shrink;

  void _share() {
    final people = _People();
    final navigator = Navigator.of(context);
    final route = switch (_style) {
      _SheetStyle.coil => DemoSheetRoute<void>(
        context: context,
        snappingConfig: _snapping,
        dismissalMode: _dismissal,
        child: _CoilShare(people: people),
      ),
      _SheetStyle.glass => StupidSimpleGlassSheetRoute<void>(
        snappingConfig: _snapping,
        dismissalMode: _dismissal,
        backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.systemGroupedBackground,
          context,
        ),
        child: _CupertinoScope(child: _GlassShare(people: people)),
      ),
      _SheetStyle.cupertino => StupidSimpleCupertinoSheetRoute<void>(
        snappingConfig: _snapping,
        dismissalMode: _dismissal,
        backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.systemGroupedBackground,
          context,
        ),
        child: _CupertinoScope(child: _CupertinoShare(people: people)),
      ),
    };
    navigator.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return DemoScaffold(
      title: const Text('Notes'),
      trailing: CoilButton(
        variant: CoilButtonVariant.secondary,
        size: CoilSize.compact,
        onPressed: _share,
        child: const Text('Share'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 8,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: DemoContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('Packing list for Lisbon', style: text.display),
              ),
              const SizedBox(height: 16),
              for (final line in _noteLines) ...[
                Text(line, style: text.body),
                const SizedBox(height: 8),
              ],
              SizedBox(height: DemoScaffold.sectionGapOf(context) - 8),
              CoilField(
                label: const Text('Sheet style'),
                child: CoilTabs<_SheetStyle>(
                  value: _style,
                  onChanged: (style) => setState(() => _style = style),
                  tabs: [
                    for (final style in _SheetStyle.values)
                      CoilTab(value: style, label: Text(style.label)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SheetStyle {
  coil('coil'),
  glass('Glass'),
  cupertino('Cupertino');

  const _SheetStyle(this.label);

  final String label;
}

const _noteLines = [
  'Passport and boarding pass',
  'Comfortable walking shoes for the hills',
  'Light rain jacket',
  'Phone charger and a plug adapter',
  'Sunscreen and a hat',
  'Tram 28 is crowded, go early',
];

/// The people the note can be shared with, and who is picked.
class _People extends ChangeNotifier {
  final selected = <String>{};

  void toggle(String name) {
    if (!selected.remove(name)) selected.add(name);
    notifyListeners();
  }

  /// The share button's label: copying the link until somebody is picked.
  String get action =>
      selected.isEmpty ? 'Copy link' : 'Send to ${selected.length}';
}

const _names = ['Ana', 'Ben', 'Chloe', 'Dev', 'Elin', 'Farid'];

const _actions = [
  'Send a copy',
  'Export as PDF',
  'Print',
  'Add to reading list',
];

// -- coil ------------------------------------------------------------------

class _CoilShare extends StatelessWidget {
  const _CoilShare({required this.people});

  final _People people;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return ListenableBuilder(
      listenable: people,
      builder: (context, _) => CoilSheetPanel(
        title: const Text('Share note'),
        footer: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CoilActionBar(
            actions: [
              CoilButton(
                onPressed: navigator.maybePop,
                child: Text(people.action),
              ),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                spacing: 16,
                children: [
                  for (final name in _names)
                    _CoilPerson(
                      name: name,
                      selected: people.selected.contains(name),
                      onPressed: () => people.toggle(name),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final label in _actions)
              DemoRow(label: Text(label), onPressed: navigator.maybePop),
          ],
        ),
      ),
    );
  }
}

class _CoilPerson extends StatelessWidget {
  const _CoilPerson({
    required this.name,
    required this.selected,
    required this.onPressed,
  });

  final String name;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return CoilInteraction(
      onPressed: onPressed,
      builder: (context, states, _) => Semantics(
        label: name,
        selected: selected,
        excludeSemantics: true,
        child: SizedBox(
          width: 56,
          child: Column(
            spacing: 6,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.muted,
                      shape: const CircleBorder(),
                    ),
                    child: SizedBox.square(
                      dimension: 56,
                      child: Center(
                        child: Text(
                          name[0],
                          style: text.title.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: colors.foreground,
                          shape: CircleBorder(
                            side: BorderSide(
                              color: colors.surface(3),
                              width: 2,
                            ),
                          ),
                        ),
                        child: SizedBox.square(
                          dimension: 22,
                          child: IconTheme(
                            data: IconThemeData(
                              size: 14,
                              color: colors.background,
                            ),
                            child: const Center(
                              child: CoilIcon(CoilIconRole.check),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Text(name, style: text.muted.caption, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Cupertino -------------------------------------------------------------

/// Gives Cupertino content its own theme and text style, so nothing of
/// coil's reaches it.
class _CupertinoScope extends StatelessWidget {
  const _CupertinoScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return CupertinoTheme(
      data: CupertinoThemeData(brightness: brightness),
      child: Builder(
        builder: (context) => DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: child,
        ),
      ),
    );
  }
}

const _avatarColors = [
  CupertinoColors.systemIndigo,
  CupertinoColors.systemGreen,
  CupertinoColors.systemOrange,
  CupertinoColors.systemPink,
  CupertinoColors.systemTeal,
  CupertinoColors.systemPurple,
];

/// The share content in Cupertino widgets: people, then the actions, then
/// the pinned button. [header] sits above the people.
class _CupertinoShareBody extends StatelessWidget {
  const _CupertinoShareBody({required this.people, this.header});

  final _People people;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final labelStyle = CupertinoTheme.of(context).textTheme.tabLabelTextStyle
        .copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context));
    return ListenableBuilder(
      listenable: people,
      builder: (context, _) => Column(
        children: [
          ?header,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 12),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    spacing: 16,
                    children: [
                      for (final (index, name) in _names.indexed)
                        GestureDetector(
                          onTap: () => people.toggle(name),
                          child: Semantics(
                            button: true,
                            selected: people.selected.contains(name),
                            label: name,
                            child: ExcludeSemantics(
                              child: SizedBox(
                                width: 56,
                                child: Column(
                                  spacing: 6,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: _avatarColors[index]
                                                .resolveFrom(context),
                                            shape: BoxShape.circle,
                                          ),
                                          child: SizedBox.square(
                                            dimension: 56,
                                            child: Center(
                                              child: Text(
                                                name[0],
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w600,
                                                  color: CupertinoColors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (people.selected.contains(name))
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: CupertinoColors
                                                    .systemGroupedBackground
                                                    .resolveFrom(context),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                CupertinoIcons
                                                    .check_mark_circled_solid,
                                                size: 24,
                                                color: CupertinoColors
                                                    .activeBlue
                                                    .resolveFrom(context),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(name, style: labelStyle),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoListSection.insetGrouped(
                  backgroundColor: const Color(0x00000000),
                  children: [
                    for (final label in _actions)
                      CupertinoListTile.notched(
                        title: Text(label),
                        trailing: const CupertinoListTileChevron(),
                        onTap: navigator.maybePop,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: navigator.maybePop,
                child: Text(people.action),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassShare extends StatelessWidget {
  const _GlassShare({required this.people});

  final _People people;

  @override
  Widget build(BuildContext context) {
    return _CupertinoShareBody(
      people: people,
      header: SizedBox(
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'Share note',
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 16),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(44),
                  onPressed: Navigator.of(context).maybePop,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.tertiarySystemFill.resolveFrom(
                        context,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 18,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CupertinoShare extends StatelessWidget {
  const _CupertinoShare({required this.people});

  final _People people;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: Navigator.of(context).maybePop,
          child: const Text('Close'),
        ),
        middle: const Text('Share note'),
      ),
      // The bar is translucent and the page scrolls under it.
      child: SafeArea(
        bottom: false,
        child: _CupertinoShareBody(people: people),
      ),
    );
  }
}
