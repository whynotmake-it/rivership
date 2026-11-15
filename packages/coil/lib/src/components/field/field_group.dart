import 'package:coil/foundation.dart';
import 'package:coil/src/components/field/field_style.dart';
import 'package:flutter/widgets.dart';

/// Stacks fields with the theme's field spacing.
class CoilFieldGroup extends StatelessWidget {
  /// Creates a field group.
  const CoilFieldGroup({
    required this.children,
    super.key,
    this.size,
    this.style,
  });

  /// The fields, and any separators between them.
  final List<Widget> children;

  /// Pins the spacing to one size step.
  final CoilSize? size;

  /// Overrides for the look.
  final CoilFieldStyle? style;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: CoilFieldStyle.resolve(
      context,
      size: size,
      style: style,
    ).fieldGap!,
    children: children,
  );
}
