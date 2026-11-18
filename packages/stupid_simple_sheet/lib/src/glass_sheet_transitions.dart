/// Sheet transitions for the iOS 26 liquid glass style.
///
/// Reuses shared constants and helpers from [cupertino_sheet_copy.dart].
/// Only the methods that differ from [CopiedCupertinoSheetTransitions] are
/// defined here.
library;
// ignore_for_file: type=lint

import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/src/clamped_animation.dart';
import 'package:stupid_simple_sheet/src/cupertino_sheet_copy.dart';
import 'package:stupid_simple_sheet/src/presentation_sizing.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

const double _floatingSheetMargin = 8;
const double _sheetAttachmentStart = 0.85;
const double _glassMaterialBlur = 24;
const double _glassMaterialOpacity = 0.56;

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
    required bool materialBlur,
    bool floatingMargins = false,
    bool floatingMaterial = false,
    bool hugContent = false,
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
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final attachment = Interval(
              _sheetAttachmentStart,
              1,
            ).transform(animation.value.clamp(0.0, 1.0).toDouble());
            final floating = floatingMargins
                ? 1 - attachment
                : floatingMaterial
                    ? 1.0
                    : 0.0;
            final resolvedColor = CupertinoDynamicColor.resolve(
              backgroundColor,
              context,
            );
            return SheetBackground(
              shape: floatingSheetShape(shape, floating),
              backgroundColor: resolvedColor.withValues(
                alpha: resolvedColor.a *
                    lerpDouble(1, _glassMaterialOpacity, floating)!,
              ),
              backdropBlur: materialBlur
                  ? lerpDouble(0, _glassMaterialBlur, floating)!
                  : 0,
              extensionAtBottom: floatingMargins
                  ? attachment * MediaQuery.sizeOf(context).height
                  : extensionAtBottom,
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
            );
          },
          child: child,
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
    required bool materialBlur,
    DismissalMode dismissalMode = DismissalMode.slide,
    ShapeBorder shape = const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(36),
      ),
    ),
    PresentationSizing presentationSizing = PresentationSizing.automatic,
    Widget? child,
  }) {
    final formSheet =
        presentationSizing.resolvesToFormSheet(MediaQuery.sizeOf(context));
    final effectiveShape = formSheet
        ? CopiedCupertinoSheetTransitions.allCornersSheetShape(shape)
        : shape;

    final secondaryChild = secondarySlideUpTransition(
      context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      shape: effectiveShape,
      opacityRange: opacityRange,
      slideBackRange: slideBackRange,
      backgroundColor: backgroundColor,
      secondSheet: secondSheet,
      materialBlur: materialBlur,
      floatingMargins: !formSheet,
      floatingMaterial: formSheet,
      hugContent: presentationSizing.sizesToContent(
        MediaQuery.sizeOf(context),
      ),
      extensionAtBottom: formSheet ? 0 : null,
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
            MediaQuery.sizeOf(context),
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
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final attachment = Interval(
                _sheetAttachmentStart,
                1,
              ).transform(animation.value.clamp(0.0, 1.0).toDouble());
              final margin = _floatingSheetMargin * (1 - attachment);
              return Padding(
                padding: EdgeInsets.all(margin),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: secondSheet ? kSheetPaddingToPrevious : 0,
                  ),
                  child: child,
                ),
              );
            },
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

  /// Interpolates between the floating all-corner sheet and its edge-attached
  /// shape as the sheet reaches its largest detent.
  static ShapeBorder floatingSheetShape(
    ShapeBorder shape,
    double floating,
  ) {
    switch (shape) {
      case RoundedSuperellipseBorder(:final borderRadius, :final side):
        final resolved = borderRadius.resolve(TextDirection.ltr);
        return RoundedSuperellipseBorder(
          side: side,
          borderRadius: BorderRadius.only(
            topLeft: resolved.topLeft,
            topRight: resolved.topRight,
            bottomLeft: Radius.lerp(
              resolved.bottomLeft,
              resolved.topLeft,
              floating,
            )!,
            bottomRight: Radius.lerp(
              resolved.bottomRight,
              resolved.topRight,
              floating,
            )!,
          ),
        );
      case RoundedRectangleBorder(:final borderRadius, :final side):
        final resolved = borderRadius.resolve(TextDirection.ltr);
        return RoundedRectangleBorder(
          side: side,
          borderRadius: BorderRadius.only(
            topLeft: resolved.topLeft,
            topRight: resolved.topRight,
            bottomLeft: Radius.lerp(
              resolved.bottomLeft,
              resolved.topLeft,
              floating,
            )!,
            bottomRight: Radius.lerp(
              resolved.bottomRight,
              resolved.topRight,
              floating,
            )!,
          ),
        );
      default:
        return shape;
    }
  }
}
