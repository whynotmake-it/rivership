/// Sheet transitions for the iOS 26 liquid glass style.
///
/// Reuses shared constants and helpers from [cupertino_sheet_copy.dart].
/// Only the methods that differ from [CopiedCupertinoSheetTransitions] are
/// defined here.
library;
// ignore_for_file: type=lint

import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/src/clamped_animation.dart';
import 'package:stupid_simple_sheet/src/cupertino_sheet_copy.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

abstract class GlassSheetTransitions {
  /// Reuses the identical implementation from the iOS 18 transitions.
  static Widget? secondarySlideDownTransition(
    BuildContext context, {
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required (double, double) opacityRange,
    required (double, double) slideBackRange,
    required ShapeBorder primaryShape,
    Widget? child,
  }) {
    return CopiedCupertinoSheetTransitions.secondarySlideDownTransition(
      context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      opacityRange: opacityRange,
      slideBackRange: slideBackRange,
      primaryShape: primaryShape,
      child: child,
    );
  }

  static Widget secondarySlideUpTransition(
    BuildContext context, {
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required ShapeBorder shape,
    required (double, double) opacityRange,
    required (double, double) slideBackRange,
    required Color backgroundColor,
    required bool secondSheet,
    Widget? child,
  }) {
    final slideAnimation = secondSheet
        ? secondaryAnimation
            .remapped(
              start: slideBackRange.$1,
              end: slideBackRange.$2,
            )
            .drive(
              Tween<Offset>(
                begin: Offset(0, 0),
                end: Offset(
                  0,
                  -kSheetPaddingToPrevious / MediaQuery.sizeOf(context).height,
                ),
              ),
            )
        : AlwaysStoppedAnimation(Offset.zero);
    return SlideTransition(
      position: slideAnimation,
      transformHitTests: false,
      child: ScaleTransition(
        scale: secondaryAnimation
            .remapped(
              start: slideBackRange.$1,
              end: slideBackRange.$2,
            )
            .drive(kScaleTween),
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.medium,
        child: SheetBackground(
          shape: shape,
          backgroundColor: CupertinoDynamicColor.resolve(
            backgroundColor,
            context,
          ),
          child: getOverlayedChild(
            context,
            child,
            secondaryAnimation.remapped(
              start: opacityRange.$1,
              end: opacityRange.$2,
            ),
            true,
          ),
        ),
      ),
    );
  }

  static Widget fullTransition(
    BuildContext context, {
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required (double, double) opacityRange,
    required (double, double) slideBackRange,
    required Color backgroundColor,
    required bool secondSheet,
    ShapeBorder shape = const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(36),
      ),
    ),
    Widget? child,
  }) {
    final offsetTween = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset(0, 0),
    );

    final Animation<Offset> positionAnimation = animation.drive(offsetTween);

    return Builder(
      builder: (context) {
        return SafeArea(
          left: false,
          right: false,
          bottom: false,
          minimum:
              EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.05),
          child: Padding(
            padding:
                EdgeInsets.only(top: secondSheet ? kSheetPaddingToPrevious : 0),
            child: SlideTransition(
              position: positionAnimation,
              child: secondarySlideUpTransition(
                context,
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                shape: shape,
                opacityRange: opacityRange,
                slideBackRange: slideBackRange,
                backgroundColor: backgroundColor,
                secondSheet: secondSheet,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
