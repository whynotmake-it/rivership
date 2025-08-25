/// A place for pasting source from cupertinos `sheets.dart`.
/// We ignore lints here so that we can copy the code without modification.
library;
// ignore_for_file: type=lint

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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

final Animatable<double> _kOpacityTween = Tween<double>(begin: 0.0, end: 0.10);

// Offset from top of screen to slightly down when a fullscreen page is covered
// by a sheet. Values found from eyeballing a simulator running iOS 18.0.
final Animatable<Offset> _kTopDownTween = Tween<Offset>(
  begin: Offset.zero,
  end: const Offset(0.0, 0.07),
);
// Amount the sheet in the background scales down. Found by measuring the width
// of the sheet in the background and comparing against the screen width on the
// iOS simulator showing an iPhone 16 pro running iOS 18.0. The scale transition
// will go from a default of 1.0 to 1.0 - _kSheetScaleFactor.
const double _kSheetScaleFactor = 0.0835;

final Animatable<double> _kScaleTween =
    Tween<double>(begin: 1.0, end: 1.0 - _kSheetScaleFactor);

class CopiedCupertinoSheetTransition {
  /// The primary delegated transition. Will slide a non [CupertinoSheetRoute] page down.
  ///
  /// Provided to the previous route to coordinate transitions between routes.
  ///
  /// If a [CupertinoSheetRoute] already exists in the stack, then it will
  /// slide the previous sheet upwards instead.
  static Widget delegateTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    final double deviceCornerRadius =
        (MediaQuery.maybeViewPaddingOf(context)?.top ?? 0) *
            _kDeviceCornerRadiusSmoothingFactor;
    final bool roundedDeviceCorners =
        deviceCornerRadius > _kRoundedDeviceCornersThreshold;

    final Animatable<BorderRadiusGeometry> decorationTween =
        Tween<BorderRadiusGeometry>(
      begin: BorderRadius.vertical(
        top: Radius.circular(roundedDeviceCorners ? deviceCornerRadius : 0),
      ),
      end: BorderRadius.circular(12),
    );

    final Animation<BorderRadiusGeometry> radiusAnimation =
        secondaryAnimation.drive(decorationTween);
    final Animation<double> opacityAnimation =
        secondaryAnimation.drive(_kOpacityTween);
    final Animation<Offset> slideAnimation =
        secondaryAnimation.drive(_kTopDownTween);
    final Animation<double> scaleAnimation =
        secondaryAnimation.drive(_kScaleTween);

    final bool isDarkMode =
        CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final Color overlayColor =
        isDarkMode ? const Color(0xFFc8c8c8) : const Color(0xFF000000);

    final Widget? contrastedChild =
        child != null && !secondaryAnimation.isDismissed
            ? Stack(
                children: <Widget>[
                  child,
                  FadeTransition(
                    opacity: opacityAnimation,
                    child: ColoredBox(
                        color: overlayColor, child: const SizedBox.expand()),
                  ),
                ],
              )
            : child;

    final double topGapHeight = MediaQuery.sizeOf(context).height * 0.08;

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
              animation: radiusAnimation,
              child: child,
              builder: (BuildContext context, Widget? child) {
                return ClipRSuperellipse(
                  borderRadius: !secondaryAnimation.isDismissed
                      ? radiusAnimation.value
                      : BorderRadius.circular(0),
                  child: contrastedChild,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
