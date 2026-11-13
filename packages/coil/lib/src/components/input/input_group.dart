import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/input/text_field_chrome.dart';
import 'package:flutter/widgets.dart';

/// A column of labeled fields that share one hover scope.
///
/// The field nearest a hovering pointer shows the `hover` fill, gaps
/// included, so the hover hands over from field to field without flicker.
/// Nothing glides: each field paints its own fill. A touch never hovers;
/// fields show only their focus states.
///
/// Each child is usually a `CoilField` around a `CoilInput` (or
/// `CoilTextarea`), which puts the label above and the error below each
/// field. Fields sit 12 apart (16 on touch), Tab moves between them, and a
/// tap anywhere in a field's box focuses its text.
///
/// ```dart
/// CoilInputGroup(
///   children: [
///     CoilField(label: Text('Name'), child: CoilInput()),
///     CoilField(
///       label: Text('Email'),
///       error: Text('Enter an email address like ada@example.com'),
///       child: CoilInput(),
///     ),
///   ],
/// )
/// ```
class CoilInputGroup extends StatelessWidget {
  /// Creates an input group.
  const CoilInputGroup({required this.children, super.key, this.size});

  /// The fields, top to bottom.
  final List<Widget> children;

  /// Pins every field to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context, size: size);
    Widget group = CoilHoverRegion(
      nearest: true,
      highlight: false,
      // Focus shows as the field's focus border, not as hover.
      followFocus: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: metrics.tier == CoilTier.touch ? 16 : 12,
        children: [
          for (final (index, child) in children.indexed)
            CoilHoverItem(
              index: index,
              child: InputGroupSlot(index: index, child: child),
            ),
        ],
      ),
    );
    if (size case final size?) {
      group = CoilAdaptiveScope(size: size, child: group);
    }
    return group;
  }
}
