import 'package:flutter/widgets.dart';

/// One choice of a list of values: a select's option, a group's item.
///
/// Data, not a widget, so it lives in the foundation and every component
/// that offers choices uses the same shape.
@immutable
class CoilOption<T> {
  /// Creates a choice.
  const CoilOption({
    required this.value,
    required this.label,
    this.icon,
    this.child,
    this.enabled = true,
  });

  /// What picking this choice reports.
  final T value;

  /// The text of the choice: shown unless [child] is set, matched by
  /// typeahead, and read by screen readers.
  final String label;

  /// A leading glyph, sized and colored by the row through [IconTheme].
  final Widget? icon;

  /// Replaces the `Text(label)` in the row.
  final Widget? child;

  /// Whether the choice can be picked. Disabled rows are skipped by the
  /// highlight, the arrow keys and typeahead.
  final bool enabled;
}
