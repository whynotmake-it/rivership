import 'package:coil/src/components/ask_user_questions/question.dart';
import 'package:flutter/foundation.dart';

/// The state of a `CoilAskUserQuestions`: which question shows, and the
/// answers so far.
///
/// Pass one to read or drive the flow from outside, for example to restore
/// a half-answered flow or to save answers as they change. Without one, the
/// widget keeps its own.
class CoilAskUserQuestionsController<T> extends ChangeNotifier {
  /// Creates a controller at [step] with [answers], keyed by
  /// `CoilQuestion.id`.
  CoilAskUserQuestionsController({
    int step = 0,
    Map<Object, CoilAnswer<T>> answers = const {},
  }) : assert(step >= 0, 'The step is an index.'),
       _step = step,
       _answers = Map.of(answers);

  int _step;
  final Map<Object, CoilAnswer<T>> _answers;

  /// The index of the question that shows.
  int get step => _step;
  set step(int value) {
    assert(value >= 0, 'The step is an index.');
    if (value == _step) return;
    _step = value;
    notifyListeners();
  }

  /// The answers so far, keyed by `CoilQuestion.id`.
  Map<Object, CoilAnswer<T>> get answers => Map.unmodifiable(_answers);

  /// The answer to the question with [id]; empty when there is none.
  CoilAnswer<T> answerOf(Object id) => _answers[id] ?? CoilAnswer<T>();

  /// Replaces the answer to the question with [id].
  void setAnswer(Object id, CoilAnswer<T> answer) {
    if (_answers[id] == answer) return;
    _answers[id] = answer;
    notifyListeners();
  }

  /// Goes back to the first question and clears every answer.
  void reset() {
    if (_step == 0 && _answers.isEmpty) return;
    _step = 0;
    _answers.clear();
    notifyListeners();
  }
}
