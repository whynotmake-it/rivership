import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// What kind of answer a [CoilQuestion] asks for.
enum CoilQuestionKind {
  /// Pick one option. Picking it answers the question and moves on.
  single,

  /// Pick any number of options, then continue.
  multiple,

  /// Type an answer. There are no options.
  freeText,
}

/// How a [CoilQuestion] lays out an option's label and description.
enum CoilQuestionLayout {
  /// The description follows the label on the same line, muted. The row
  /// stays one line and truncates.
  inline,

  /// The description sits under the label in the caption role and wraps.
  stacked,
}

/// Which edge of an option row the number key sits on.
enum CoilQuestionKeyPosition {
  /// At the end of the row: right, or left in RTL.
  end,

  /// At the start of the row, before the label. A single-choice row then
  /// shows its submit arrow at the end.
  start,
}

/// One choice of a [CoilQuestion].
@immutable
class CoilQuestionOption<T> {
  /// Creates an option.
  const CoilQuestionOption({
    required this.value,
    required this.label,
    this.description,
    this.child,
  });

  /// What picking this option reports in [CoilAnswer.values].
  final T value;

  /// The option's text, also read by screen readers.
  final String label;

  /// More detail, muted. Where it goes depends on [CoilQuestion.layout].
  final String? description;

  /// Replaces the `Text(label)` in the row. [label] still names the row for
  /// screen readers.
  final Widget? child;
}

/// One step of a `CoilAskUserQuestions`.
@immutable
class CoilQuestion<T> {
  /// A question that takes one option. Picking an option answers it and
  /// moves to the next question.
  ///
  /// With [otherPlaceholder], a last row takes a typed answer instead,
  /// submitted with Enter or the keyboard's action button.
  const CoilQuestion.single({
    required this.id,
    required this.title,
    required this.options,
    this.otherPlaceholder,
    this.skippable = true,
    this.nextLabel,
    this.layout = CoilQuestionLayout.inline,
    this.keyPosition = CoilQuestionKeyPosition.end,
  }) : kind = CoilQuestionKind.single,
       placeholder = null,
       lines = 1,
       validator = null;

  /// A question that takes any number of options, answered with the
  /// Continue button (or Ctrl/⌘+Enter).
  ///
  /// With [otherPlaceholder], a last row adds a typed answer.
  const CoilQuestion.multiple({
    required this.id,
    required this.title,
    required this.options,
    this.otherPlaceholder,
    this.skippable = true,
    this.nextLabel,
    this.layout = CoilQuestionLayout.inline,
    this.keyPosition = CoilQuestionKeyPosition.end,
  }) : kind = CoilQuestionKind.multiple,
       placeholder = null,
       lines = 1,
       validator = null;

  /// A question answered by typing, in a field [lines] tall that grows with
  /// its text.
  ///
  /// [validator] runs when the answer is submitted. It returns a message
  /// that blocks the submit, or null to allow it.
  const CoilQuestion.freeText({
    required this.id,
    required this.title,
    this.placeholder,
    this.lines = 3,
    this.validator,
    this.skippable = true,
    this.nextLabel,
  }) : assert(lines > 0, 'A free-text field shows at least one line.'),
       kind = CoilQuestionKind.freeText,
       options = const [],
       otherPlaceholder = null,
       layout = CoilQuestionLayout.inline,
       keyPosition = CoilQuestionKeyPosition.end;

  /// Identifies the question in the answers. Unique within a flow.
  final Object id;

  /// The question.
  final String title;

  /// What kind of answer it takes.
  final CoilQuestionKind kind;

  /// The choices. Empty for [CoilQuestionKind.freeText].
  final List<CoilQuestionOption<T>> options;

  /// The placeholder of the typed "other" row. Null: no such row.
  final String? otherPlaceholder;

  /// Whether Skip is offered.
  final bool skippable;

  /// The label of the button that answers the question. Null: "Continue",
  /// or "Finish" on the last question.
  final String? nextLabel;

  /// How option rows lay out their descriptions.
  final CoilQuestionLayout layout;

  /// Which edge the option rows' number keys sit on.
  final CoilQuestionKeyPosition keyPosition;

  /// The free-text field's placeholder.
  final String? placeholder;

  /// How tall the free-text field starts, in lines. 1 makes it single-line.
  final int lines;

  /// Checks a free-text answer when it's submitted.
  final String? Function(String text)? validator;
}

/// The answer to one [CoilQuestion].
@immutable
class CoilAnswer<T> {
  /// Creates an answer.
  const CoilAnswer({
    this.values = const {},
    this.text = '',
    this.skipped = false,
  });

  /// The picked options' values.
  final Set<T> values;

  /// The typed answer: the "other" row or a free-text question.
  final String text;

  /// Whether the question was skipped. Picks made before skipping stay.
  final bool skipped;

  /// Whether nothing is picked or typed.
  bool get isEmpty => values.isEmpty && text.trim().isEmpty;

  /// Returns a copy with the given fields replaced.
  CoilAnswer<T> copyWith({Set<T>? values, String? text, bool? skipped}) =>
      CoilAnswer(
        values: values ?? this.values,
        text: text ?? this.text,
        skipped: skipped ?? this.skipped,
      );

  @override
  bool operator ==(Object other) =>
      other is CoilAnswer<T> &&
      setEquals(other.values, values) &&
      other.text == text &&
      other.skipped == skipped;

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(values), text, skipped);

  @override
  String toString() =>
      'CoilAnswer(values: $values, text: "$text", skipped: $skipped)';
}
