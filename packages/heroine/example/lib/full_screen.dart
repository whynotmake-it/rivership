import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine_example/main.dart';
import 'package:heroine_example/src/settings_menus.dart';

final springNotifier = ValueNotifier(Spring());
final flightShuttleNotifier =
    ValueNotifier<HeroineShuttleBuilder>(const FadeThroughShuttleBuilder());
final adjustSpringTimingToRoute = ValueNotifier(false);
final detailsPageAspectRatio = ValueNotifier(1.0);

void main() async {
  runApp(FullscreenHeroineExampleApp());
}

class FullscreenHeroineExampleApp extends StatelessWidget {
  const FullscreenHeroineExampleApp({super.key});

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
      builder: (context, child) => CupertinoApp(
        debugShowCheckedModeBanner: false,
        onGenerateRoute: (settings) => MyCustomRoute(
          builder: (context) => FullscreenHeroineExample(),
          title: 'Fullscreen Heroine Example',
        ),
        navigatorObservers: [HeroineController()],
      ),
    );
  }
}

class FullscreenHeroineExample extends StatelessWidget {
  const FullscreenHeroineExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: ModalRoute.of(context)?.secondaryAnimation ??
          AlwaysStoppedAnimation(0),
      builder: (context, value, child) {
        final easedValue = Easing.standard.flipped.transform(value);

        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            CupertinoTheme.of(context)
                .barBackgroundColor
                .withValues(alpha: .5 * easedValue),
            BlendMode.srcOver,
          ),
          child: child!,
        );
      },
      child: CupertinoPageScaffold(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              trailing: MainSettingsButton(),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  mainAxisSpacing: 32,
                  crossAxisSpacing: 32,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Heroine(
                    tag: index,
                    spring: springNotifier.value,
                    adjustToRouteTransitionDuration:
                        adjustSpringTimingToRoute.value,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text('Go To Details $index'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MyCustomRoute(
                            fullscreenDialog: true,
                            title: 'Details',
                            builder: (context) => DetailsPage(index: index),
                          ),
                        );
                      },
                    ),
                  ),
                  childCount: 100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return FullscreenHeroine(
      flightShuttleBuilder: flightShuttleNotifier.value,
      tag: index,
      child: CupertinoPageScaffold(
        child: CustomScrollView(
          slivers: [
            ReactToHeroineDismiss(
              builder: (context, progress, offset, child) {
                final opacity = 1 - progress;
                return SliverOpacity(
                  opacity: opacity,
                  sliver: child!,
                );
              },
              child: CupertinoSliverNavigationBar(largeTitle: SizedBox()),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 16,
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: Heroine(
                  tag: 'detail',
                  adjustToRouteTransitionDuration:
                      adjustSpringTimingToRoute.value,
                  spring: springNotifier.value,
                  flightShuttleBuilder: FadeShuttleBuilder(),
                  child: SizedBox(
                    width: 400,
                    height: 200,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: CupertinoColors.systemYellow,
                        foregroundColor: CupertinoColors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text('Go even Deeper'),
                      onPressed: () => Navigator.push(
                        context,
                        MyCustomRoute(
                          fullscreenDialog: true,
                          title: 'Second Details Page',
                          builder: (context) => const SecondDetailsPage(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SecondDetailsPage extends StatelessWidget {
  const SecondDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FullscreenHeroine(
      flightShuttleBuilder: FadeShuttleBuilder(),
      tag: 'detail',
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemYellow,
        navigationBar: CupertinoNavigationBar(
          middle: Text('The deepest'),
        ),
        child: Center(
          child: Text('This is the end.'),
        ),
      ),
    );
  }
}

class FullscreenHeroine extends StatelessWidget {
  const FullscreenHeroine({
    super.key,
    required this.tag,
    required this.flightShuttleBuilder,
    required this.child,
  });

  final Object tag;
  final HeroineShuttleBuilder flightShuttleBuilder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragDismissable(
      child: ReactToHeroineDismiss(
        builder: (context, progress, offset, child) => Transform.scale(
          scale: 1 - progress * 0.2,
          child: Heroine(
            tag: tag,
            adjustToRouteTransitionDuration: adjustSpringTimingToRoute.value,
            spring: springNotifier.value,
            flightShuttleBuilder: flightShuttleBuilder,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.hardEdge,
              elevation: progress > 0 ? 24 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(progress > 0 ? 32 : 0),
              ),
              child: child,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
