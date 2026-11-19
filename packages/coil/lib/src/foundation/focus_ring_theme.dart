import 'dart:ui' show lerpDouble;

import 'package:coil/src/foundation/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Marks a copyWith argument that wasn't passed.
const Object _keep = Object();

/// How focus rings look (`CoilThemeData.focusRing`): the ring that keyboard
/// focus draws around a control, concentric with the control's shape.
///
/// By default the ring is 1 px wide and sits 2 px outside the control, so
/// its inner edge has the control's radius + 2. Every control draws it the
/// same way: a single control with `CoilFocusRing`, a list or group whose
/// one ring travels between rows with [decorationAround] on a highlight
/// grown by [extent].
///
/// The ring's corner comes from the theme's shape, like every other corner.
/// In high contrast, the theme draws it 2 px wide, in a color with at least
/// 3:1 contrast against the background.
@immutable
class CoilFocusRingTheme with Diagnosticable {
  /// Creates a focus ring theme.
  const CoilFocusRingTheme({
    this.width = 1,
    this.offset = defaultOffset,
    this.color,
  });

  /// The gap between a control's edge and its ring, unless a theme sets
  /// another [offset].
  static const defaultOffset = 2.0;

  /// The ring's thickness.
  final double width;

  /// The gap between the control's edge and the ring.
  final double offset;

  /// How far the ring's outer edge reaches outside the control: [offset]
  /// plus [width]. Room a parent keeps clear for the ring.
  double get extent => offset + width;

  /// The ring around a control whose corners have [radius], as a
  /// decoration for the control's box grown by [extent] on every side (a
  /// `CoilHighlight` with `inflate: extent`): a [width] line along that
  /// box's edge, [offset] clear of the control and concentric with it.
  ShapeDecoration decorationAround(
    CoilColors colors, {
    required double radius,
  }) => ShapeDecoration(
    shape: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius + extent),
      side: BorderSide(color: colorOf(colors), width: width),
    ),
  );

  /// The ring's color, or null for the theme's brand color.
  final Color? color;

  /// The ring's color in [colors]: [color], or the brand color.
  Color colorOf(CoilColors colors) => color ?? colors.brand;

  /// Returns a copy with the given fields replaced. Pass `color: null` to go
  /// back to the brand color.
  CoilFocusRingTheme copyWith({
    double? width,
    double? offset,
    Object? color = _keep,
  }) => CoilFocusRingTheme(
    width: width ?? this.width,
    offset: offset ?? this.offset,
    color: identical(color, _keep) ? this.color : color as Color?,
  );

  /// Interpolates two focus ring themes, for animated theme changes.
  // A static lerp, like Color.lerp.
  // ignore: prefer_constructors_over_static_methods
  static CoilFocusRingTheme lerp(
    CoilFocusRingTheme a,
    CoilFocusRingTheme b,
    double t,
  ) {
    if (identical(a, b)) return a;
    return CoilFocusRingTheme(
      width: lerpDouble(a.width, b.width, t)!,
      offset: lerpDouble(a.offset, b.offset, t)!,
      color: Color.lerp(a.color, b.color, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoilFocusRingTheme &&
      other.width == width &&
      other.offset == offset &&
      other.color == color;

  @override
  int get hashCode => Object.hash(width, offset, color);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('width', width, defaultValue: 1))
      ..add(DoubleProperty('offset', offset, defaultValue: defaultOffset))
      ..add(ColorProperty('color', color, defaultValue: null));
  }
}
