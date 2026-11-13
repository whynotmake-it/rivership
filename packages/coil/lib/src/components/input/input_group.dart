import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/input/text_field_chrome.dart';
import 'package:flutter/widgets.dart';

/// A stack of labeled fields that share one hover.
///
/// The field nearest the mouse shows the hover fill, even when the pointer
/// is in the gap between fields, so the hover never flickers off. Touch
/// shows focus only. Each child is usually a `CoilField` around a
/// `CoilInput`.
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
