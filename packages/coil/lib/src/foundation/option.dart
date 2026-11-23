import 'package:coil/src/foundation/plain_text.dart';
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
    String? searchText,
    this.semanticLabel,
    this.enabled = true,
  }) // The field is null when the label is the choice's text.
    // ignore: prefer_initializing_formals
    : _searchText = searchText;

  /// What picking this choice reports.
  final T value;

  /// What the row shows, usually a [Text]. The row styles it with
  /// [DefaultTextStyle] and [IconTheme], and screen readers read it.
  final Widget label;

  /// A leading glyph, sized and colored by the row through [IconTheme].
  final Widget? icon;

  /// The choice as plain text, for what needs a string: typeahead and
  /// filtering match it, and a select announces it as its value.
  ///
  /// Defaults to the text of [label] when it is a [Text]. Set it when the
  /// label is another widget; without any text, typeahead and filters skip
  /// the choice.
  String? get searchText => _searchText ?? plainTextOf(label);
  final String? _searchText;

  /// Names the choice for screen readers when [label] can't, such as an
  /// icon-only toggle.
  final String? semanticLabel;

  /// Whether the choice can be picked. Disabled rows are skipped by the
  /// highlight, the arrow keys and typeahead.
  final bool enabled;
}
