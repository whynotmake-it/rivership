import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/coil_example.dart';
import 'package:flutter/cupertino.dart';
import 'package:heroine_example/main.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_example/font_licenses.dart';
import 'package:motor_example/main.dart';
import 'package:rivership/rivership.dart';
import 'package:stupid_simple_sheet_example/main.dart';

import 'src/example_frame.dart';
import 'src/landing_page.dart';

/// How the landing page and the examples swap: a quick fade, with no slide.
///
/// The route takes the whole fade to settle, so the leaving page is hidden
/// for that time instead of shown over the next one.
final exampleRouteType = RouteType.custom(
  duration: _fade,
  reverseDuration: _fade,
  transitionsBuilder: _fadeTransition,
);

const _fade = Duration(milliseconds: 120);

/// Where an arriving page fades in from.
const _fadeFrom = 0.5;

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final leaving = animation.status == AnimationStatus.reverse;
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

NamedRouteDef _exampleRoute({
  required String name,
  required String path,
  required String package,
  required List<AutoRoute> children,
  bool cupertino = true,
}) =>
    NamedRouteDef(
      name: name,
      path: path,
      type: exampleRouteType,
      builder: (context, data) => ExampleFrame(
        package: package,
        cupertino: cupertino,
        child: const AutoRouter(),
      ),
      children: children,
    );

/// The coil catalog's own route, framed.
///
/// The catalog's route is rebuilt rather than nested under a frame route with
/// an empty path, which doesn't resolve the catalog's pages from deep links.
NamedRouteDef _coilRoute() {
  final catalog = coilCatalogRoute(path: '/coil');
  return NamedRouteDef(
    name: catalog.name,
    path: catalog.path,
    type: exampleRouteType,
    builder: (context, data) => ExampleFrame(
      package: 'coil',
      cupertino: false,
      child: catalog.page.builder(data),
    ),
    children: catalog.children,
  );
}

void main() async {
  await WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final router = RootStackRouter.build(
    routes: [
      NamedRouteDef(
        path: '/',
        name: 'Home',
        type: exampleRouteType,
        builder: (context, state) => const LandingPage(),
      ),
      _exampleRoute(
        name: 'Heroine',
        path: '/heroine',
        package: 'heroine',
        children: heroineRoutes,
      ),
      _exampleRoute(
        name: 'Motor',
        path: '/motor',
        package: 'motor',
        children: motorRoutes,
      ),
      _coilRoute(),
      _exampleRoute(
        name: 'Stupid Simple Sheet',
        path: '/stupid_simple_sheet',
        package: 'stupid_simple_sheet',
        children: stupidSimpleSheetRoutes,
      ),
    ],
  );

  runApp(
    ListenableBuilder(
      // The motor home and the coil settings each have a DevTools switch.
      listenable: Listenable.merge([devtoolsVisible, coilDevtoolsVisible]),
      builder: (context, child) => MotorDevTools(
        // The gallery ships the tools on purpose, in release builds too.
        enabled: true,
        visible: devtoolsVisible.value || coilDevtoolsVisible.value,
        child: child!,
      ),
      child: WidgetsApp.router(
        title: 'whynotmake.it packages',
        color: CoilColors.light.brand,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final data = switch (MediaQuery.platformBrightnessOf(context)) {
            Brightness.dark => CoilThemeData.dark,
            Brightness.light => CoilThemeData.light,
          };
          final theme = data.copyWith(
            typography: CoilTypography.allo(roundness: 50),
          );
          return CoilTheme(
            data: theme,
            child: Builder(
              builder: (context) => DefaultTextStyle(
                style: CoilTheme.textOf(context).body,
                child: child!,
              ),
            ),
          );
        },
        routerConfig: router.config(
          navigatorObservers: () => [
            HeroineController(),
            HeroController(),
          ],
        ),
      ),
    ),
  );
}
