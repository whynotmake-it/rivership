import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/font_licenses.dart';
import 'package:motor_example/home.dart';
import 'package:motor_example/shell/devtools_switch.dart';
import 'package:motor_example/shell/motor_shell.dart';

export 'package:motor_example/shell/devtools_switch.dart' show devtoolsVisible;

/// Runs the gallery on its own. It is a bare [WidgetsApp]: coil needs no
/// Material or Cupertino app.
///
/// Build with `--dart-define=MOTOR_DEVTOOLS=false` to remove the tools.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  runApp(
    ValueListenableBuilder(
      valueListenable: devtoolsVisible,
      builder: (context, visible, child) => MotorDevTools(
        // The gallery ships the tools on purpose, also in release builds.
        enabled: true,
        visible: visible,
        motions: const {
          'Smooth': .smoothSpring(),
          'Snappy': .snappySpring(),
          'Bouncy': .bouncySpring(),
        },
        child: child!,
      ),
      child: WidgetsApp.router(
        title: 'Motor',
        color: const Color(0xFF6B97FF),
        debugShowCheckedModeBanner: false,
        routerConfig: router.config(),
      ),
    ),
  );
}

/// How the gallery's pages come and go: in place, at once. The sidebar is
/// how you move around, so a page swaps rather than pushes.
final _pageRouteType = RouteType.custom(
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      Offstage(
        offstage: animation.status == AnimationStatus.reverse,
        child: child,
      ),
);

/// The gallery's routes, for mounting it inside another app:
///
/// ```dart
/// NamedRouteDef.shell(name: 'Motor', path: '/motor', children: motorRoutes)
/// ```
///
/// One shell route holds the sidebar; the overview and every demo are its
/// children.
final motorRoutes = <AutoRoute>[
  NamedRouteDef(
    name: 'Motor gallery',
    path: '',
    type: _pageRouteType,
    builder: (context, state) => const MotorShell(),
    children: [
      NamedRouteDef(
        name: overviewRouteName,
        path: '',
        type: _pageRouteType,
        builder: (context, state) => const HomePage(),
      ),
      for (final chapter in chapters)
        NamedRouteDef(
          name: chapter.title,
          path: chapter.path,
          type: _pageRouteType,
          builder: (context, state) => chapter.page(),
        ),
    ],
  ),
];

/// The router of the standalone gallery.
final router = RootStackRouter.build(
  routes: [NamedRouteDef.shell(name: 'Home', path: '/', children: motorRoutes)],
);
