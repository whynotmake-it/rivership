import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/dialog_page.dart';
import 'package:coil_example/src/pages/home_page.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/catalog_shell.dart';
import 'package:flutter/widgets.dart';

/// The home page's route name.
const catalogHomeRouteName = 'coil:home';

/// The route name of [entry]'s page.
String catalogRouteName(CatalogEntry entry) => 'coil:${entry.slug}';

/// How the catalog's pages come and go: a quick blur-fade in place, no
/// slide, so moving between pages from the sidebar reads as a swap rather
/// than a push. In 180 ms, out in 140 (about coil's `fade` and `fadeExit`).
/// Under reduced motion `CoilBlurFade` drops the blur and keeps the fade.
///
/// There is no back swipe: Back is the header button, Escape or the
/// system back.
final catalogPageRouteType = RouteType.custom(
  duration: const Duration(milliseconds: 180),
  reverseDuration: const Duration(milliseconds: 140),
  transitionsBuilder: _blurFade,
);

Widget _blurFade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => CoilBlurFade(
  presence: animation.drive(CurveTween(curve: Curves.easeOut)),
  // Only blur and fade: a page that grows or moves reads as a push.
  scale: 1,
  child: child,
);

/// The catalog's pages, relative to wherever the catalog is mounted.
final List<AutoRoute> coilCatalogRoutes = [
  NamedRouteDef(
    name: catalogHomeRouteName,
    path: '',
    type: catalogPageRouteType,
    builder: (context, data) => const HomePage(),
  ),
  for (final entry in catalogEntries)
    NamedRouteDef(
      name: catalogRouteName(entry),
      path: entry.path,
      type: catalogPageRouteType,
      builder: (context, data) => entry.page(),
    ),
  dialogRouteDef,
];

/// The whole catalog as one route with its pages nested, for apps that
/// mount it next to other examples.
NamedRouteDef coilCatalogRoute({String path = '/coil'}) => NamedRouteDef(
  name: 'Coil',
  path: path,
  type: catalogPageRouteType,
  builder: (context, data) => const CatalogShell(),
  children: coilCatalogRoutes,
);
