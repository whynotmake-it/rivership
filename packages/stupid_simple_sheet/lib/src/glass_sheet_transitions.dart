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
    double? extensionAtBottom,
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
          extensionAtBottom: extensionAtBottom,
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
    DismissalMode dismissalMode = DismissalMode.slide,
    ShapeBorder shape = const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(36),
      ),
    ),
    bool formSheet = false,
    bool isStacked = false,
    double formSheetWidth = 580,
    double formSheetMinHorizontalMargin = 40,
    double formSheetMaxHeight = 650,
    double formSheetMinVerticalMargin = 64,
    Widget? child,
  }) {
    final effectiveShape = formSheet ? toFormSheetShape(shape) : shape;

    final secondaryChild = secondarySlideUpTransition(
      context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      shape: effectiveShape,
      opacityRange: opacityRange,
      slideBackRange: slideBackRange,
      backgroundColor: backgroundColor,
      secondSheet: secondSheet,
      extensionAtBottom: formSheet ? 0 : null,
      child: child,
    );

    if (formSheet) {
      return Builder(
        builder: (context) {
          final screenSize = MediaQuery.sizeOf(context);
          final viewInsets = MediaQuery.viewInsetsOf(context);
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, (1 - animation.value) * screenSize.height),
                child: child,
              );
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: formSheetMinHorizontalMargin,
                right: formSheetMinHorizontalMargin,
                top: viewInsets.top +
                    formSheetMinVerticalMargin +
                    (secondSheet ? kFormSheetPaddingToPrevious : 0),
                bottom: viewInsets.bottom +
                    formSheetMinVerticalMargin +
                    kFormSheetBottomInset,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: formSheetWidth,
                    maxHeight: formSheetMaxHeight,
                  ),
                  child: secondaryChild,
                ),
              ),
            ),
          );
        },
      );
    }

    return Builder(
      builder: (context) {
        return SafeArea(
          left: false,
          right: false,
          bottom: false,
          minimum:
              EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.05),
          child: Padding(
            padding: EdgeInsets.only(top: secondSheet ? 0 : 0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SheetDismissalTransition(
                animation: animation,
                dismissalMode: dismissalMode,
                child: secondaryChild,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Returns a version of [shape] with all corners rounded, suitable for
  /// form sheet presentation where the sheet is not edge-attached.
  static ShapeBorder toFormSheetShape(ShapeBorder shape) {
    if (shape is RoundedSuperellipseBorder) {
      final radius = shape.borderRadius.resolve(TextDirection.ltr).topLeft;
      return RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(radius),
      );
    }
    if (shape is RoundedRectangleBorder) {
      final radius = shape.borderRadius.resolve(TextDirection.ltr).topLeft;
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.all(radius),
      );
    }
    return shape;
  }
}
