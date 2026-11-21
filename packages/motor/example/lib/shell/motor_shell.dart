import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/shell/devtools_switch.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_example/widgets/motor_logo.dart';

/// The overview's route name.
const overviewRouteName = 'Motor 2.0';

/// Below this window width the gallery is on a phone, or in a phone-sized
/// window: the touch tier, with the sidebar as a drawer.
const phoneBreakpoint = 600.0;

/// The gallery: coil's theme, the sidebar listing every demo, and the
/// demo on screen.
///
/// Inside an app that already provides a [CoilTheme], the gallery takes
/// that theme, so it matches the app around it. Otherwise it follows the
/// platform's brightness with coil's Allo typography.
class MotorShell extends StatelessWidget {
  const MotorShell({super.key});

  @override
  Widget build(BuildContext context) => MotorEnvironment(
    child: AutoRouter(
      builder: (context, navigator) =>
          MotorNavigation(router: AutoRouter.of(context), child: navigator),
    ),
  );
}

/// Sets up coil for the gallery: the theme (unless an ancestor sets one),
/// the touch tier in a phone-sized window, and the page background.
///
/// The gallery's own theme uses coil's Allo typography when the app bundles
/// Allo (the aggregate example app does), and the platform font otherwise.
class MotorEnvironment extends StatefulWidget {
  const MotorEnvironment({required this.child, super.key});

  final Widget child;

  @override
  State<MotorEnvironment> createState() => _MotorEnvironmentState();
}

class _MotorEnvironmentState extends State<MotorEnvironment> {
  static Future<bool>? _alloBundled;

  /// Whether the app's font manifest declares Allo.
  static Future<bool> _loadAlloBundled() async {
    try {
      final manifest = await rootBundle.loadString('FontManifest.json');
      final families = jsonDecode(manifest) as List<Object?>;
      return families.any(
        (family) => family is Map && family['family'] == 'Allo',
      );
    } on Object {
      return false;
    }
  }

  var _allo = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      (_alloBundled ??= _loadAlloBundled()).then((bundled) {
        if (mounted && bundled != _allo) setState(() => _allo = bundled);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Builder(
      builder: (context) => ColoredBox(
        color: CoilTheme.of(context).colors.background,
        child: DefaultTextStyle(
          style: CoilTheme.textOf(context).body,
          child: widget.child,
        ),
      ),
    );
    if (MediaQuery.sizeOf(context).width < phoneBreakpoint) {
      result = CoilAdaptiveScope(tier: CoilTier.touch, child: result);
    }
    if (context.findAncestorWidgetOfExactType<CoilTheme>() != null) {
      return result;
    }
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return CoilTheme(
      data: (dark ? CoilThemeData.dark : CoilThemeData.light).copyWith(
        typography: _allo ? CoilTypography.allo() : CoilTypography.platform,
      ),
      child: result,
    );
  }
}

/// Shows the demo [chapter] in the gallery's [router], or the overview
/// when [chapter] is null.
///
/// Demos don't stack: the sidebar is how to move around, so a demo takes
/// the place of whatever was shown.
Future<void> openChapter(StackRouter router, Chapter? chapter) async {
  final name = chapter?.title ?? overviewRouteName;
  final stack = router.stackData;
  if (stack.length == 1 && stack.single.name == name) return;
  await router.replaceAll([NamedRoute(name)]);
}

/// The gallery's navigation: coil's sidebar scaffold, a sidebar on a wide
/// window and a drawer on a narrow one. Lists the overview and every demo
/// by group, highlights the one on screen, and has the DevTools switch.
class MotorNavigation extends StatefulWidget {
  const MotorNavigation({required this.router, required this.child, super.key});

  /// The router whose pages [child] shows.
  final StackRouter router;

  /// The page.
  final Widget child;

  @override
  State<MotorNavigation> createState() => _MotorNavigationState();
}

class _MotorNavigationState extends State<MotorNavigation> {
  final _sidebar = CoilSidebarController(width: 240);
  final _expanded = {for (final group in ChapterGroup.values) group: true};

  @override
  void dispose() {
    _sidebar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.router,
    builder: (context, _) => HasSidebar(
      child: CoilSidebarScaffold(
        controller: _sidebar,
        sidebar: _sidebarFor(context),
        body: widget.child,
      ),
    ),
  );

  Widget _sidebarFor(BuildContext context) {
    final current = widget.router.stackData.lastOrNull?.name;
    return CoilSidebar(
      semanticLabel: 'Motor examples',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          const SizedBox(height: 8),
          CoilSidebarMenu(
            items: [
              CoilSidebarItem(
                label: const Text('Overview'),
                leading: const GlyphIcon(Glyph.home),
                selected: current == overviewRouteName,
                onPressed: () => unawaited(openChapter(widget.router, null)),
              ),
            ],
          ),
        ],
      ),
      footer: const DevToolsSwitch(),
      children: [
        for (final group in ChapterGroup.values)
          CoilSidebarGroup(
            label: Text(group.title),
            expanded: _expanded[group]!,
            onExpandedChanged: (open) =>
                setState(() => _expanded[group] = open),
            child: CoilSidebarMenu(
              items: [
                for (final chapter in chapters.where((c) => c.group == group))
                  CoilSidebarItem(
                    label: Text(chapter.title),
                    leading: GlyphIcon(chapter.glyph),
                    selected: chapter.title == current,
                    onPressed: () =>
                        unawaited(openChapter(widget.router, chapter)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The logo, "Motor" and the version, at the top of the sidebar.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final metrics = CoilTheme.metricsOf(context);
    return Semantics(
      label: 'Motor 2.0',
      excludeSemantics: true,
      child: Padding(
        // Rows inset their content by the item padding; the brand lines up
        // with their icons.
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: metrics.itemPaddingX,
          vertical: 4,
        ),
        child: Row(
          children: [
            MotorLogo(size: metrics.iconSize + 4),
            SizedBox(width: metrics.gap),
            Text('Motor', style: text.title),
            const SizedBox(width: 8),
            const CoilBadge(child: Text('2.0')),
          ],
        ),
      ),
    );
  }
}

/// Marks pages that sit beside the gallery's sidebar, so their header shows
/// its trigger. A page pumped on its own has none.
class HasSidebar extends InheritedWidget {
  const HasSidebar({required super.child, super.key});

  /// Whether [context] is inside the gallery's sidebar scaffold.
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HasSidebar>() != null;

  @override
  bool updateShouldNotify(HasSidebar oldWidget) => false;
}
