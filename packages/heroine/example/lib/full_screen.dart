import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine_example/main.dart';
import 'package:heroine_example/src/settings_menus.dart';
import 'package:springster/springster.dart';

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
                    child: Cover(
                      index: index,
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

class Cover extends StatelessWidget {
  const Cover({
    super.key,
    required this.index,
    this.onPressed,
    this.isFlipped = false,
  });

  final int index;
  final bool isFlipped;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = SmoothRectangleBorder(
      borderRadius: SmoothBorderRadius(
        cornerRadius: 32,
        cornerSmoothing: .6,
      ),
    );
    return FilledButton(
      style: FilledButton.styleFrom(
        splashFactory: NoSplash.splashFactory,
        padding: EdgeInsets.all(32),
        shape: shape,
        backgroundColor:
            !isFlipped ? Colors.transparent : CupertinoColors.systemGrey4,
        foregroundColor:
            !isFlipped ? CupertinoColors.white : CupertinoColors.black,
        shadowColor: Colors.brown.withValues(alpha: .3),
        elevation: isFlipped ? 24 : 8,
        backgroundBuilder: (context, states, child) => DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            gradient: isFlipped
                ? LinearGradient(
                    colors: [
                      CupertinoColors.systemGrey5.withValues(blue: .88),
                      CupertinoColors.systemGrey3.withValues(blue: .75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            image: isFlipped
                ? null
                : DecorationImage(
                    image: CachedNetworkImageProvider(
                      'https://picsum.photos/800/800?random=$index',
                      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                    ),
                    fit: BoxFit.cover,
                  ),
          ),
          child: child,
        ),
      ),
      child: Align(
        alignment: isFlipped ? Alignment.bottomLeft : Alignment.center,
        child: Heroine(
          tag: 'detail $index',
          child: Text(
            'Image #$index',
            style: CupertinoTheme.of(context)
                .textTheme
                .navLargeTitleTextStyle
                .copyWith(
                  color: CupertinoColors.inactiveGray,
                ),
          ),
        ),
      ),
      onPressed: onPressed,
    );
  }
}

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return FullscreenHeroine(
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
              child: CupertinoSliverNavigationBar(
                largeTitle: SizedBox(),
                trailing: DetailsPageSettingsButton(),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 16,
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: MediaQuery.sizeOf(context).height * .5,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Center(
                  child: SingleMotionBuilder(
                    value: detailsPageAspectRatio.value,
                    motion: SpringMotion(Spring.bouncy),
                    builder: (context, value, child) => AspectRatio(
                      aspectRatio: value,
                      child: child!,
                    ),
                    child: Heroine(
                      tag: 'detail',
                      adjustToRouteTransitionDuration:
                          adjustSpringTimingToRoute.value,
                      spring: springNotifier.value,
                      flightShuttleBuilder: flightShuttleNotifier.value,
                      child: Cover(
                        index: index,
                        isFlipped: true,
                        onPressed: () => Navigator.push(
                          context,
                          MyCustomRoute(
                            title: 'Second Details Page',
                            builder: (context) => const SecondDetailsPage(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 48)),
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Details',
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .color
                                    ?.withValues(alpha: .8),
                              ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          lorem,
                          style: CupertinoTheme.of(context).textTheme.textStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
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
      tag: 'detail',
      child: const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(),
        child: Center(
          child: Text('Second Details Page'),
        ),
      ),
    );
  }
}

class FullscreenHeroine extends StatelessWidget {
  const FullscreenHeroine({
    super.key,
    required this.child,
    required this.tag,
  });

  final Object tag;
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
            flightShuttleBuilder: flightShuttleNotifier.value,
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
