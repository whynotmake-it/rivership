import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/coil_pattern.dart';
import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';
import 'src/ink_centering.dart';

const _stack = CoilQuestion<String>.single(
  id: 'stack',
  title: 'Which stack should the app use?',
  options: [
    CoilQuestionOption(value: 'flutter', label: 'Flutter'),
    CoilQuestionOption(value: 'swift', label: 'SwiftUI'),
    CoilQuestionOption(value: 'kotlin', label: 'Jetpack Compose'),
  ],
  otherPlaceholder: 'Something else',
);

const _platforms = CoilQuestion<String>.multiple(
  id: 'platforms',
  title: 'Which platforms ship first?',
  options: [
    CoilQuestionOption(value: 'ios', label: 'iOS'),
    CoilQuestionOption(value: 'android', label: 'Android'),
    CoilQuestionOption(value: 'web', label: 'Web'),
    CoilQuestionOption(value: 'macos', label: 'macOS'),
  ],
  otherPlaceholder: 'Another platform',
);

const _tone = CoilQuestion<String>.single(
  id: 'tone',
  title: 'How should replies sound?',
  layout: CoilQuestionLayout.stacked,
  options: [
    CoilQuestionOption(
      value: 'brief',
      label: 'Brief',
      description: 'Short answers, no small talk.',
    ),
    CoilQuestionOption(
      value: 'warm',
      label: 'Warm',
      description: 'Friendly, with a little context for each step.',
    ),
  ],
);

String? _nameRule(String text) =>
    text.length < 3 ? 'Use at least 3 characters' : null;

const _name = CoilQuestion<String>.freeText(
  id: 'name',
  title: 'What should we call the project?',
  placeholder: 'Project name',
  lines: 1,
  validator: _nameRule,
);

const _questions = [_stack, _platforms, _tone, _name];

/// The card in an app, with a button before it for focus checks.
class _Host extends StatefulWidget {
  const _Host({
    this.questions = _questions,
    this.tier = CoilTier.pointer,
    this.controller,
    this.reduceMotion = false,
    this.autofocus = false,
    this.motions,
    this.onCompleted,
    this.onSkipped,
    this.direction = TextDirection.ltr,
  });

  final List<CoilQuestion<String>> questions;
  final CoilTier tier;
  final CoilAskUserQuestionsController<String>? controller;
  final bool reduceMotion;
  final bool autofocus;
  final Map<CoilAskUserQuestionsTrack<Object>, Motion>? motions;
  final ValueChanged<Map<Object, CoilAnswer<String>>>? onCompleted;
  final ValueChanged<Object>? onSkipped;
  final TextDirection direction;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late CoilThemeData theme = CoilThemeData.light.copyWith(tier: widget.tier);

  void setTheme(CoilThemeData value) => setState(() => theme = value);

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, navigator) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: widget.reduceMotion),
      child: Directionality(
        textDirection: widget.direction,
        child: CoilTheme(data: theme, child: navigator!),
      ),
    ),
    onGenerateRoute: (_) => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoilButton(onPressed: () {}, child: const Text('Before')),
              RepaintBoundary(
                key: _shot,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CoilAskUserQuestions<String>(
                    key: const ValueKey('auq'),
                    questions: widget.questions,
                    controller: widget.controller,
                    autofocus: widget.autofocus,
                    motions: widget.motions,
                    onCompleted: widget.onCompleted,
                    onSkipped: widget.onSkipped,
                  ),
                ),
              ),
              CoilButton(onPressed: () {}, child: const Text('After')),
            ],
          ),
        ),
      ),
    ),
  );
}

final _shot = GlobalKey();

final _card = find.byKey(const ValueKey('auq'));

/// An option's label. A row also lays out a hidden semibold copy, so picking
/// it never reflows; this finds the visible one.
Finder _option(String label) => find.text(label).last;

Future<_HostState> _pump(
  WidgetTester tester, {
  CoilTier tier = CoilTier.pointer,
  CoilAskUserQuestionsController<String>? controller,
  bool reduceMotion = false,
  bool autofocus = false,
  Map<CoilAskUserQuestionsTrack<Object>, Motion>? motions,
  ValueChanged<Map<Object, CoilAnswer<String>>>? onCompleted,
  ValueChanged<Object>? onSkipped,
  TextDirection direction = TextDirection.ltr,
  List<CoilQuestion<String>> questions = _questions,
}) async {
  await tester.pumpWidget(
    _Host(
      tier: tier,
      controller: controller,
      reduceMotion: reduceMotion,
      autofocus: autofocus,
      motions: motions,
      onCompleted: onCompleted,
      onSkipped: onSkipped,
      direction: direction,
      questions: questions,
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

/// The interaction detector of the row showing [label].
CoilInteractionDetector _row(WidgetTester tester, String label) =>
    tester.widget<CoilInteractionDetector>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(CoilInteractionDetector),
          )
          .first,
    );

Iterable<CoilInteractionDetector> _detectors(WidgetTester tester) =>
    tester.widgetList<CoilInteractionDetector>(
      find.descendant(
        of: _card,
        matching: find.byType(CoilInteractionDetector),
      ),
    );

bool _ringShows(WidgetTester tester) => _detectors(
  tester,
).any((d) => d.states.value.contains(WidgetState.focused));

bool _focusInCard() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  var inside = false;
  context.visitAncestorElements((e) {
    inside = e.widget is CoilAskUserQuestions<String>;
    return !inside;
  });
  return inside;
}

bool _editingText() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>() !=
    null;

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  LogicalKeyboardKey? modifier,
}) async {
  if (modifier != null) await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  if (modifier != null) await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

double _cardHeight(WidgetTester tester) => tester.getSize(_card).height;

/// Picks "Flutter" on the first question, then pumps one frame.
Future<void> _pickFirst(WidgetTester tester) async {
  await tester.tap(_option('Flutter'));
  await tester.pump();
}

void main() {
  matrixGoldenTest(
    'ask_user_questions',
    (context) => SizedBox(
      width: 340,
      child: CoilAskUserQuestions<String>(
        questions: _questions,
        controller: CoilAskUserQuestionsController(
          step: 1,
          answers: {
            'platforms': const CoilAnswer(values: {'ios', 'android'}),
          },
        ),
      ),
    ),
    surface: const Size(2300, 4200),
  );

  testWidgets('ask_user_questions sheet: kinds and layouts', (tester) async {
    Widget card(CoilQuestion<String> q, CoilAnswer<String> answer) => SizedBox(
      width: 340,
      child: CoilAskUserQuestions<String>(
        questions: [_stack, q],
        controller: CoilAskUserQuestionsController(
          step: 1,
          answers: {q.id: answer},
        ),
      ),
    );
    Widget column() => Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        card(_tone, const CoilAnswer(values: {'warm'})),
        card(
          const CoilQuestion.single(
            id: 'keys-start',
            title: 'Keys at the start',
            keyPosition: CoilQuestionKeyPosition.start,
            otherPlaceholder: 'Something else',
            options: [
              CoilQuestionOption(value: 'a', label: 'First'),
              CoilQuestionOption(value: 'b', label: 'Second'),
            ],
          ),
          const CoilAnswer(text: 'Typed instead'),
        ),
        card(_name, const CoilAnswer(text: 'Atlas')),
        card(
          const CoilQuestion.freeText(id: 'notes', title: 'Anything else?'),
          const CoilAnswer(),
        ),
      ],
    );
    final sheet = await pumpSheet(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ThemedPair(title: 'pointer', builder: (_) => column()),
          ThemedPair(
            title: 'touch',
            tier: CoilTier.touch,
            builder: (_) => column(),
          ),
        ],
      ),
      surface: const Size(900, 2400),
    );
    await expectSheetGolden(tester, sheet, 'goldens/ask_user_questions.png');
  });

  group('state goldens', () {
    Future<void> golden(WidgetTester tester, String name) async {
      await expectLater(
        find.byKey(_shot),
        matchesGoldenFile('goldens/ask_user_questions_$name.png'),
      );
    }

    testWidgets('hover shows the submit arrow on a single-choice row', (
      tester,
    ) async {
      await _pump(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(_option('SwiftUI')));
      await tester.pumpAndSettle();
      await golden(tester, 'hover');
    });

    testWidgets('keyboard focus rings the row', (tester) async {
      await _pump(tester, autofocus: true);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await golden(tester, 'focus');
    });

    testWidgets('an empty "other" field shows chrome while focused', (
      tester,
    ) async {
      await _pump(tester, autofocus: true);
      await _key(tester, LogicalKeyboardKey.digit4);
      expect(_editingText(), isTrue);
      await golden(tester, 'other');
    });

    testWidgets('a rejected free-text answer shows its message', (
      tester,
    ) async {
      await _pump(
        tester,
        controller: CoilAskUserQuestionsController(step: 3),
      );
      await tester.enterText(find.byType(EditableText), 'ab');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await golden(tester, 'error');
    });

    testWidgets('a finger shows the press fill on touch', (tester) async {
      await _pump(
        tester,
        tier: CoilTier.touch,
        controller: CoilAskUserQuestionsController(step: 1),
      );
      final finger = await tester.startGesture(
        tester.getCenter(_option('Android')),
      );
      // The fill starts on the next frame, then fades in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await golden(tester, 'pressed');
      await finger.up();
      await tester.pumpAndSettle();
    });
  });

  group('rows center their labels', () {
    // The shared ink test measures a whole widget; a row only exists inside
    // the card, so this measures the row's own rect the same way.
    for (final (name, question) in [
      (
        'single',
        const CoilQuestion<String>.single(
          id: 'q',
          title: 'Q',
          options: [CoilQuestionOption(value: 'a', label: 'HEH')],
        ),
      ),
      (
        'multiple',
        const CoilQuestion<String>.multiple(
          id: 'q',
          title: 'Q',
          options: [CoilQuestionOption(value: 'a', label: 'HEH')],
        ),
      ),
    ]) {
      for (final tier in CoilTier.values) {
        for (final size in CoilSize.values) {
          for (final scale in [1.0, 1.5, 2.0]) {
            testWidgets('$name @ ${tier.name} ${size.name} x$scale', (
              tester,
            ) async {
              await _expectRowCentered(tester, question, tier, size, scale);
            });
          }
        }
      }
    }
  });

  group('flow', () {
    testWidgets('picking a single option answers it and moves on', (
      tester,
    ) async {
      final controller = CoilAskUserQuestionsController<String>();
      await _pump(tester, controller: controller);
      expect(find.text('Question 1 of 4'), findsOneWidget);
      await tester.tap(_option('SwiftUI'));
      await tester.pumpAndSettle();
      expect(controller.step, 1);
      expect(controller.answerOf('stack').values, {'swift'});
      expect(find.text('Question 2 of 4'), findsOneWidget);
      expect(find.text('Which platforms ship first?'), findsOneWidget);
    });

    testWidgets('multiple choice toggles, then Continue moves on', (
      tester,
    ) async {
      final controller = CoilAskUserQuestionsController<String>(step: 1);
      await _pump(tester, controller: controller);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(controller.step, 1, reason: 'Continue waits for an answer');

      await tester.tap(_option('iOS'));
      await tester.tap(_option('Web'));
      await tester.tap(_option('iOS'));
      await tester.pumpAndSettle();
      expect(controller.answerOf('platforms').values, {'web'});

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(controller.step, 2);
    });

    testWidgets('a typed "other" answer replaces the pick and submits', (
      tester,
    ) async {
      final controller = CoilAskUserQuestionsController<String>(
        answers: {
          'stack': const CoilAnswer(values: {'swift'}),
        },
      );
      await _pump(tester, controller: controller);
      await tester.enterText(find.byType(EditableText), 'Dart');
      await tester.pump();
      expect(
        controller.answerOf('stack'),
        const CoilAnswer<String>(text: 'Dart'),
        reason: 'one answer: typing drops the picked option',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.step, 1);
    });

    testWidgets('Enter in a multiple-choice "other" field continues', (
      tester,
    ) async {
      final controller = CoilAskUserQuestionsController<String>(step: 1);
      await _pump(tester, controller: controller);
      await tester.tap(_option('Android'));
      await tester.enterText(find.byType(EditableText), 'Linux');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.step, 2);
      expect(
        controller.answerOf('platforms'),
        const CoilAnswer<String>(values: {'android'}, text: 'Linux'),
      );
    });

    testWidgets('a free-text validator blocks the submit until fixed', (
      tester,
    ) async {
      Map<Object, CoilAnswer<String>>? completed;
      await _pump(
        tester,
        controller: CoilAskUserQuestionsController(step: 3),
        onCompleted: (answers) => completed = answers,
      );
      await tester.enterText(find.byType(EditableText), 'ab');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Use at least 3 characters'), findsOneWidget);
      expect(completed, isNull);

      await tester.enterText(find.byType(EditableText), 'abc');
      await tester.pump();
      expect(find.text('Use at least 3 characters'), findsNothing);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(completed?['name']?.text, 'abc');
    });

    testWidgets('Skip marks the question skipped; Back keeps answers', (
      tester,
    ) async {
      final skipped = <Object>[];
      final controller = CoilAskUserQuestionsController<String>(
        step: 1,
        answers: {
          'platforms': const CoilAnswer(values: {'ios'}),
        },
      );
      await _pump(tester, controller: controller, onSkipped: skipped.add);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(skipped, ['platforms']);
      expect(controller.step, 2);
      expect(
        controller.answerOf('platforms'),
        const CoilAnswer<String>(values: {'ios'}, skipped: true),
      );

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(controller.step, 1);
      expect(find.text('Which platforms ship first?'), findsOneWidget);
    });

    testWidgets('answering the last question completes with every answer', (
      tester,
    ) async {
      Map<Object, CoilAnswer<String>>? completed;
      await _pump(tester, onCompleted: (a) => completed = a);
      await tester.tap(_option('Flutter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(_option('Brief'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Atlas');
      await tester.pump();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(
        completed?.keys,
        unorderedEquals(['stack', 'platforms', 'tone', 'name']),
      );
      expect(completed?['platforms']?.skipped, isTrue);
      expect(completed?['name']?.text, 'Atlas');
    });

    testWidgets('the controller drives the flow from outside', (tester) async {
      final controller = CoilAskUserQuestionsController<String>();
      await _pump(tester, controller: controller);
      controller.step = 2;
      await tester.pumpAndSettle();
      expect(find.text('Question 3 of 4'), findsOneWidget);
      controller.reset();
      await tester.pumpAndSettle();
      expect(find.text('Question 1 of 4'), findsOneWidget);
    });

    testWidgets('no questions shows the empty label', (tester) async {
      await _pump(tester, questions: const []);
      expect(find.text('No questions.'), findsOneWidget);
    });
  });

  group('keyboard', () {
    testWidgets('number keys pick, toggle, or open the "other" field', (
      tester,
    ) async {
      final controller = CoilAskUserQuestionsController<String>();
      await _pump(tester, controller: controller, autofocus: true);
      await _key(tester, LogicalKeyboardKey.digit2);
      expect(controller.answerOf('stack').values, {'swift'});
      expect(controller.step, 1);

      await _key(tester, LogicalKeyboardKey.digit1);
      await _key(tester, LogicalKeyboardKey.digit3);
      expect(controller.answerOf('platforms').values, {'ios', 'web'});

      await _key(tester, LogicalKeyboardKey.digit5);
      expect(_editingText(), isTrue, reason: '5 is the "other" row');
      await _key(tester, LogicalKeyboardKey.digit1);
      expect(
        controller.answerOf('platforms').values,
        {'ios', 'web'},
        reason: 'digits typed into a field are text',
      );
    });

    testWidgets('arrows move between rows without picking; Enter picks', (
      tester,
    ) async {
      final controller = CoilAskUserQuestionsController<String>();
      await _pump(tester, controller: controller, autofocus: true);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(
        _row(tester, 'SwiftUI').states.value,
        contains(WidgetState.focused),
      );
      expect(controller.answerOf('stack').isEmpty, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(
        _row(tester, 'Jetpack Compose').states.value,
        contains(WidgetState.focused),
        reason: 'Up wraps to the last row',
      );
      await _key(tester, LogicalKeyboardKey.enter);
      expect(controller.answerOf('stack').values, {'kotlin'});
      expect(controller.step, 1);
    });

    testWidgets('Up and Down leave the "other" field for the rows', (
      tester,
    ) async {
      await _pump(tester, autofocus: true);
      await _key(tester, LogicalKeyboardKey.digit4);
      expect(_editingText(), isTrue);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(
        _row(tester, 'Jetpack Compose').states.value,
        contains(WidgetState.focused),
      );
      await _key(tester, LogicalKeyboardKey.digit4);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(
        _row(tester, 'Flutter').states.value,
        contains(WidgetState.focused),
      );
    });

    testWidgets('focus moves to the next question after a keyboard pick', (
      tester,
    ) async {
      await _pump(tester, autofocus: true);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(find.text('Question 2 of 4'), findsOneWidget);
      expect(_row(tester, 'iOS').states.value, contains(WidgetState.focused));
    });

    testWidgets('a free-text question takes focus when reached by keyboard', (
      tester,
    ) async {
      await _pump(
        tester,
        controller: CoilAskUserQuestionsController(step: 2),
        autofocus: true,
      );
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_editingText(), isTrue);
    });

    testWidgets('Escape and the back arrow return; the forward arrow skips', (
      tester,
    ) async {
      final controller = CoilAskUserQuestionsController<String>(step: 1);
      await _pump(tester, controller: controller, autofocus: true);
      await _key(tester, LogicalKeyboardKey.escape);
      expect(controller.step, 0);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(controller.step, 1);
      expect(controller.answerOf('stack').skipped, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(controller.step, 0);
    });

    testWidgets('in RTL the arrows flip', (tester) async {
      final controller = CoilAskUserQuestionsController<String>(step: 1);
      await _pump(
        tester,
        controller: controller,
        autofocus: true,
        direction: TextDirection.rtl,
      );
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(controller.step, 0, reason: 'Right points back in RTL');
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(controller.step, 1, reason: 'Left skips in RTL');
    });

    testWidgets('Ctrl+Enter continues a multiple-choice question', (
      tester,
    ) async {
      final controller = CoilAskUserQuestionsController<String>(step: 1);
      await _pump(tester, controller: controller, autofocus: true);
      await _key(tester, LogicalKeyboardKey.space);
      expect(controller.answerOf('platforms').values, {'ios'});
      await _key(
        tester,
        LogicalKeyboardKey.enter,
        modifier: LogicalKeyboardKey.controlLeft,
      );
      expect(controller.step, 2);
    });

    testWidgets('follows the question pattern', (tester) async {
      await _pump(tester);
      await expectCoilPattern(tester, _card, CoilPattern.question);
    });

    testWidgets('follows the question pattern in RTL', (tester) async {
      await _pump(
        tester,
        direction: TextDirection.rtl,
        controller: CoilAskUserQuestionsController(step: 1),
      );
      await expectCoilPattern(tester, _card, CoilPattern.question);
    });
  });

  group('touch and mouse', () {
    testWidgets('touch hides the number keys and rows are 44 tall', (
      tester,
    ) async {
      await _pump(tester, tier: CoilTier.touch);
      expect(find.text('1'), findsNothing);
      final row = find
          .ancestor(
            of: _option('Flutter'),
            matching: find.byType(CoilChoiceItem),
          )
          .first;
      expect(tester.getSize(row).height, 44);
    });

    testWidgets('pointer shows a number key per row, the "other" row too', (
      tester,
    ) async {
      await _pump(tester);
      for (final n in ['1', '2', '3', '4']) {
        expect(find.text(n), findsOneWidget);
      }
    });

    testWidgets('a touch presses a row and leaves nothing lit', (
      tester,
    ) async {
      await _pump(
        tester,
        tier: CoilTier.touch,
        controller: CoilAskUserQuestionsController(step: 1),
      );
      final finger = await tester.startGesture(
        tester.getCenter(_option('Android')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        _row(tester, 'Android').states.value,
        contains(WidgetState.pressed),
      );
      await finger.up();
      await tester.pumpAndSettle();
      expect(_row(tester, 'Android').states.value, isEmpty);
      expect(_focusInCard(), isFalse, reason: 'a tap takes no focus');
    });

    testWidgets('a tap moving on does not pull focus or the keyboard', (
      tester,
    ) async {
      await _pump(
        tester,
        tier: CoilTier.touch,
        controller: CoilAskUserQuestionsController(step: 2),
      );
      await tester.tap(_option('Brief'));
      await tester.pumpAndSettle();
      expect(find.text('What should we call the project?'), findsOneWidget);
      expect(_editingText(), isFalse);
    });

    testWidgets('a mouse hovers rows; a click shows no ring', (tester) async {
      await _pump(tester, controller: CoilAskUserQuestionsController(step: 1));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(_option('Web')));
      await tester.pumpAndSettle();
      expect(_row(tester, 'Web').states.value, contains(WidgetState.hovered));
      await mouse.down(tester.getCenter(_option('Web')));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(_ringShows(tester), isFalse);
    });
  });

  group('semantics', () {
    testWidgets('announces the step and groups each question', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(
        tester.getSemantics(find.text('Question 1 of 4')),
        matchesSemantics(label: 'Question 1 of 4', isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.text('Which stack should the app use?')),
        matchesSemantics(
          label: 'Which stack should the app use?',
          isHeader: true,
        ),
      );
      final group = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.role == SemanticsRole.radioGroup &&
            w.properties.label == 'Which stack should the app use?',
      );
      expect(group, findsOneWidget);
      expect(
        tester.getSemantics(_option('SwiftUI')),
        matchesSemantics(
          label: 'SwiftUI',
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.tap(_option('SwiftUI'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Question 2 of 4')),
        matchesSemantics(label: 'Question 2 of 4', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('a stacked row reads its label and description', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, controller: CoilAskUserQuestionsController(step: 2));
      expect(
        find.bySemanticsLabel('Brief, Short answers, no small talk.'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('motion', () {
    testWidgets('the height springs to the next question', (tester) async {
      await _pump(tester);
      final before = _cardHeight(tester);
      await _pickFirst(tester);
      await tester.pump(const Duration(milliseconds: 40));
      final mid = _cardHeight(tester);
      await tester.pumpAndSettle();
      final after = _cardHeight(tester);
      expect(after, greaterThan(before));
      expect(mid, inExclusiveRange(before, after));
    });

    testWidgets('reduced motion makes the height instant', (tester) async {
      await _pump(tester, reduceMotion: true);
      await _pickFirst(tester);
      await tester.pump();
      final first = _cardHeight(tester);
      await tester.pumpAndSettle();
      expect(first, _cardHeight(tester));
    });

    testWidgets('a per-track motion overrides the height spring', (
      tester,
    ) async {
      await _pump(
        tester,
        motions: {CoilAskUserQuestionsTrack.height: const Motion.instant()},
      );
      await _pickFirst(tester);
      await tester.pump();
      final first = _cardHeight(tester);
      await tester.pumpAndSettle();
      expect(first, _cardHeight(tester));
    });

    testWidgets('a theme change applies to the next question change', (
      tester,
    ) async {
      final host = await _pump(tester);
      host.setTheme(
        host.theme.copyWith(
          motion: host.theme.motion.copyWith(standard: const Motion.instant()),
        ),
      );
      await tester.pumpAndSettle();
      await _pickFirst(tester);
      await tester.pump();
      final first = _cardHeight(tester);
      await tester.pumpAndSettle();
      expect(first, _cardHeight(tester));
    });
  });

  testWidgets('style: fallback < theme < instance', (tester) async {
    Color surface() =>
        (tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: _card,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as ShapeDecoration)
            .color!;
    final host = await _pump(tester);
    expect(surface(), CoilThemeData.light.colors.surface(3));
    host.setTheme(
      host.theme.withComponentStyle(
        const CoilAskUserQuestionsStyle(surface: Color(0xFFFF0000)),
      ),
    );
    await tester.pump();
    expect(surface(), const Color(0xFFFF0000));
    await tester.pumpWidget(
      CoilTheme(
        data: host.theme,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: CoilAskUserQuestions<String>(
            key: ValueKey('auq'),
            questions: _questions,
            style: CoilAskUserQuestionsStyle(surface: Color(0xFF0000FF)),
          ),
        ),
      ),
    );
    expect(surface(), const Color(0xFF0000FF));
  });
}

/// Renders [question]'s single row with its label shown and hidden, and
/// checks the label's ink is centered in the row (±1 px, as the shared ink
/// test).
Future<void> _expectRowCentered(
  WidgetTester tester,
  CoilQuestion<String> question,
  CoilTier tier,
  CoilSize size,
  double scale,
) async {
  const ratio = 8.0;
  final ink = ValueNotifier(true);
  addTearDown(ink.dispose);
  final boundary = GlobalKey();
  final withChild = switch (question.kind) {
    CoilQuestionKind.single => CoilQuestion<String>.single(
      id: question.id,
      title: question.title,
      options: [
        CoilQuestionOption(
          value: 'a',
          label: 'HEH',
          child: ValueListenableBuilder(
            valueListenable: ink,
            builder: (_, visible, _) => InkLabel(visible, const Text('HEH')),
          ),
        ),
      ],
    ),
    _ => CoilQuestion<String>.multiple(
      id: question.id,
      title: question.title,
      options: [
        CoilQuestionOption(
          value: 'a',
          label: 'HEH',
          child: ValueListenableBuilder(
            valueListenable: ink,
            builder: (_, visible, _) => InkLabel(visible, const Text('HEH')),
          ),
        ),
      ],
    ),
  };
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: CoilTheme(
          data: CoilThemeData.light.copyWith(tier: tier),
          child: CoilAdaptiveScope(
            size: size,
            child: Center(
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 320,
                  child: CoilAskUserQuestions<String>(questions: [withChild]),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final row = tester.getRect(find.byType(CoilChoiceItem));
  final origin = tester.getTopLeft(find.byKey(boundary));
  Future<Uint8List> render() async {
    final box = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundary),
    );
    final bytes = await tester.runAsync(() async {
      final image = await box.toImage(pixelRatio: ratio);
      final data = await image.toByteData();
      image.dispose();
      return data!.buffer.asUint8List();
    });
    return bytes!;
  }

  final shown = await render();
  ink.value = false;
  await tester.pumpAndSettle();
  final hidden = await render();
  final width = (tester.getSize(find.byKey(boundary)).width * ratio).round();
  final top = ((row.top - origin.dy) * ratio).round();
  final bottom = ((row.bottom - origin.dy) * ratio).round();
  int? first;
  int? last;
  for (var y = top; y < bottom; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      var diff = 0;
      for (var c = 0; c < 4; c++) {
        diff += (shown[i + c] - hidden[i + c]).abs();
      }
      if (diff > 160) {
        first ??= y;
        last = y;
        break;
      }
    }
  }
  expect(first, isNotNull, reason: 'no label ink found');
  final topGap = (first! - top) / ratio;
  final bottomGap = (bottom - 1 - last!) / ratio;
  expect(
    (topGap - bottomGap).abs(),
    lessThanOrEqualTo(1),
    reason: 'top $topGap, bottom $bottomGap',
  );
}
