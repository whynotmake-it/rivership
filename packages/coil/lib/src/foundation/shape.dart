/// @docImport 'package:coil/src/foundation/theme.dart';
library;

import 'dart:math' as math;

import 'package:coil/src/foundation/metrics.dart';
import 'package:flutter/foundation.dart';

/// The three corner radii a shape family has at one tier.
@immutable
class CoilRadii {
  /// Creates radii.
  const CoilRadii({
    required this.item,
    required this.container,
    required this.focusRing,
  });

  /// Controls, list rows, and the fills that sit on them.
  final double item;

  /// Containers holding items: popovers, sheets, cards, and groups.
  ///
  /// Concentric with [item] at the popup inset.
  final double container;

  /// A focus ring drawn 2 px outside an item.
  final double focusRing;

  /// The radius of a container whose edge runs [inset] outside a shape of
  /// [inner] radius, so the two corners share a center: inner + inset.
  ///
  /// A superellipse draws a radius past half its shorter side as half of
  /// it (a pill), so pass that side as [innerExtent] whenever [inner] can
  /// be a pill's: a 28 px button at the `pill` item radius 20 has 14 px
  /// corners, and a container 8 px out from it needs 22, not 28.
  ///
  /// A family whose containers are no rounder than its items (`sharp`)
  /// nests square: it gets [container] back, so a near-square button
  /// never sits in a rounded frame.
  ///
  /// ```dart
  /// // A composer around its send button, `gap` in from the corner.
  /// final radius = CoilTheme.radiiOf(context).concentric(
  ///   buttonRadius,
  ///   metrics.gap,
  ///   innerExtent: buttonHeight,
  /// );
  /// ```
  double concentric(
    double inner,
    double inset, {
    double innerExtent = double.infinity,
  }) => container <= item
      ? container
      : math.max(0, math.min(inner, innerExtent / 2)) + inset;

  @override
  bool operator ==(Object other) =>
      other is CoilRadii &&
      other.item == item &&
      other.container == container &&
      other.focusRing == focusRing;

  @override
  int get hashCode => Object.hash(item, container, focusRing);
}

/// The corner shape family: radii per tier.
///
/// Touch controls are taller, so their corners grow to keep the same
/// proportions. Use one of [rounded] (the default), [pill], or [sharp], or
/// define your own with two [CoilRadii].
@immutable
class CoilShape {
  /// Creates a shape family with radii for each tier.
  const CoilShape({required this.pointer, required this.touch});

  /// Fully rounded controls.
  static const pill = CoilShape(
    pointer: CoilRadii(item: 20, container: 24, focusRing: 22),
    touch: CoilRadii(item: 22, container: 28, focusRing: 24),
  );

  /// The default: 8 px controls inside 12 px containers on the pointer
  /// tier, 10 inside 16 on touch.
  static const rounded = CoilShape(
    pointer: CoilRadii(item: 8, container: 12, focusRing: 10),
    touch: CoilRadii(item: 10, container: 16, focusRing: 12),
  );

  /// Near-square corners.
  static const sharp = CoilShape(
    pointer: CoilRadii(item: 1, container: 1, focusRing: 3),
    touch: CoilRadii(item: 1, container: 1, focusRing: 3),
  );

  /// The radii on the pointer tier.
  final CoilRadii pointer;

  /// The radii on the touch tier.
  final CoilRadii touch;

  /// The radii for [tier].
  ///
  /// [CoilTheme.radiiOf] resolves the tier for you.
  CoilRadii radii(CoilTier tier) => switch (tier) {
    CoilTier.pointer => pointer,
    CoilTier.touch => touch,
  };

  /// The radius of a surface inset by [inset] inside one of [outer] radius.
  ///
  /// This is the inverse of [CoilRadii.concentric].
  static double nested(double outer, double inset, [double borderWidth = 0]) =>
      (outer - inset - borderWidth).clamp(0, double.infinity);

  @override
  bool operator ==(Object other) =>
      other is CoilShape && other.pointer == pointer && other.touch == touch;

  @override
  int get hashCode => Object.hash(pointer, touch);
}
