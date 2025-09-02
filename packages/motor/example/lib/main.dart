import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor_example/2d_redirection.dart';
import 'package:motor_example/draggable_icons.dart';
import 'package:motor_example/flip_card.dart';
import 'package:motor_example/one_dimension.dart';
import 'package:motor_example/phase_animation/phase_animation.dart';
import 'package:motor_example/pip.dart';
import 'package:motor_example/title_slide.dart';

void main() async {
  runApp(
    CupertinoApp.router(
      routerConfig: router.config(),
    ),
  );
}

final motorRoutes = [
  NamedRouteDef(
    name: 'Motor Examples',
    path: '',
    type: RouteType.cupertino(),
    builder: (context, state) => const MotorExample(),
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
  NamedRouteDef(
    name: TitleSlideExample.name,
    path: TitleSlideExample.path,
    type: RouteType.cupertino(),
    builder: (context, state) => TitleSlideExample(),
  ),
  NamedRouteDef(
    name: SequenceAnimationExamples.name,
    path: SequenceAnimationExamples.path,
    type: RouteType.cupertino(),
    builder: (context, state) => const SequenceAnimationExamples(),
  ),
];

final router = RootStackRouter.build(
  routes: [
    NamedRouteDef.shell(
      name: 'Home',
      path: '/',
      type: RouteType.cupertino(),
      children: motorRoutes,
    ),
  ],
);

class MotorExample extends StatelessWidget {
  const MotorExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  for (final route in motorRoutes) ...[
                    if (route.path != '')
                      buildDestinationButton(context, route.name),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget buildDestinationButton(BuildContext context, String name) {
    return CupertinoButton.filled(
      onPressed: () => context.navigateTo(NamedRoute(name)),
      child: Text(name),
    );
  }
}
