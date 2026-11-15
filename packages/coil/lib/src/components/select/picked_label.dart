import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// What a select-style trigger shows: [placeholder] (muted) when nothing is
/// picked, the one option's label, or several labels in one line,
/// comma-separated and cut with an ellipsis when they don't fit.
Widget pickedLabel<T>(
  List<CoilOption<T>> picked, {
  required bool multiple,
  required Widget placeholder,
  required Color placeholderColor,
}) => switch (picked) {
  [] => DefaultTextStyle.merge(
    style: TextStyle(color: placeholderColor),
    child: placeholder,
  ),
  [final only] when !multiple => only.label,
  _ => Text.rich(
    TextSpan(
      children: [
        for (final (i, option) in picked.indexed) ...[
          if (i > 0) const TextSpan(text: ', '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: option.label,
          ),
        ],
      ],
    ),
  ),
};

/// The picked options as a screen reader's value: their semantic labels or
/// search texts, comma-separated. Null when nothing is picked or an option
/// has neither, so the trigger reads its labels instead.
String? pickedSemanticValue<T>(List<CoilOption<T>> picked) {
  final texts = [
    for (final option in picked) ?(option.semanticLabel ?? option.searchText),
  ];
  return picked.isEmpty || texts.length < picked.length
      ? null
      : texts.join(', ');
}
