import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/converters.dart';
import 'package:motor_widgets/src/implicit_tracks.dart';
import 'package:motor_widgets/src/layout/padding_extended.dart';

final _alignment = Track<Alignment>(
  MotionConverter.alignment,
  debugLabel: 'alignment',
);
final _padding = Track<EdgeInsets>(
  MotionConverter.edgeInsets,
  debugLabel: 'padding',
);
final _color = Track<Color>(MotionConverter.colorRgb, debugLabel: 'color');
final _decorationColor = Track<Color>(
  MotionConverter.colorRgb,
  debugLabel: 'decoration.color',
);
final _decorationRadius = Track<BorderRadius>(
  const BorderRadiusMotionConverter(),
  debugLabel: 'decoration.borderRadius',
);
final _foregroundColor = Track<Color>(
  MotionConverter.colorRgb,
  debugLabel: 'foregroundDecoration.color',
);
final _foregroundRadius = Track<BorderRadius>(
  const BorderRadiusMotionConverter(),
  debugLabel: 'foregroundDecoration.borderRadius',
);
final _minWidth = Track<double>(
  const NonNegativeMotionConverter(),
  debugLabel: 'minWidth',
);
final _maxWidth = Track<double>(
  const NonNegativeMotionConverter(),
  debugLabel: 'maxWidth',
);
final _minHeight = Track<double>(
  const NonNegativeMotionConverter(),
  debugLabel: 'minHeight',
);
final _maxHeight = Track<double>(
  const NonNegativeMotionConverter(),
  debugLabel: 'maxHeight',
);
final _margin = Track<EdgeInsets>(
  MotionConverter.edgeInsets,
  debugLabel: 'margin',
);
final _transform = Track<Matrix4>(
  const Matrix4MotionConverter(),
  debugLabel: 'transform',
);
final _transformAlignment = Track<Alignment>(
  MotionConverter.alignment,
  debugLabel: 'transformAlignment',
);

/// Animated version of [Container] that springs each of its properties to
/// its new value whenever it changes.
///
/// The Motor version of [AnimatedContainer]. Every property is its own track
/// on one `TrackBuilder`, so changing one property never disturbs another
/// that is still in flight, and a property that is retargeted mid-flight
/// keeps its velocity.
///
/// What animates:
///
/// * [alignment], [padding], [margin] and [transformAlignment]. Directional
///   values are resolved against the ambient [Directionality] first.
/// * [color].
/// * The `color` and `borderRadius` of a [BoxDecoration] in [decoration] and
///   [foregroundDecoration]. Its other fields (border, shadows, gradient,
///   image, shape) and other kinds of [Decoration] change at once.
/// * [width], [height] and [constraints], as the four bounds of the combined
///   constraints. An unbounded (infinite) bound changes at once.
/// * [transform], decomposed into translation, rotation and scale like
///   `Matrix4Tween`.
///
/// As in [AnimatedContainer], a property that goes from null to a value
/// starts at that value instead of animating. Padding and margin may
/// overshoot below zero while a spring settles; they are laid out with
/// [PaddingExtended], which allows that.
class MotionContainer extends StatelessWidget {
  /// Creates a container that animates its parameters with [motion].
  MotionContainer({
    required this.motion,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.width,
    this.height,
    BoxConstraints? constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.child,
    this.clipBehavior = Clip.none,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  }) : assert(margin == null || margin.isNonNegative, 'margin is negative'),
       assert(
         padding == null || padding.isNonNegative,
         'padding is negative',
       ),
       assert(
         decoration == null || decoration.debugAssertIsValid(),
         'decoration is invalid',
       ),
       assert(
         constraints == null || constraints.debugAssertIsValid(),
         'constraints are invalid',
       ),
       assert(
         decoration != null || clipBehavior == Clip.none,
         'clipBehavior needs a decoration',
       ),
       assert(
         color == null || decoration == null,
         'Cannot provide both a color and a decoration\n'
         'The color argument is just a shorthand for '
         '"decoration: BoxDecoration(color: color)".',
       ),
       constraints = (width != null || height != null)
           ? constraints?.tighten(width: width, height: height) ??
                 BoxConstraints.tightFor(width: width, height: height)
           : constraints;

  /// The [child] contained by the container.
  final Widget? child;

  /// Align the [child] within the container. See [Container.alignment].
  final AlignmentGeometry? alignment;

  /// Empty space to inscribe inside the [decoration]. See
  /// [Container.padding].
  final EdgeInsetsGeometry? padding;

  /// The color to paint behind the [child]. See [Container.color].
  final Color? color;

  /// The decoration to paint behind the [child].
  final Decoration? decoration;

  /// The decoration to paint in front of the [child].
  final Decoration? foregroundDecoration;

  /// The requested width, folded into [constraints].
  final double? width;

  /// The requested height, folded into [constraints].
  final double? height;

  /// Additional constraints to apply to the child, including [width] and
  /// [height].
  final BoxConstraints? constraints;

  /// Empty space to surround the [decoration] and [child].
  final EdgeInsetsGeometry? margin;

  /// The transformation matrix to apply before painting the container.
  final Matrix4? transform;

  /// The alignment of the origin of [transform], relative to the container's
  /// size.
  final AlignmentGeometry? transformAlignment;

  /// The clip behavior when [decoration] is not null. See
  /// [Container.clipBehavior].
  final Clip clipBehavior;

  /// The motion every property follows.
  final Motion motion;

  /// Called every time the animation settles.
  final VoidCallback? onEnd;

  /// How often the animation ticks, for example `tickerRate: .fps(30)`.
  ///
  /// Overrides the nearest [TickerRateScope]. Without either, it ticks every
  /// frame.
  final TickerRate? tickerRate;

  /// A name for the controller, shown by inspection tools such as
  /// `motor_devtools`.
  final String? debugLabel;

  EdgeInsetsGeometry? get _paddingIncludingDecoration {
    final decorationPadding = decoration?.padding;
    if (decorationPadding == null) return padding;
    return padding?.add(decorationPadding) ?? decorationPadding;
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.maybeOf(context);
    final decoration = this.decoration;
    final foregroundDecoration = this.foregroundDecoration;
    final constraints = this.constraints;
    double? finite(double? value) =>
        value != null && value.isFinite ? value : null;

    return ImplicitTrackBuilder(
      motion: motion,
      onEnd: onEnd,
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionContainer',
      tracks: [
        _alignment.implicit(alignment?.resolve(direction)),
        _padding.implicit(
          _paddingIncludingDecoration?.resolve(direction),
        ),
        _color.implicit(color),
        if (decoration is BoxDecoration) ...[
          _decorationColor.implicit(decoration.color),
          _decorationRadius.implicit(
            decoration.borderRadius?.resolve(direction),
          ),
        ],
        if (foregroundDecoration is BoxDecoration) ...[
          _foregroundColor.implicit(foregroundDecoration.color),
          _foregroundRadius.implicit(
            foregroundDecoration.borderRadius?.resolve(direction),
          ),
        ],
        _minWidth.implicit(finite(constraints?.minWidth)),
        _maxWidth.implicit(finite(constraints?.maxWidth)),
        _minHeight.implicit(finite(constraints?.minHeight)),
        _maxHeight.implicit(finite(constraints?.maxHeight)),
        _margin.implicit(margin?.resolve(direction)),
        _transform.implicit(transform),
        _transformAlignment.implicit(
          transformAlignment?.resolve(direction),
        ),
      ],
      builder: (context, value, child) {
        Decoration? animatedDecoration(
          Decoration? decoration,
          Track<Color> color,
          Track<BorderRadius> radius,
        ) => switch (decoration) {
          final BoxDecoration box => BoxDecoration(
            color: value(color),
            image: box.image,
            border: box.border,
            borderRadius: value(radius),
            boxShadow: box.boxShadow,
            gradient: box.gradient,
            backgroundBlendMode: box.backgroundBlendMode,
            shape: box.shape,
          ),
          _ => decoration,
        };

        final currentConstraints = constraints == null
            ? null
            : BoxConstraints(
                minWidth: value(_minWidth) ?? constraints.minWidth,
                maxWidth: value(_maxWidth) ?? constraints.maxWidth,
                minHeight: value(_minHeight) ?? constraints.minHeight,
                maxHeight: value(_maxHeight) ?? constraints.maxHeight,
              ).normalize();

        return _ContainerLayout(
          alignment: value(_alignment),
          padding: value(_padding),
          color: value(_color),
          decoration: animatedDecoration(
            decoration,
            _decorationColor,
            _decorationRadius,
          ),
          foregroundDecoration: animatedDecoration(
            foregroundDecoration,
            _foregroundColor,
            _foregroundRadius,
          ),
          constraints: currentConstraints,
          // Decided on the target, so the tree doesn't change shape while
          // the constraints are moving.
          expandsWhenEmpty: constraints == null || !constraints.isTight,
          margin: value(_margin),
          transform: value(_transform),
          transformAlignment: value(_transformAlignment),
          clipBehavior: clipBehavior,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// The tree [Container] builds, with [PaddingExtended] in place of
/// [Padding] so springs may overshoot below zero padding.
class _ContainerLayout extends StatelessWidget {
  const _ContainerLayout({
    required this.alignment,
    required this.padding,
    required this.color,
    required this.decoration,
    required this.foregroundDecoration,
    required this.constraints,
    required this.expandsWhenEmpty,
    required this.margin,
    required this.transform,
    required this.transformAlignment,
    required this.clipBehavior,
    required this.child,
  });

  final Alignment? alignment;
  final EdgeInsets? padding;
  final Color? color;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final BoxConstraints? constraints;
  final bool expandsWhenEmpty;
  final EdgeInsets? margin;
  final Matrix4? transform;
  final Alignment? transformAlignment;
  final Clip clipBehavior;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    var current = child;

    if (child == null && expandsWhenEmpty) {
      current = LimitedBox(
        maxWidth: 0,
        maxHeight: 0,
        child: ConstrainedBox(constraints: const BoxConstraints.expand()),
      );
    } else if (alignment case final alignment?) {
      current = Align(alignment: alignment, child: current);
    }
    if (padding case final padding?) {
      current = PaddingExtended(padding: padding, child: current);
    }
    if (color case final color?) {
      current = ColoredBox(color: color, child: current);
    }
    if (clipBehavior != Clip.none) {
      current = ClipPath(
        clipper: _DecorationClipper(
          textDirection: Directionality.maybeOf(context),
          decoration: decoration!,
        ),
        clipBehavior: clipBehavior,
        child: current,
      );
    }
    if (decoration case final decoration?) {
      current = DecoratedBox(decoration: decoration, child: current);
    }
    if (foregroundDecoration case final foregroundDecoration?) {
      current = DecoratedBox(
        decoration: foregroundDecoration,
        position: DecorationPosition.foreground,
        child: current,
      );
    }
    if (constraints case final constraints?) {
      current = ConstrainedBox(constraints: constraints, child: current);
    }
    if (margin case final margin?) {
      current = PaddingExtended(padding: margin, child: current);
    }
    if (transform case final transform?) {
      current = Transform(
        transform: transform,
        alignment: transformAlignment,
        child: current,
      );
    }
    return current!;
  }
}

/// Clips to the shape of a [Decoration], as [Container] does.
class _DecorationClipper extends CustomClipper<Path> {
  _DecorationClipper({required this.decoration, TextDirection? textDirection})
    : textDirection = textDirection ?? TextDirection.ltr;

  final TextDirection textDirection;
  final Decoration decoration;

  @override
  Path getClip(Size size) =>
      decoration.getClipPath(Offset.zero & size, textDirection);

  @override
  bool shouldReclip(_DecorationClipper oldClipper) =>
      oldClipper.decoration != decoration ||
      oldClipper.textDirection != textDirection;
}
