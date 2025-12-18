import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

final controller = TextEditingController();

class KeyboardCardExample extends StatelessWidget {
  const KeyboardCardExample({super.key});

  static const name = 'Keyboard Card';
  static const path = 'keyboard-card';

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
        resizeToAvoidBottomInset: false,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.transparent,
          brightness: Brightness.light,
          middle: SizedBox(),
          enableBackgroundFilterBlur: false,
          automaticBackgroundVisibility: false,
        ),
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: Image.network(
                'https://images.unsplash.com/photo-1506744038136-46273834b3fb?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop',
              ).image,
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Heroine(
                  tag: 0,
                  continuouslyTrackTarget: true,
                  child: Field(
                    index: 0,
                    onPressed: () {
                      Navigator.of(context).push(
                        CardRoute(
                          settings: RouteSettings(name: 'Details'),
                          title: 'Details',
                          builder: (context) => DetailsPage(index: 0),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Field extends StatelessWidget {
  const Field({
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
    return CupertinoUserInterfaceLevel(
      data: CupertinoUserInterfaceLevelData.elevated,
      child: Builder(builder: (context) {
        return FakeGlass(
          settings: LiquidGlassSettings(
            lightIntensity: .6,
            glassColor: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withValues(alpha: .8),
          ),
          shape: LiquidRoundedSuperellipse(borderRadius: 32),
          child: GlassGlowLayer(
            child: GlassGlow(
              child: GestureDetector(
                onTap: onPressed,
                child: Container(
                  color: Colors.transparent,
                  child: CupertinoTextField(
                    placeholder: 'Type something...',
                    textAlignVertical: TextAlignVertical.top,
                    cursorColor:
                        CupertinoTheme.of(context).primaryContrastingColor,
                    controller: controller,
                    autofocus: true,
                    enabled: isFlipped,
                    decoration: BoxDecoration(),
                    padding: const EdgeInsets.all(16.0),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return ReactToHeroineDismiss(
      builder: (context, progress, offset, child) {
        final opacity = 1 - progress;

        return Padding(
          padding: MediaQuery.viewInsetsOf(context),
          child: BackdropFilter(
            filter:
                ImageFilter.blur(sigmaX: opacity * 20, sigmaY: opacity * 20),
            child: child!,
          ),
        );
      },
      child: SafeArea(
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: DragDismissable(
              child: Heroine(
                tag: index,
                continuouslyTrackTarget: true,
                motion:
                    Motion.bouncySpring(duration: Duration(milliseconds: 350)),
                child: AspectRatio(
                  aspectRatio: 2,
                  child: Field(
                    index: index,
                    isFlipped: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CardRoute<T> extends PageRoute<T> with HeroinePageRouteMixin {
  CardRoute({
    required this.settings,
    required this.title,
    required this.builder,
    this.fullscreenDialog = false,
  });

  @override
  final RouteSettings settings;

  final String title;

  final Widget Function(BuildContext context) builder;

  final bool fullscreenDialog;

  @override
  bool get maintainState => false;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => Duration(milliseconds: 300);

  @override
  Color? get barrierColor => Colors.black26;

  @override
  String? get barrierLabel => null;

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (fullscreenDialog) {
      return FadeTransition(opacity: animation, child: child);
    }
    return FadeTransition(opacity: animation, child: child);
  }
}
