import 'package:coil/foundation.dart';
import 'package:coil/src/components/field/field_group.dart';
import 'package:coil/src/components/field/field_style.dart';
import 'package:flutter/widgets.dart';

/// Related fields under one heading (the [legend]), such as an address
/// block or a group of checkboxes. Screen readers read the legend first.
class CoilFieldSet extends StatelessWidget {
  /// Creates a field set.
  const CoilFieldSet({
    required this.children,
    super.key,
    this.legend,
    this.description,
    this.size,
    this.style,
  });

  /// The set's heading. Usually a [Text].
  final Widget? legend;

  /// One sentence under the legend.
  final Widget? description;

  /// The fields.
  final List<Widget> children;

  /// Pins the text and spacing to one size step.
  final CoilSize? size;

  /// Overrides for the look.
  final CoilFieldStyle? style;

  @override
  Widget build(BuildContext context) {
    final look = CoilFieldStyle.resolve(context, size: size, style: style);
    final header = [
      if (legend case final legend?)
        Semantics(
          header: true,
          child: DefaultTextStyle(style: look.legendStyle!, child: legend),
        ),
      if (description case final description?)
        DefaultTextStyle(style: look.descriptionStyle!, child: description),
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: look.fieldGap!,
        children: [
          if (header.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: look.legendGap!,
              children: header,
            ),
          CoilFieldGroup(size: size, style: style, children: children),
        ],
      ),
    );
  }
}
