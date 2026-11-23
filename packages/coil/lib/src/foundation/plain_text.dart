import 'package:flutter/widgets.dart';

/// The plain text of [label] when it is a [Text] (its `data`, or the
/// `toPlainText()` of its `Text.rich` span), else null.
///
/// Components use it to default a string that would only restate a text
/// label: what screen readers announce, or what typeahead matches.
String? plainTextOf(Widget? label) {
  if (label is! Text) return null;
  return label.data ?? label.textSpan?.toPlainText();
}
