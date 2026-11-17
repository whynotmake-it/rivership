/// A place for pasting source from cupertinos `sheets.dart`.
/// We ignore lints here so that we can copy the code without modification.
library;
// ignore_for_file: type=lint

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stupid_simple_sheet/src/clamped_animation.dart';
import 'package:stupid_simple_sheet/src/optimized_clip.dart';
import 'package:stupid_simple_sheet/src/presentation_sizing.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

// Smoothing factor applied to the device's top padding (which approximates the corner radius)
// to achieve a smoother end to the corner radius animation.  A value of 1.0 would use
// the full top padding. Values less than 1.0 reduce the effective corner radius, improving
// the animation's appearance.  Determined through empirical testing.
const double kDeviceCornerRadiusSmoothingFactor = 0.9;

// Threshold in logical pixels. If the calculated device corner radius (after applying
// the smoothing factor) is below this value, the corner radius transition animation will
// start from zero. This prevents abrupt transitions for devices with small or negligible
// corner radii.  This value, combined with the smoothing factor, corresponds roughly
// to double the targeted radius of 12.  Determined through testing and visual inspection.
const double kRoundedDeviceCornersThreshold = 20.0;

// Amount the sheet in the background scales down. Found by measuring the width
// of the sheet in the background and comparing against the screen width on the
// iOS simulator showing an iPhone 16 pro running iOS 18.0. The scale transition
// will go from a default of 1.0 to 1.0 - _kSheetScaleFactor.
const double kSheetScaleFactor = 0.0835;

const kSheetPaddingToPrevious = 11.0;

final Animatable<double> kScaleTween =
    Tween<double>(begin: 1.0, end: 1.0 - kSheetScaleFactor);

double getRelativeTopPadding(
  BuildContext context, {
  double extraPadding = 0,
  double minFraction = 0.05,
}) {
  final safeArea = MediaQuery.paddingOf(context);
  final height = MediaQuery.sizeOf(context).height;

  if (height == 0) {
    return minFraction;
  }
  // Ensure that the sheet moves down by at least 5% of the screen height if
  // the safe area is very small (e.g. no notch).
  return max((safeArea.top + extraPadding) / height, minFraction);
}

Widget getOverlayedChild(
  BuildContext context,
  Widget? child,
  Animation<double> animation,
  bool secondLayer, {
  bool expandOverlay = true,
}) {
  final bool isDarkMode =
      CupertinoTheme.brightnessOf(context) == Brightness.dark;
  final overlayColor = isDarkMode && !secondLayer
      ? const Color(0xFFc8c8c8)
      : const Color(0xFF000000);
  final opacity = animation.drive(Tween(
    begin: 0.0,
    end: secondLayer && isDarkMode ? 0.15 : 0.1,
  ));
  final overlay = IgnorePointer(
    child: FadeTransition(
      opacity: opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(color: overlayColor),
        // When expanding, the overlay is a non-positioned child that forces the
        // stack to fill the largest allowed size (the default sheet behavior).
        child: expandOverlay ? const SizedBox.expand() : null,
      ),
    ),
  );
  return Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      if (child != null) child,
      // When not expanding, position the overlay so it matches the child's size
      // instead of dictating it — letting a content-sized sheet hug content.
      if (expandOverlay) overlay else Positioned.fill(child: overlay),
    ],
  );
}

ShapeBorder getDeviceShape({
  required ShapeBorder sheetShape,
  required double deviceCornerRadius,
}) {
  switch (sheetShape) {
    case RoundedSuperellipseBorder():
      return RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(deviceCornerRadius),
        ),
      );
    default:
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(deviceCornerRadius),
        ),
      );
  }
}

abstract class CopiedCupertinoSheetTransitions {
  /// The primary delegated transition. Will slide a non [CupertinoSheetRoute] page down.
  ///
  /// Provided to the previous route to coordinate transitions between routes.
  static Widget? secondarySlideDownTransition(
    BuildContext context, {
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required (double, double) opacityRange,
    required (double, double) slideBackRange,
    required ShapeBorder primaryShape,
    Widget? child,
  }) {
    final Animatable<Offset> topDownTween = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(
        0,
        getRelativeTopPadding(context),
      ),
    );

    final double deviceCornerRadius =
        (MediaQuery.maybeViewPaddingOf(context)?.top ?? 0) *
            kDeviceCornerRadiusSmoothingFactor;
    final bool roundedDeviceCorners =
        deviceCornerRadius > kRoundedDeviceCornersThreshold;

    final deviceShape = getDeviceShape(
      sheetShape: primaryShape,
      deviceCornerRadius: roundedDeviceCorners ? deviceCornerRadius : 0,
    );

    final decorationTween = ShapeBorderTween(
      begin: deviceShape,
      end: primaryShape.scale(1 / 1.5),
    );

    final shapeAnimation = secondaryAnimation
        .remapped(
          start: slideBackRange.$1,
          end: slideBackRange.$2,
        )
        .drive(decorationTween);

    final Animation<Offset> slideAnimation = secondaryAnimation
        .remapped(
          start: slideBackRange.$1,
          end: slideBackRange.$2,
        )
        .drive(topDownTween);
    final Animation<double> scaleAnimation = secondaryAnimation
        .remapped(
          start: slideBackRange.$1,
          end: slideBackRange.$2,
        )
        .drive(kScaleTween);

    final Widget? contrastedChild = getOverlayedChild(
      context,
      child,
      secondaryAnimation.remapped(
        start: opacityRange.$1,
        end: opacityRange.$2,
      ),
      false,
    );

    final double topGapHeight =
        MediaQuery.sizeOf(context).height * getRelativeTopPadding(context);

    return Stack(
      children: <Widget>[
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
          child: SizedBox(height: topGapHeight, width: double.infinity),
        ),
        SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            filterQuality: FilterQuality.medium,
            alignment: Alignment.topCenter,
            child: AnimatedBuilder(
              animation: shapeAnimation,
              child: contrastedChild,
              builder: (BuildContext context, Widget? child) {
                return OptimizedClip(
                  shape: shapeAnimation.value,
                  child: child!,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static Widget secondarySlideUpTransition(
    BuildContext context, {
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Animation<ShapeBorder?> shapeAnimation,
    required (double, double) opacityRange,
    required (double, double) slideBackRange,
    required Color backgroundColor,
    double? extensionAtBottom,
    bool hugContent = false,
    Widget? child,
  }) {
    return SlideTransition(
      position: secondaryAnimation
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
          ),
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
        child: AnimatedBuilder(
          animation: shapeAnimation,
          builder: (context, child) => SheetBackground(
            shape: shapeAnimation.value!,
            backgroundColor: CupertinoDynamicColor.resolve(
              backgroundColor,
              context,
            ),
            extensionAtBottom: extensionAtBottom,
            child: child!,
          ),
          child: getOverlayedChild(
            context,
            child,
            secondaryAnimation.remapped(
              start: opacityRange.$1,
              end: opacityRange.$2,
            ),
            true,
            expandOverlay: !hugContent,
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
    DismissalMode dismissalMode = DismissalMode.slide,
    ShapeBorder shape = const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(12),
      ),
    ),
    PresentationSizing presentationSizing = PresentationSizing.automatic,
    bool secondSheet = false,
    Widget? child,
  }) {
    final formSheet =
        presentationSizing.resolvesToFormSheet(MediaQuery.sizeOf(context));
    final effectiveShape = formSheet ? allCornersSheetShape(shape) : shape;
    final shapeTween = ShapeBorderTween(
      begin: effectiveShape,
      end: effectiveShape.scale(1 / 1.5),
    );

    final shapeAnimation = secondaryAnimation
        .remapped(
          start: slideBackRange.$1,
          end: slideBackRange.$2,
        )
        .drive(shapeTween);

    final secondaryChild = secondarySlideUpTransition(
      context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      shapeAnimation: shapeAnimation,
      opacityRange: opacityRange,
      slideBackRange: slideBackRange,
      backgroundColor: backgroundColor,
      extensionAtBottom: formSheet ? 0 : null,
      hugContent: presentationSizing.sizesToContent(
        MediaQuery.sizeOf(context),
      ),
      child: child,
    );

    if (formSheet) {
      return Builder(
        builder: (context) {
          final availableSize = presentationSizing.formSheetAvailableSize(
            context,
            additionalTopMargin: secondSheet ? kFormSheetPaddingToPrevious : 0,
          );
          final constraints = presentationSizing.constraintsFor(
            availableSize,
            formSheet: true,
          );
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: kFormSheetMinHorizontalMargin,
              vertical: kFormSheetMinVerticalMargin,
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(
                  0,
                  secondSheet ? kFormSheetPaddingToPrevious : 0,
                ),
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final maxHeight =
                        constraints.maxHeight * animation.value.clamp(0.0, 1.0);
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.minWidth,
                        maxWidth: constraints.maxWidth,
                        minHeight: min(constraints.minHeight, maxHeight),
                        maxHeight: maxHeight,
                      ),
                      child: child,
                    );
                  },
                  child: secondaryChild,
                ),
              ),
            ),
          );
        },
      );
    }

    final regularPage = presentationSizing.isRegularPresentation(
      MediaQuery.sizeOf(context),
    );
    final constraints = regularPage
        ? presentationSizing.constraintsFor(
            Size(
              MediaQuery.sizeOf(context).width,
              MediaQuery.sizeOf(context).height,
            ),
            formSheet: false,
          )
        : BoxConstraints.tight(MediaQuery.sizeOf(context));

    return Builder(
      builder: (context) {
        return SafeArea(
          left: false,
          right: false,
          bottom: false,
          minimum:
              EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.05),
          child: Padding(
            padding: const EdgeInsets.only(top: kSheetPaddingToPrevious),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SheetDismissalTransition(
                animation: animation,
                dismissalMode: dismissalMode,
                child: ConstrainedBox(
                  constraints: constraints,
                  child: secondaryChild,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Returns a version of [shape] with all corners rounded, suitable for
  /// presentations that are not edge-attached. Shape borders are preserved.
  static ShapeBorder allCornersSheetShape(ShapeBorder shape) {
    switch (shape) {
      case RoundedSuperellipseBorder(
          :final borderRadius,
          :final side,
        ):
        final resolved = borderRadius.resolve(TextDirection.ltr);
        return RoundedSuperellipseBorder(
          side: side,
          borderRadius: BorderRadius.only(
            topLeft: resolved.topLeft,
            topRight: resolved.topRight,
            bottomLeft: resolved.topLeft,
            bottomRight: resolved.topRight,
          ),
        );
      case RoundedRectangleBorder(:final borderRadius, :final side):
        final resolved = borderRadius.resolve(TextDirection.ltr);
        return RoundedRectangleBorder(
          side: side,
          borderRadius: BorderRadius.only(
            topLeft: resolved.topLeft,
            topRight: resolved.topRight,
            bottomLeft: resolved.topLeft,
            bottomRight: resolved.topRight,
          ),
        );
      default:
        return shape;
    }
  }
}
