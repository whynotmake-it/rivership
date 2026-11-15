import 'package:auto_route/auto_route.dart';
import 'package:coil_example/coil_example.dart';
import 'package:flutter/cupertino.dart';
import 'package:heroine_example/main.dart';
import 'package:merging_dots_example/main.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_example/font_licenses.dart';
import 'package:motor_example/main.dart';
import 'package:rivership/rivership.dart';
import 'package:stupid_simple_sheet_example/main.dart';

void main() async {
  await WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final router = RootStackRouter.build(
    routes: [
      NamedRouteDef(
        path: '/',
        name: 'Home',
        type: RouteType.cupertino(),
        builder: (context, state) => const Home(),
      ),
      NamedRouteDef.shell(
        path: '/heroine',
        name: 'Heroine',
        children: heroineRoutes,
      ),
      NamedRouteDef.shell(
        name: 'Motor',
        path: '/motor',
        children: motorRoutes,
      ),
      NamedRouteDef(
        name: 'Merging Dots',
        path: '/merging_dots',
        type: RouteType.cupertino(),
        builder: (context, state) => const MergingDotsEditor(),
      ),
      coilCatalogRoute(path: '/coil'),
      NamedRouteDef.shell(
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
        // The gallery ships the tools on purpose, also in release builds.
        enabled: true,
        visible: devtoolsVisible.value || coilDevtoolsVisible.value,
        child: child!,
      ),
      child: CupertinoApp.router(
        debugShowCheckedModeBanner: false,
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

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: GridView.count(
        padding: MediaQuery.viewPaddingOf(context) + const EdgeInsets.all(32),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          CupertinoButton.filled(
            onPressed: () => context.navigateTo(NamedRoute('Heroine')),
            child: const Text('Heroine'),
          ),
          CupertinoButton.filled(
            onPressed: () => context.navigateTo(NamedRoute('Motor')),
            child: const Text('Motor'),
          ),
          CupertinoButton.filled(
            onPressed: () => context.navigateTo(NamedRoute('Coil')),
            child: const Text('coil'),
          ),
          CupertinoButton.filled(
            onPressed: () =>
                context.navigateTo(NamedRoute('Stupid Simple Sheet')),
            child: const Text('Stupid Simple Sheet'),
          ),
          CupertinoButton.filled(
            onPressed: () => context.navigateTo(NamedRoute('Merging Dots')),
            child: const Text('Merging Dots'),
          ),
        ],
      ),
    );
  }
}
