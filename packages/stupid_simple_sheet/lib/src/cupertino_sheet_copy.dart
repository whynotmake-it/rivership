/// A place for pasting source from cupertinos `sheets.dart`.
/// We ignore lints here so that we can copy the code without modification.
library;
// ignore_for_file: type=lint

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stupid_simple_sheet/src/clamped_animation.dart';
import 'package:stupid_simple_sheet/src/extend_sheet_at_bottom.dart';

// Smoothing factor applied to the device's top padding (which approximates the corner radius)
// to achieve a smoother end to the corner radius animation.  A value of 1.0 would use
// the full top padding. Values less than 1.0 reduce the effective corner radius, improving
// the animation's appearance.  Determined through empirical testing.
const double _kDeviceCornerRadiusSmoothingFactor = 0.9;

// Threshold in logical pixels. If the calculated device corner radius (after applying
// the smoothing factor) is below this value, the corner radius transition animation will
// start from zero. This prevents abrupt transitions for devices with small or negligible
// corner radii.  This value, combined with the smoothing factor, corresponds roughly
// to double the targeted radius of 12.  Determined through testing and visual inspection.
const double _kRoundedDeviceCornersThreshold = 20.0;

// Amount the sheet in the background scales down. Found by measuring the width
// of the sheet in the background and comparing against the screen width on the
// iOS simulator showing an iPhone 16 pro running iOS 18.0. The scale transition
// will go from a default of 1.0 to 1.0 - _kSheetScaleFactor.
const double _kSheetScaleFactor = 0.0835;

const _kSheetPaddingToPrevious = 11.0;

final Animatable<double> _kScaleTween =
    Tween<double>(begin: 1.0, end: 1.0 - _kSheetScaleFactor);

abstract class CopiedCupertinoSheetTransitions {
  static double _getRelativeTopPadding(
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
        _getRelativeTopPadding(context),
      ),
    );

    final double deviceCornerRadius =
        (MediaQuery.maybeViewPaddingOf(context)?.top ?? 0) *
            _kDeviceCornerRadiusSmoothingFactor;
    final bool roundedDeviceCorners =
        deviceCornerRadius > _kRoundedDeviceCornersThreshold;

    final deviceShape = _getDeviceShape(
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
        .drive(_kScaleTween);

    final Widget? contrastedChild = _getOverlayedChild(
      context,
      child,
      secondaryAnimation.remapped(
        start: opacityRange.$1,
        end: opacityRange.$2,
      ),
      false,
    );

    final double topGapHeight =
        MediaQuery.sizeOf(context).height * _getRelativeTopPadding(context);

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
                return _ClipToShape(
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
    required (double, double) opacityRange,
    required (double, double) slideBackRange,
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
                -_kSheetPaddingToPrevious / MediaQuery.sizeOf(context).height,
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
            .drive(_kScaleTween),
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.medium,
        child: _getOverlayedChild(
          context,
          child,
          secondaryAnimation.remapped(
            start: opacityRange.$1,
            end: opacityRange.$2,
          ),
          true,
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
    ShapeBorder shape = const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(12),
      ),
    ),
    Widget? child,
  }) {
    final offsetTween = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset(0, 0),
    );

    final shapeTween = ShapeBorderTween(
      begin: shape,
      end: shape.scale(1 / 1.5),
    );

    final Animation<Offset> positionAnimation = animation.drive(offsetTween);

    return SafeArea(
      left: false,
      right: false,
      bottom: false,
      minimum: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.05),
      child: Padding(
        padding: const EdgeInsets.only(top: _kSheetPaddingToPrevious),
        child: secondarySlideUpTransition(
          context,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          opacityRange: opacityRange,
          slideBackRange: slideBackRange,
          child: SlideTransition(
            position: positionAnimation,
            child: ValueListenableBuilder(
              valueListenable: secondaryAnimation
                  .remapped(
                    start: slideBackRange.$1,
                    end: slideBackRange.$2,
                  )
                  .drive(shapeTween),
              builder: (context, value, child) {
                final content = ColoredBox(
                  color: CupertinoDynamicColor.resolve(
                    backgroundColor,
                    context,
                  ),
                  child: child,
                );

                return ExtendSheetAtBottom(
                  color: CupertinoDynamicColor.resolve(
                    backgroundColor,
                    context,
                  ),
                  child: _ClipToShape(
                    shape: value,
                    child: content,
                  ),
                );
              },
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  static Widget? _getOverlayedChild(
    BuildContext context,
    Widget? child,
    Animation<double> animation,
    bool secondLayer,
  ) {
    final bool isDarkMode =
        CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final overlayColor = isDarkMode && !secondLayer
        ? const Color(0xFFc8c8c8)
        : const Color(0xFF000000);
    final opacity = animation.drive(Tween(
      begin: 0.0,
      end: secondLayer && isDarkMode ? 0.15 : 0.1,
    ));
    return Stack(
      children: <Widget>[
        if (child != null) child,
        IgnorePointer(
          child: FadeTransition(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(color: overlayColor),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }

  static ShapeBorder _getDeviceShape({
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
}

class _ClipToShape extends StatelessWidget {
  const _ClipToShape({required this.shape, required this.child});

  final ShapeBorder? shape;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = this.shape;
    return switch (shape) {
      null => child,
      RoundedRectangleBorder(:final borderRadius) => ClipRRect(
          borderRadius: borderRadius,
          child: child,
        ),
      RoundedSuperellipseBorder(:final borderRadius) => ClipRRect(
          borderRadius: borderRadius,
          child: child,
        ),
      _ => ClipPath(
          clipper: ShapeBorderClipper(
            shape: shape,
          ),
          child: child,
        )
    };
  }
}
