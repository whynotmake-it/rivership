import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:motor_example/main.dart';
import 'package:heroine_example/main.dart';
import 'package:springster_example/main.dart';
import 'package:stupid_simple_sheet_example/main.dart';

void main() async {
  await WidgetsFlutterBinding.ensureInitialized();
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
      NamedRouteDef.shell(
        name: 'Springster',
        path: '/springster',
        children: springsterRoutes,
      ),
      NamedRouteDef.shell(
        name: 'Stupid Simple Sheet',
        path: '/stupid_simple_sheet',
        children: stupidSimpleSheetRoutes,
      ),
    ],
  );

  runApp(
    CupertinoApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router.config(
        navigatorObservers: () => [
          HeroineController(),
          HeroController(),
        ],
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
        padding: const EdgeInsets.all(32),
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
            onPressed: () => context.navigateTo(NamedRoute('Springster')),
            child: const Text('Springster'),
          ),
          CupertinoButton.filled(
            onPressed: () =>
                context.navigateTo(NamedRoute('Stupid Simple Sheet')),
            child: const Text('Stupid Simple Sheet'),
          ),
        ],
      ),
    );
  }
}
