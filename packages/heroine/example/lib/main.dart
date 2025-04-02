import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine_example/classic.dart';
import 'package:heroine_example/full_screen.dart';
import 'package:lorem_gen/lorem_gen.dart';

final springNotifier = ValueNotifier(Spring.bouncy);
final flightShuttleNotifier =
    ValueNotifier<HeroineShuttleBuilder>(const FlipShuttleBuilder());
final adjustSpringTimingToRoute = ValueNotifier(false);
final detailsPageAspectRatio = ValueNotifier(1.0);

void main() async {
  runApp(HeroineExampleApp());
}

final router = RootStackRouter.build(
  routes: [
    NamedRouteDef.shell(
      name: 'Home',
      path: '/',
      type: RouteType.cupertino(),
      children: [
        NamedRouteDef(
          name: 'Heroine Example',
          path: '',
          type: RouteType.cupertino(),
          builder: (context, _) => HeroineExamplePicker(),
        ),
        NamedRouteDef(
          name: 'Classic',
          path: 'picker',
          type: RouteType.cupertino(),
          builder: (context, _) => HeroineExample(),
        ),
        NamedRouteDef(
          name: 'Container Transform',
          path: 'fullscreen',
          type: RouteType.cupertino(),
          builder: (context, _) => FullscreenHeroineExample(),
        ),
      ],
    ),
  ],
);

class HeroineExampleApp extends StatelessWidget {
  const HeroineExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
        [
          springNotifier,
          flightShuttleNotifier,
          adjustSpringTimingToRoute,
          detailsPageAspectRatio,
        ],
      ),
      builder: (context, child) => CupertinoApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router.config(
          navigatorObservers: () => [HeroineController()],
        ),
      ),
    );
  }
}

class HeroineExamplePicker extends StatelessWidget {
  const HeroineExamplePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(),
          SliverPadding(
            padding: const EdgeInsets.all(32),
            sliver: SliverList.list(
              children: [
                CupertinoButton.filled(
                  onPressed: () => context.navigateTo(NamedRoute('Classic')),
                  child: const Text('Classic'),
                ),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  onPressed: () =>
                      context.navigateTo(NamedRoute('Container Transform')),
                  child: const Text('Fullscreen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyCustomRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin, HeroinePageRouteMixin {
  MyCustomRoute({
    required this.title,
    required this.builder,
    this.fullscreenDialog = false,
  });

  final String title;

  final Widget Function(BuildContext context) builder;

  final bool fullscreenDialog;

  @override
  bool get maintainState => false;

  @override
  bool get opaque => false;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  bool canTransitionTo(TransitionRoute nextRoute) {
    return super.canTransitionTo(nextRoute) ||
        nextRoute is MyCustomRoute && nextRoute.fullscreenDialog;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return CupertinoRouteTransitionMixin.buildPageTransitions(
      this,
      context,
      animation,
      AlwaysStoppedAnimation(0),
      child,
    );
  }
}

final lorem = Lorem.paragraph(numParagraphs: 10);
