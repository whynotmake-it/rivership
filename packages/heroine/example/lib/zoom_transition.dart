import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine_example/src/settings_menus.dart';

final springNotifier = ValueNotifier(CupertinoMotion.smooth());
final flightShuttleNotifier =
    ValueNotifier<HeroineShuttleBuilder>(const FadeThroughShuttleBuilder());
final detailsPageAspectRatio = ValueNotifier(1.0);

final zoomTransitionRoutes = [
  NamedRouteDef(
    name: ZoomTransitionExample.name,
    path: ZoomTransitionExample.path,
    type: RouteType.cupertino(),
    builder: (context, _) => ZoomTransitionExample(),
  ),
  NamedRouteDef(
    name: DetailsPage.name,
    path: DetailsPage.path,
    type: RouteType.custom(
      customRouteBuilder: <T>(
        context,
        child,
        page,
      ) =>
          HeroineZoomRoute(
        title: page.routeData.name,
        tag: page.routeData.params.getInt('index'),
        settings: page,
        builder: (context) => child,
      ),
    ),
    builder: (context, data) => DetailsPage(index: data.params.getInt('index')),
  ),
  NamedRouteDef(
    name: SecondDetailsPage.name,
    path: SecondDetailsPage.path,
    type: RouteType.custom(
      customRouteBuilder: <T>(
        BuildContext context,
        Widget child,
        AutoRoutePage<T> page,
      ) =>
          HeroineZoomRoute<T>(
        settings: page,
        title: page.routeData.name,
        builder: (context) => child,
      ),
    ),
    builder: (context, _) => const SecondDetailsPage(),
  ),
];

class ZoomTransitionExample extends StatelessWidget {
  const ZoomTransitionExample({super.key});

  static const name = 'Zoom Transition';
  static const path = 'zoom';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        springNotifier,
        flightShuttleNotifier,
        detailsPageAspectRatio,
      ]),
      builder: (context, child) => ValueListenableBuilder<double>(
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
                      motion: springNotifier.value,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text('Go To Details $index'),
                        onPressed: () {
                          context.navigateTo(
                            NamedRoute(
                              DetailsPage.name,
                              params: {
                                'index': index,
                              },
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
      ),
    );
  }
}

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.index});

  static const name = 'Details';
  static const path = 'details';

  final int index;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
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
            child: CupertinoSliverNavigationBar(
              previousPageTitle: ZoomTransitionExample.name,
              largeTitle: Text('Details $index'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 16,
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: Heroine(
                tag: SecondDetailsPage.name,
                motion: springNotifier.value,
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
                    onPressed: () => context.navigateTo(
                      NamedRoute(SecondDetailsPage.name),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SecondDetailsPage extends StatelessWidget {
  const SecondDetailsPage({super.key});

  static const name = 'Second Details';
  static const path = 'second-details';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemYellow,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: DetailsPage.name,
        middle: Text(name),
      ),
      child: Center(
        child: Text('This is the end.'),
      ),
    );
  }
}

class HeroineZoomRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin, HeroinePageRouteMixin {
  HeroineZoomRoute({
    required this.title,
    required this.settings,
    required this.builder,
    Object? tag,
    this.fullscreenDialog = false,
  }) : tag = tag ?? title;

  @override
  final String title;

  @override
  final RouteSettings settings;

  final Object tag;

  final Widget Function(BuildContext context) builder;

  @override
  final bool fullscreenDialog;

  @override
  bool get maintainState => false;

  @override
  bool get opaque => false;

  @override
  Widget buildContent(BuildContext context) => HeroMode(
        // Flutter heroes begone
        enabled: false,
        child: DragDismissable(
          child: ReactToHeroineDismiss(
            builder: (context, progress, offset, child) => Transform.scale(
              scale: 1 - progress * 0.2,
              child: Heroine(
                tag: tag,
                motion: springNotifier.value,
                flightShuttleBuilder: FadeShuttleBuilder(),
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
            child: builder(context),
          ),
        ),
      );

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return child;
    //return FadeTransition(opacity: animation, child: child);
  }

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) {
        final overlayColor = switch (Theme.of(context).brightness) {
          Brightness.light => CupertinoColors.black,
          Brightness.dark => CupertinoColors.white,
        };
        return ValueListenableBuilder<double>(
          valueListenable: this.animation!,
          builder: (context, value, child) => ColorFiltered(
            colorFilter: ColorFilter.mode(
              overlayColor.withValues(alpha: value * .0),
              BlendMode.srcOver,
            ),
            child: ColoredBox(
              color: value > 0
                  ? CupertinoTheme.of(context).scaffoldBackgroundColor
                  : Colors.transparent,
              child: Transform.scale(
                scale: 1,
                child: child,
              ),
            ),
          ),
          child: child,
        );
      };
}
