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

import 'src/cupertino_environment.dart';
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

/// The route name of each package's example, by the package's pub name.
const _exampleRouteNames = {
  'coil': 'Coil',
  'motor': 'Motor',
  'heroine': 'Heroine',
  'stupid_simple_sheet': 'Stupid Simple Sheet',
};

NamedRouteDef _exampleRoute({
  required String name,
  required String path,
  required List<AutoRoute> children,
}) =>
    NamedRouteDef(
      name: name,
      path: path,
      type: exampleRouteType,
      builder: (context, data) =>
          const CupertinoEnvironment(child: AutoRouter()),
      children: children,
    );

void main() async {
  await WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // Late, so the examples' home links can navigate with it.
  late final RootStackRouter router;
  router = RootStackRouter.build(
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
        children: heroineRoutes,
      ),
      NamedRouteDef.shell(
        name: 'Motor',
        path: '/motor',
        type: exampleRouteType,
        // The gallery's logo leads back to the landing page.
        children: motorRoutesFor(
          onHome: () => router.navigate(const NamedRoute('Home')),
        ),
      ),
      coilCatalogRoute(
        path: '/coil',
        // The coil wordmark leads back to the landing page, and the
        // catalog's mentions of another package open its example.
        onHome: () => router.navigate(const NamedRoute('Home')),
        onOpenPackage: (package) {
          if (_exampleRouteNames[package] case final name?) {
            router.navigate(NamedRoute(name));
          }
        },
      ),
      _exampleRoute(
        name: 'Stupid Simple Sheet',
        path: '/stupid_simple_sheet',
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
                // Black behind every route: a page that a sheet pushes back
                // and scales down shows this around it, never white.
                child: ColoredBox(
                  color: const Color(0xFF000000),
                  child: child,
                ),
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
