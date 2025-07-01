import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:springster_example/2d_redirection.dart';
import 'package:springster_example/draggable_icons.dart';
import 'package:springster_example/flip-card.dart';
import 'package:springster_example/one_dimension.dart';
import 'package:springster_example/pip.dart';

void main() async {
  runApp(SpringsterExampleApp());
}

final springsterRoutes = [
  NamedRouteDef(
    name: 'Springster Examples',
    path: '',
    type: RouteType.cupertino(),
    builder: (context, state) => const SpringsterExample(),
  ),
  NamedRouteDef(
    name: OneDimensionExample.name,
    path: OneDimensionExample.path,
    type: RouteType.cupertino(),
    builder: (context, state) => OneDimensionExample(),
  ),
  NamedRouteDef(
    name: TwoDimensionRedirectionExample.name,
    path: TwoDimensionRedirectionExample.path,
    type: RouteType.cupertino(),
    builder: (context, state) => TwoDimensionRedirectionExample(),
  ),
  NamedRouteDef(
    name: DraggableIconsExample.name,
    path: DraggableIconsExample.path,
    type: RouteType.cupertino(),
    builder: (context, state) => DraggableIconsExample(),
  ),
  NamedRouteDef(
    name: PipExample.name,
    path: PipExample.path,
    type: RouteType.cupertino(),
    builder: (context, state) => PipExample(),
  ),
  NamedRouteDef(
    name: FlipCardExample.name,
    path: FlipCardExample.path,
    type: RouteType.cupertino(),
    builder: (context, state) => FlipCardExample(),
  ),
];

final router = RootStackRouter.build(
  routes: [
    NamedRouteDef.shell(
      name: 'Home',
      path: '/',
      type: RouteType.cupertino(),
      children: springsterRoutes,
    ),
  ],
);

class SpringsterExampleApp extends StatelessWidget {
  const SpringsterExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp.router(
      routerConfig: router.config(),
    );
  }
}

class SpringsterExample extends StatelessWidget {
  const SpringsterExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(),
      child: ExamplesList(),
    );
  }
}

class ExamplesList extends StatelessWidget {
  const ExamplesList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16) + MediaQuery.paddingOf(context),
      children: [
        CupertinoButton.tinted(
          onPressed: () => context.navigateToPath(OneDimensionExample.path),
          child: const Text(OneDimensionExample.name),
        ),
        const SizedBox(height: 16),
        CupertinoButton.tinted(
          onPressed: () =>
              context.navigateToPath(TwoDimensionRedirectionExample.path),
          child: const Text(TwoDimensionRedirectionExample.name),
        ),
        const SizedBox(height: 16),
        CupertinoButton.tinted(
          onPressed: () => context.navigateToPath(DraggableIconsExample.path),
          child: const Text(DraggableIconsExample.name),
        ),
        const SizedBox(height: 16),
        CupertinoButton.tinted(
          onPressed: () => context.navigateToPath(PipExample.path),
          child: const Text(PipExample.name),
        ),
        const SizedBox(height: 16),
        CupertinoButton.tinted(
          onPressed: () => context.navigateToPath(FlipCardExample.path),
          child: const Text(FlipCardExample.name),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
