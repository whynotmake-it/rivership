import 'package:auto_route/auto_route.dart';
import 'package:coil_example/src/pages/components/dialog_page.dart';
import 'package:coil_example/src/pages/home_page.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/catalog_shell.dart';

/// The route name of [entry]'s page.
String catalogRouteName(CatalogEntry entry) => 'coil:${entry.slug}';

/// The catalog's pages, relative to wherever the catalog is mounted. Pages
/// use the platform's page route: an edge swipe pops on iOS.
final List<AutoRoute> coilCatalogRoutes = [
  NamedRouteDef(
    name: 'coil:home',
    path: '',
    type: const RouteType.cupertino(),
    builder: (context, data) => const HomePage(),
  ),
  for (final entry in catalogEntries)
    NamedRouteDef(
      name: catalogRouteName(entry),
      path: entry.path,
      type: const RouteType.cupertino(),
      builder: (context, data) => entry.page(),
    ),
  dialogRouteDef,
];

/// The whole catalog as one route with its pages nested, for apps that
/// mount it next to other examples.
NamedRouteDef coilCatalogRoute({String path = '/coil'}) => NamedRouteDef(
  name: 'Coil',
  path: path,
  type: const RouteType.cupertino(),
  builder: (context, data) => const CatalogShell(child: AutoRouter()),
  children: coilCatalogRoutes,
);
