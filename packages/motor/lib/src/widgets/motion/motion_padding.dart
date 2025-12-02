import 'package:flutter/material.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/widgets/layout/padding_extended.dart';
import 'package:motor/src/widgets/motion_builder.dart';

export 'package:motor/src/widgets/layout/padding_extended.dart'
    show PaddingExtended;

/// A widget similar to [AnimatedPadding], but each side's padding can be
/// simulated independently using [Motion].
///
/// Uses [PaddingExtended] to allow for negative padding values.
class MotionPadding extends StatelessWidget {
  /// Creates a [MotionPadding] widget.
  const MotionPadding({
    required this.motion,
    required this.padding,
    required this.child,
    super.key,
  });

  /// The motion that controls the padding animation.
  final Motion motion;

  /// The padding to animate.
  final EdgeInsetsGeometry padding;

  /// The child widget to apply the padding to.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MotionBuilder<EdgeInsetsGeometry>(
      value: padding,
      motion: motion,
      converter: switch (padding) {
        EdgeInsets() => const EdgeInsetsMotionConverter(),
        EdgeInsetsDirectional() => const EdgeInsetsDirectionalMotionConverter(),
        _ => throw UnsupportedError(
            'Unsupported EdgeInsetsGeometry type: ${padding.runtimeType}',
          ),
      },
      builder: (context, value, child) {
        return PaddingExtended(
          padding: value,
          child: child,
        );
      },
      child: child,
    );
  }
}
