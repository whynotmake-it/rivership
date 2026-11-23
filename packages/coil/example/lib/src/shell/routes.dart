import 'package:auto_route/auto_route.dart';
import 'package:coil_example/src/pages/components/dialog_page.dart';
import 'package:coil_example/src/pages/home_page.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/catalog_shell.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:flutter/widgets.dart';

/// The home page's route name.
const catalogHomeRouteName = 'coil:home';

/// The route name of [entry]'s page.
String catalogRouteName(CatalogEntry entry) => 'coil:${entry.slug}';

/// How the catalog's pages come and go: instantly on desktop, and on a
/// phone (a phone-sized window, or the iPhone and Android frames) a very
/// quick fade in place from half opacity, with no slide, scale or blur, so
/// moving between pages from the sidebar reads as a swap, not a push.
///
/// The route still takes [_fade] to settle, so on desktop the leaving page
/// is hidden for that time instead of shown over the next one.
///
/// There is no back swipe: Back is the header button, Escape or the
/// system back.
final catalogPageRouteType = RouteType.custom(
  duration: _fade,
  reverseDuration: _fade,
  transitionsBuilder: _transition,
);

const _fade = Duration(milliseconds: 120);

/// Where a phone's page fades in from.
const _fadeFrom = 0.5;

/// Whether pages at [context] fade: on a phone-sized window, and in the
/// iPhone and Android frames.
bool _fades(BuildContext context) =>
    !CatalogChrome.hasTopBarOf(context) ||
    CatalogSettingsScope.maybeOf(context)?.viewport == CatalogViewport.mobile;

Widget _transition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final leaving = animation.status == AnimationStatus.reverse;
  if (!_fades(context)) {
    // In or out at once: arriving is drawn whole, leaving not at all.
    return Offstage(offstage: leaving, child: child);
  }
  return FadeTransition(
    opacity: leaving
        ? animation
        : animation.drive(
            Tween<double>(
              begin: _fadeFrom,
              end: 1,
            ).chain(CurveTween(curve: Curves.easeOut)),
          ),
    child: child,
  );
}

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
///
/// [onHome] takes the host app back to its landing page: with it, the
/// coil wordmark in the top bar (and in the drawer on a phone) becomes a
/// link back to all packages. Without it, the wordmark is inert.
NamedRouteDef coilCatalogRoute({
  String path = '/coil',
  VoidCallback? onHome,
}) => NamedRouteDef(
  name: 'Coil',
  path: path,
  type: catalogPageRouteType,
  builder: (context, data) => CatalogShell(onHome: onHome),
  children: coilCatalogRoutes,
);
