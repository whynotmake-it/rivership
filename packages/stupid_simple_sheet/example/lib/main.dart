import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet_example/playground/playground_page.dart';
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
///
/// The logo on the home page is inert here. To make it a link back to a
/// landing page, mount [buildStupidSimpleSheetRoutes] instead.
final stupidSimpleSheetRoutes = buildStupidSimpleSheetRoutes();

/// Builds the example's pages, to mount under any [RootStackRouter].
///
/// [onHome] turns the home page's logo into a link back to the app that
/// hosts the example, such as a combined gallery's landing page. Mount it
/// with `children: buildStupidSimpleSheetRoutes(onHome: () => ...)`. Without
/// it the logo is decorative.
List<AutoRoute> buildStupidSimpleSheetRoutes({VoidCallback? onHome}) => [
  _page('sheet:home', '', (_) => SheetHomePage(onHome: onHome)),
  _page('sheet:playground', 'playground', (_) => const PlaygroundPage()),
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
