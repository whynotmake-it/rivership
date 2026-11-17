/// Sheet transitions for the iOS 26 liquid glass style.
///
/// Reuses shared constants and helpers from [cupertino_sheet_copy.dart].
/// Only the methods that differ from [CopiedCupertinoSheetTransitions] are
/// defined here.
library;
// ignore_for_file: type=lint

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:stupid_simple_sheet/src/clamped_animation.dart';
import 'package:stupid_simple_sheet/src/cupertino_sheet_copy.dart';
import 'package:stupid_simple_sheet/src/sheet_recede.dart';
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
    ValueListenable<double>? recedeFactor,
    PresentationSizing sizing = PresentationSizing.automatic,
    Widget? child,
  }) {
    final recede = secondaryAnimation
        .remapped(
          start: slideBackRange.$1,
          end: slideBackRange.$2,
        )
        .scaledBy(recedeFactor);
    final slideAnimation = secondSheet
        ? recede.drive(
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
        scale: recede.drive(kScaleTween),
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
            sizing: sizing,
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
    DismissalMode dismissalMode = DismissalMode.slide,
    ShapeBorder shape = const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(36),
      ),
    ),
    PresentationSizing sizing = PresentationSizing.automatic,
    ValueListenable<double>? recedeFactor,
    ValueNotifier<double>? reportRecedeFactorTo,
    Widget? child,
  }) {
    final secondaryChild = secondarySlideUpTransition(
      context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      shape: shape,
      opacityRange: opacityRange,
      slideBackRange: slideBackRange,
      backgroundColor: backgroundColor,
      secondSheet: secondSheet,
      recedeFactor: recedeFactor,
      sizing: sizing,
      child: child,
    );

    final sheet = SheetDismissalTransition(
      animation: animation,
      dismissalMode: dismissalMode,
      // Attached to the bottom edge, the sheet always takes the full width,
      // and the full height unless it fits its content's height.
      child: SizedBox(
        width: double.infinity,
        height: sizing.sizesHeightToContent ? null : double.infinity,
        child: secondaryChild,
      ),
    );

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
            child: Align(
              alignment: Alignment.bottomCenter,
              child: reportRecedeFactorTo == null
                  ? sheet
                  : SheetRecedeReporter(
                      recedeFactor: reportRecedeFactorTo,
                      child: sheet,
                    ),
            ),
          ),
        );
      },
    );
  }
}
