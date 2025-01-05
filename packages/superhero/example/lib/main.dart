import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:superhero/superhero.dart';

void main() async {
  runApp(CupertinoApp(
    onGenerateRoute: (settings) => CupertinoPageRoute(
      builder: (context) => SuperheroExample(),
      title: 'Superhero Example',
    ),
    navigatorObservers: [SuperheroController()],
  ));
}

class SuperheroExample extends StatelessWidget {
  const SuperheroExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(),
          SliverPadding(
            padding: const EdgeInsets.all(32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 32,
                crossAxisSpacing: 32,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => Superhero(
                  transitionOnUserGestures: true,
                  tag: index,
                  spring: SimpleSpring.snappy,
                  child: Cover(
                    index: index,
                    onPressed: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                        fullscreenDialog: true,
                        title: 'Page 2',
                        builder: (context) => Page2(index: index),
                      ),
                    ),
                  ),
                ),
                childCount: 100,
              ),
            ),
          ),
        ],
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
    return AspectRatio(
      aspectRatio: 1,
      child: FilledButton(
        style: FilledButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(48),
          ),
          backgroundColor: !isFlipped
              ? CupertinoColors.systemPink
              : CupertinoColors.systemGrey4,
          foregroundColor:
              !isFlipped ? CupertinoColors.white : CupertinoColors.black,
          elevation: 8,
          shadowColor: CupertinoColors.systemPink.withValues(alpha: .2),
        ),
        child: Text(isFlipped ? 'Button $index details' : 'Button $index'),
        onPressed: onPressed,
      ),
    );
  }
}

class Page2 extends StatelessWidget {
  const Page2({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 16,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .5,
              child: Center(
                child: Superhero(
                  spring: SimpleSpring.bouncy,
                  transitionOnUserGestures: true,
                  flightShuttleBuilder: (flightContext, animation,
                      flightDirection, fromHeroContext, toHeroContext) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final realValue =
                            flightDirection == HeroFlightDirection.push
                                ? animation.value
                                : 1 - animation.value;

                        final angle = realValue * pi;

                        final perspective = Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(-angle);

                        return Transform(
                          alignment: FractionalOffset.center,
                          filterQuality: FilterQuality.none,
                          transform: perspective,
                          child: realValue > 0.5
                              ? Transform.flip(
                                  flipX: true,
                                  child: toHeroContext.widget,
                                )
                              : fromHeroContext.widget,
                        );
                      },
                    );
                  },
                  tag: index,
                  child: Cover(
                    index: index,
                    isFlipped: true,
                    onPressed: () => Navigator.pop(context),
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
