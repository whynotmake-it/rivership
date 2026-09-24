import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/font_licenses.dart';
import 'package:motor_example/home.dart';

/// Whether the motor devtools overlay is shown. The home screen toggles it;
/// the tools keep tracking while hidden, so nothing is lost.
///
/// Build with `--dart-define=MOTOR_DEVTOOLS=false` to remove the tools.
final devtoolsEnabled = ValueNotifier(true);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  runApp(
    ValueListenableBuilder(
      valueListenable: devtoolsEnabled,
      builder: (context, visible, child) => MotorDevTools(
        visible: visible,
        motions: const {
          'Smooth': .smoothSpring(),
          'Snappy': .snappySpring(),
          'Bouncy': .bouncySpring(),
        },
        child: child!,
      ),
      child: CupertinoApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router.config(),
      ),
    ),
  );
}

final motorRoutes = [
  NamedRouteDef(
    name: 'Motor 2.0',
    path: '',
    type: const RouteType.cupertino(),
    builder: (context, state) => const HomePage(),
  ),
  for (final chapter in chapters)
    NamedRouteDef(
      name: chapter.title,
      path: chapter.path,
      type: const RouteType.cupertino(),
      builder: (context, state) => chapter.page(),
    ),
];

final router = RootStackRouter.build(
  routes: [
    NamedRouteDef.shell(
      name: 'Home',
      path: '/',
      type: const RouteType.cupertino(),
      children: motorRoutes,
    ),
  ],
);
