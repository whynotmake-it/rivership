import 'package:coil/foundation.dart';
import 'package:coil/src/components/field/field_style.dart';
import 'package:flutter/widgets.dart';

/// A hairline between groups of fields, with an optional caption in the
/// middle ("or").
class CoilFieldSeparator extends StatelessWidget {
  /// Creates a separator.
  const CoilFieldSeparator({super.key, this.label, this.size, this.style});

  /// A short caption in the middle of the line. Usually a [Text].
  final Widget? label;

  /// Pins the caption to one size step.
  final CoilSize? size;

  /// Overrides for the look.
  final CoilFieldStyle? style;

  @override
  Widget build(BuildContext context) {
    final look = CoilFieldStyle.resolve(context, size: size, style: style);
    final line = SizedBox(
      height: 1,
      child: ColoredBox(color: look.separatorColor!),
    );
    final label = this.label;
    // Flutter has no separator role; only the caption is read.
    return Semantics(
      container: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: look.separatorHeight!),
        child: label == null
            ? Center(child: line)
            : Row(
                spacing: look.separatorLabelGap!,
                children: [
                  Expanded(child: line),
                  DefaultTextStyle(
                    style: look.separatorLabelStyle!,
                    child: label,
                  ),
                  Expanded(child: line),
                ],
              ),
      ),
    );
  }
}
