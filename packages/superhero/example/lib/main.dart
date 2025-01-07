import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:example/src/settings_menus.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lorem_gen/lorem_gen.dart';
import 'package:springster/springster.dart';
import 'package:superhero/superhero.dart';

final springNotifier = ValueNotifier(SimpleSpring.bouncy);
final flightShuttleNotifier =
    ValueNotifier<SuperheroShuttleBuilder>(const FlipShuttleBuilder());
final adjustSpringTimingToRoute = ValueNotifier(false);
final detailsPageAspectRatio = ValueNotifier(1.0);

void main() async {
  runApp(
    ListenableBuilder(
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
          builder: (context) => SuperheroExample(),
          title: 'Superhero Example',
        ),
        navigatorObservers: [SuperheroController()],
      ),
    ),
  );
}

class SuperheroExample extends StatelessWidget {
  const SuperheroExample({super.key});

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
                  maxCrossAxisExtent: 400,
                  mainAxisSpacing: 32,
                  crossAxisSpacing: 32,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Superhero(
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
            gradient: LinearGradient(
              colors: [
                CupertinoColors.systemGrey5.withValues(blue: .88),
                CupertinoColors.systemGrey3.withValues(blue: .75),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            image: isFlipped
                ? null
                : DecorationImage(
                    image: CachedNetworkImageProvider(
                      'https://picsum.photos/800/800?random=$index',
                    ),
                    fit: BoxFit.cover,
                  ),
          ),
          child: child,
        ),
      ),
      child: isFlipped
          ? Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Image #$index',
                style: CupertinoTheme.of(context)
                    .textTheme
                    .navLargeTitleTextStyle
                    .copyWith(
                      color: CupertinoColors.inactiveGray,
                    ),
              ),
            )
          : const SizedBox.shrink(),
      onPressed: onPressed,
    );
  }
}

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return ReactToSuperheroDismiss(
      builder: (context, progress, offset, child) {
        final opacity = 1 - progress;

        return ClipRect(
          child: BackdropFilter(
            filter:
                ImageFilter.blur(sigmaX: opacity * 20, sigmaY: opacity * 20),
            child: CupertinoPageScaffold(
              backgroundColor: CupertinoTheme.of(context)
                  .scaffoldBackgroundColor
                  .withValues(alpha: opacity),
              child: child!,
            ),
          ),
        );
      },
      child: CustomScrollView(
        slivers: [
          ReactToSuperheroDismiss(
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
                child: SpringBuilder(
                  value: detailsPageAspectRatio.value,
                  spring: SimpleSpring.bouncy,
                  builder: (context, value, child) => AspectRatio(
                    aspectRatio: value,
                    child: DragDismissable(
                      onDismiss: () => Navigator.pop(context),
                      child: child!,
                    ),
                  ),
                  child: Superhero(
                    tag: index,
                    adjustToRouteTransitionDuration:
                        adjustSpringTimingToRoute.value,
                    spring: springNotifier.value,
                    flightShuttleBuilder: flightShuttleNotifier.value,
                    child: Cover(
                      index: index,
                      isFlipped: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
            ),
          ),
          ReactToSuperheroDismiss(
            builder: (context, progress, offset, child) {
              final opacity = 1 - progress;
              return SliverOpacity(
                opacity: opacity,
                sliver: child!,
              );
            },
            child: SliverToBoxAdapter(
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
            ),
          )
        ],
      ),
    );
  }
}

class MyCustomRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin, SuperheroPageRouteMixin {
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