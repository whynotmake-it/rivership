import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Maps a presence value to a widget: how a child looks while it enters or
/// leaves.
///
/// Presence is 0 when the child is gone and 1 when it is fully present. It
/// comes from a spring, so it may overshoot past 1 on the way in, or below 0
/// on the way out; transitions extrapolate instead of clamping where that
/// makes sense (a scale grows past 1) and clamp where it doesn't (opacity).
///
/// Transitions are immutable values that compare by value, so they can be
/// created in `build` and passed down without causing extra work. Combine
/// them with `+`:
///
/// ```dart
/// MotionSwitcher(
///   motion: const .smoothSpring(),
///   transition: .fade + .scale(0.9),
///   child: Text('$count', key: ValueKey(count)),
/// )
/// ```
///
/// To write your own, extend [MotionTransition], implement [build], and
/// override `==` and `hashCode` if it has fields. A transition should build
/// the same widget structure for every presence, so the child keeps its
/// state while the value moves; disable an effect (for example with
/// `ImageFiltered.enabled`) rather than leaving its widget out.
@immutable
abstract class MotionTransition {
  /// Allows subclasses to be const.
  const MotionTransition();

  /// Scales the child from [from] at presence 0 to 1 at presence 1, around
  /// [alignment].
  const factory MotionTransition.scale(
    double from, {
    AlignmentGeometry alignment,
  }) = _ScaleTransition;

  /// Slides the child from [offset] at presence 0 to where it is at presence
  /// 1. Like `SlideTransition`, [offset] is a fraction of the child's size.
  const factory MotionTransition.slide(Offset offset) = _SlideTransition;

  /// Moves the child from [offset] logical pixels away at presence 0 to where
  /// it is at presence 1.
  const factory MotionTransition.translate(Offset offset) =
      _TranslateTransition;

  /// Blurs the child with a Gaussian blur of [sigma] at presence 0, sharp at
  /// presence 1. The blur is turned off whenever it is zero.
  const factory MotionTransition.blur(double sigma) = _BlurTransition;

  /// Blurs, fades and scales the child in, optionally moving it from
  /// [offset] logical pixels away.
  ///
  /// At presence 0 the child is invisible, blurred by [blur] (a Gaussian
  /// sigma), scaled to [scale] and moved by [offset]; at presence 1 it is
  /// as it is. The blur is turned off whenever it is zero.
  const factory MotionTransition.blurFade({
    double blur,
    double scale,
    Offset offset,
  }) = _BlurFadeTransition;

  /// Shows the child as it is, at any presence.
  static const MotionTransition none = _NoTransition();

  /// Fades the child in and out: opacity follows presence, clamped to
  /// `[0, 1]`.
  static const MotionTransition fade = _FadeTransition();

  /// Wraps [child] as it should look at [presence].
  Widget build(BuildContext context, double presence, Widget child);

  /// The transitions this one applies, outermost first.
  @protected
  List<MotionTransition> get parts => [this];

  /// Applies this transition around [other]: `a + b` wraps the child in `b`,
  /// then in `a`.
  MotionTransition operator +(MotionTransition other) {
    final parts = [...this.parts, ...other.parts];
    return switch (parts) {
      [] => none,
      [final single] => single,
      _ => _ComposedTransition(parts),
    };
  }
}

class _NoTransition extends MotionTransition {
  const _NoTransition();

  @override
  Widget build(BuildContext context, double presence, Widget child) => child;

  @override
  List<MotionTransition> get parts => const [];

  @override
  bool operator ==(Object other) => other is _NoTransition;

  @override
  int get hashCode => (_NoTransition).hashCode;

  @override
  String toString() => 'MotionTransition.none';
}

class _FadeTransition extends MotionTransition {
  const _FadeTransition();

  @override
  Widget build(BuildContext context, double presence, Widget child) =>
      Opacity(opacity: presence.clamp(0, 1), child: child);

  @override
  bool operator ==(Object other) => other is _FadeTransition;

  @override
  int get hashCode => (_FadeTransition).hashCode;

  @override
  String toString() => 'MotionTransition.fade';
}

class _ScaleTransition extends MotionTransition {
  const _ScaleTransition(this.from, {this.alignment = Alignment.center});

  final double from;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context, double presence, Widget child) =>
      Transform.scale(
        scale: _lerp(from, 1, presence),
        alignment: alignment.resolve(Directionality.maybeOf(context)),
        child: child,
      );

  @override
  bool operator ==(Object other) =>
      other is _ScaleTransition &&
      other.from == from &&
      other.alignment == alignment;

  @override
  int get hashCode => Object.hash(_ScaleTransition, from, alignment);

  @override
  String toString() => 'MotionTransition.scale($from, alignment: $alignment)';
}

class _SlideTransition extends MotionTransition {
  const _SlideTransition(this.offset);

  final Offset offset;

  @override
  Widget build(BuildContext context, double presence, Widget child) =>
      FractionalTranslation(
        translation: offset * (1 - presence),
        child: child,
      );

  @override
  bool operator ==(Object other) =>
      other is _SlideTransition && other.offset == offset;

  @override
  int get hashCode => Object.hash(_SlideTransition, offset);

  @override
  String toString() => 'MotionTransition.slide($offset)';
}

class _TranslateTransition extends MotionTransition {
  const _TranslateTransition(this.offset);

  final Offset offset;

  @override
  Widget build(BuildContext context, double presence, Widget child) =>
      Transform.translate(offset: offset * (1 - presence), child: child);

  @override
  bool operator ==(Object other) =>
      other is _TranslateTransition && other.offset == offset;

  @override
  int get hashCode => Object.hash(_TranslateTransition, offset);

  @override
  String toString() => 'MotionTransition.translate($offset)';
}

class _BlurTransition extends MotionTransition {
  const _BlurTransition(this.sigma) : assert(sigma >= 0, 'sigma is negative');

  final double sigma;

  @override
  Widget build(BuildContext context, double presence, Widget child) =>
      _blurred(sigma * (1 - presence), child);

  @override
  bool operator ==(Object other) =>
      other is _BlurTransition && other.sigma == sigma;

  @override
  int get hashCode => Object.hash(_BlurTransition, sigma);

  @override
  String toString() => 'MotionTransition.blur($sigma)';
}

class _BlurFadeTransition extends MotionTransition {
  const _BlurFadeTransition({
    this.blur = 4,
    this.scale = 0.96,
    this.offset = Offset.zero,
  }) : assert(blur >= 0, 'blur is negative');

  final double blur;
  final double scale;
  final Offset offset;

  @override
  Widget build(BuildContext context, double presence, Widget child) {
    return Opacity(
      opacity: presence.clamp(0, 1),
      child: _blurred(
        blur * (1 - presence),
        Transform.translate(
          offset: offset * (1 - presence),
          child: Transform.scale(
            scale: _lerp(scale, 1, presence),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _BlurFadeTransition &&
      other.blur == blur &&
      other.scale == scale &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(_BlurFadeTransition, blur, scale, offset);

  @override
  String toString() =>
      'MotionTransition.blurFade(blur: $blur, scale: $scale, offset: $offset)';
}

class _ComposedTransition extends MotionTransition {
  const _ComposedTransition(this.parts);

  @override
  final List<MotionTransition> parts;

  @override
  Widget build(BuildContext context, double presence, Widget child) {
    var current = child;
    for (final part in parts.reversed) {
      current = part.build(context, presence, current);
    }
    return current;
  }

  @override
  bool operator ==(Object other) =>
      other is _ComposedTransition && listEquals(other.parts, parts);

  @override
  int get hashCode => Object.hashAll(parts);

  @override
  String toString() => parts.join(' + ');
}

double _lerp(double from, double to, double t) => from + (to - from) * t;

/// Blurs [child] by [sigma], keeping the [ImageFiltered] in the tree but
/// turned off when there is nothing to blur, so the child keeps its state.
Widget _blurred(double sigma, Widget child) {
  final effective = sigma > 0 ? sigma : 0.0;
  return ImageFiltered(
    enabled: effective > 0,
    imageFilter: ImageFilter.blur(
      sigmaX: effective,
      sigmaY: effective,
      tileMode: TileMode.decal,
    ),
    child: child,
  );
}
