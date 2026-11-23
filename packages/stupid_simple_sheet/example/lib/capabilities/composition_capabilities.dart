import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/code_block.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';
import 'package:stupid_simple_sheet_example/shell/plain_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/rows.dart';

/// Sheets with sheets, pages and frozen pages in them.
final compositionCapabilities = <Capability>[
  Capability(
    title: 'Stacked sheets',
    description: 'A sheet opens another one over itself, as deep as you '
        'like.',
    code: _stackedCode,
    open: (context) => _openStacked(context, 1),
  ),
  Capability(
    title: 'Nested navigation',
    description: 'Pages pushed inside one sheet, which still drags away '
        'from any of them.',
    code: _nestedCode,
    open: (context) => Navigator.of(context).push(
      DemoSheetRoute<void>(context: context, child: const _NestedSheet()),
    ),
  ),
  Capability(
    title: 'Background snapshot',
    description: 'The page behind is rasterized while the sheet opens and '
        'rests.',
    code: _snapshotCode,
    open: (context) => Navigator.of(context).push(
      PlainSheetRoute<void>(
        context: context,
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        child: const CapabilitySheet(
          title: 'Background snapshot',
          hint:
              'While this sheet opens and rests, the page behind it is one '
              "frozen image instead of a live widget tree, so it isn't "
              'rebuilt or repainted. It goes live again as you drag.',
          code: _snapshotCode,
          children: [_Rows(3)],
        ),
      ),
    ),
  ),
];

const _stackedCode = '''
// Pushing from inside a sheet stacks the next one over it, with
// its own scrim. The one below stays where it is.
Navigator.of(context).push(
  StupidSimpleSheetRoute(child: YourContent()),
);''';

const _nestedCode = '''
// A Navigator inside the sheet. The sheet's own route can't
// hold a back handler: a route that refuses to pop also
// refuses the dismissing drag.
Navigator(
  key: navigatorKey,
  onGenerateRoute: (settings) => PageRouteBuilder(
    settings: settings,
    pageBuilder: (context, animation, secondary) => pageFor(settings),
  ),
);''';

const _snapshotCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    // Rasterizes the route behind while this one opens and
    // while it rests fully open; live during drags.
    backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
    child: YourContent(),
  ),
);''';

/// Numbered rows as one widget, so a const sheet can hold them.
class _Rows extends StatelessWidget {
  const _Rows(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: capabilityRows(count),
  );
}

Future<void> _openStacked(BuildContext context, int depth) =>
    Navigator.of(context).push(
      DemoSheetRoute<void>(
        context: context,
        child: _StackedSheet(depth: depth),
      ),
    );

/// A sheet that opens the next one over itself.
class _StackedSheet extends StatelessWidget {
  const _StackedSheet({required this.depth});

  /// How many of these sheets are open, this one included.
  final int depth;

  @override
  Widget build(BuildContext context) => CapabilitySheet(
    title: depth == 1 ? 'Stacked sheets' : 'Sheet $depth',
    hint: depth == 1
        ? 'Open another sheet over this one; each brings its own scrim, '
              'and closing one shows the one below.'
        : 'Sheet $depth, over ${depth - 1} more.',
    code: _stackedCode,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: sheetInset),
        child: CoilButton(
          variant: CoilButtonVariant.secondary,
          onPressed: () => _openStacked(context, depth + 1),
          child: Text('Open sheet ${depth + 1}'),
        ),
      ),
      const SizedBox(height: 16),
      _Rows(2),
    ],
  );
}

/// A sheet with its own [Navigator]: three pages that push and pop
/// inside it, while the sheet still drags away from any of them.
class _NestedSheet extends StatefulWidget {
  const _NestedSheet();

  @override
  State<_NestedSheet> createState() => _NestedSheetState();
}

class _NestedSheetState extends State<_NestedSheet> {
  final _navigator = GlobalKey<NavigatorState>();

  /// The title follows the visible page.
  final _title = ValueNotifier('Nested navigation');

  /// Holds focus above the pages, so Escape reaches the sheet before the
  /// first Tab and after a page that had focus has left.
  final _focus = FocusNode(skipTraversal: true);

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Takes focus back to the sheet's scope as a page comes or goes: the
  /// row that had focus is leaving the tree.
  void _refocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _focus.requestFocus();
  });

  Route<void> _route(RouteSettings settings) {
    final depth = int.tryParse(settings.name ?? '') ?? 1;
    final time = CoilTheme.motionOf(context).standard.duration;
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: time ?? const Duration(milliseconds: 180),
      reverseTransitionDuration: time ?? const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) => _NestedPage(
        depth: depth,
        open: () => _navigator.currentState?.pushNamed('${depth + 1}'),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1;
        return AnimatedBuilder(
          animation: Listenable.merge([animation, secondaryAnimation]),
          child: child,
          builder: (context, child) {
            final entering = Curves.easeOutCubic.transform(animation.value);
            final leaving = Curves.easeOutCubic.transform(
              secondaryAnimation.value,
            );
            return Opacity(
              opacity: (1 - leaving) * entering,
              child: FractionalTranslation(
                translation: Offset(sign * ((1 - entering) - 0.25 * leaving), 0),
                child: child,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = math.min(380.0, MediaQuery.sizeOf(context).height * 0.5);
    return CoilSheetPanel(
      title: ValueListenableBuilder(
        valueListenable: _title,
        builder: (context, title, _) => Text(title),
      ),
      // Escape goes back a page before it closes the sheet. The sheet's
      // own route can't hold a back handler: a route that refuses to pop
      // also refuses the dismissing drag.
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
        },
        child: Actions(
          actions: {_BackIntent: _BackAction(_navigator)},
          // Takes focus on open so Escape works before the first Tab, and
          // keeps it when a page leaves.
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            child: SizedBox(
              height: height,
              child: Navigator(
                key: _navigator,
                observers: [_TitleObserver(_title, _refocus)],
                onGenerateRoute: _route,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One page inside the nested sheet: a back row to the page before it,
/// the page's rows, and a row that pushes the next page.
class _NestedPage extends StatelessWidget {
  const _NestedPage({required this.depth, required this.open});

  /// Which page this is, from 1.
  final int depth;

  /// Pushes the next page.
  final VoidCallback open;

  /// How many pages there are.
  static const pages = 3;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (depth > 1)
        DemoRow(
          label: Text('Page ${depth - 1}'),
          leading: const CoilIcon(CoilIconRole.chevronStart),
          onPressed: Navigator.of(context).pop,
        ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            if (depth == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  sheetInset,
                  0,
                  sheetInset,
                  16,
                ),
                child: Text(
                  'Push pages inside the sheet, and drag the sheet down '
                  'from any of them. Escape goes back a page first.',
                  style: CoilTheme.textOf(context).muted.body,
                ),
              ),
            ...capabilityRows(3, from: depth * 10 - 9),
            if (depth < pages)
              DemoRow(
                label: Text('Page ${depth + 1}'),
                chevron: true,
                onPressed: open,
              ),
            if (depth == 1) ...[
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: sheetInset),
                child: CodeBlock(code: _nestedCode),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _BackIntent extends Intent {
  const _BackIntent();
}

/// Pops the nested navigator for Escape while it has a page to pop, and
/// otherwise leaves Escape to the sheet.
class _BackAction extends Action<_BackIntent> {
  _BackAction(this.navigator);

  final GlobalKey<NavigatorState> navigator;

  @override
  bool isEnabled(_BackIntent intent) =>
      navigator.currentState?.canPop() ?? false;

  @override
  Object? invoke(_BackIntent intent) {
    navigator.currentState?.pop();
    return null;
  }
}

/// Keeps [title] on the name of the visible page.
class _TitleObserver extends NavigatorObserver {
  _TitleObserver(this.title, this.onChanged);

  final ValueNotifier<String> title;

  /// Called after a page came or went.
  final VoidCallback onChanged;

  static String _nameOf(Route<dynamic>? route) {
    final depth = int.tryParse(route?.settings.name ?? '') ?? 1;
    return depth == 1 ? 'Nested navigation' : 'Page $depth';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    title.value = _nameOf(route);
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    title.value = _nameOf(previousRoute);
    onChanged();
  }
}
