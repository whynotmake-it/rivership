import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet_example/demos/detents_demo.dart';
import 'package:stupid_simple_sheet_example/demos/keyboard_demo.dart';
import 'package:stupid_simple_sheet_example/demos/nested_navigation_demo.dart';
import 'package:stupid_simple_sheet_example/demos/route_styles_demo.dart';
import 'package:stupid_simple_sheet_example/demos/scroll_handoff_demo.dart';
import 'package:stupid_simple_sheet_example/shell/home_page.dart';
import 'package:stupid_simple_sheet_example/shell/sheet_example_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CupertinoApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router.config(),
    ),
  );
}

/// The example's pages, to mount under any [RootStackRouter]. Route names
/// are prefixed with `sheet:` so they stay unique next to other examples.
final stupidSimpleSheetRoutes = <AutoRoute>[
  _page('sheet:home', '', (_) => const SheetHomePage()),
  _page('sheet:detents', 'detents', (_) => const DetentsDemo()),
  _page('sheet:handoff', 'scroll-handoff', (_) => const ScrollHandoffDemo()),
  _page(
    'sheet:nested',
    'nested-navigation',
    (_) => const NestedNavigationDemo(),
  ),
  _page('sheet:keyboard', 'keyboard', (_) => const KeyboardDemo()),
  _page('sheet:styles', 'route-styles', (_) => const RouteStylesDemo()),
];

final _router = RootStackRouter.build(
  routes: [
    NamedRouteDef.shell(
      name: 'Home',
      path: '/',
      children: stupidSimpleSheetRoutes,
    ),
  ],
);

AutoRoute _page(String name, String path, WidgetBuilder page) => NamedRouteDef(
  name: name,
  path: path,
  type: RouteType.cupertino(),
  builder: (context, _) => SheetExampleTheme(child: page(context)),
);
