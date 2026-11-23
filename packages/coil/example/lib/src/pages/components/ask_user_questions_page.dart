import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const askUserQuestionsEntry = CatalogEntry(
  slug: 'ask-user-questions',
  title: 'AskUserQuestions',
  group: CatalogGroup.shellAndComposites,
  summary:
      'A card an assistant uses to ask what it needs to know, one question at '
      'a time.',
  page: AskUserQuestionsPage.new,
);

const _questions = <CoilQuestion<String>>[
  CoilQuestion.single(
    id: 'stack',
    title: Text('Which stack should the app use?'),
    options: [
      CoilQuestionOption(value: 'flutter', label: Text('Flutter')),
      CoilQuestionOption(value: 'swift', label: Text('SwiftUI')),
      CoilQuestionOption(value: 'kotlin', label: Text('Jetpack Compose')),
    ],
    otherPlaceholder: Text('Something else'),
    otherSemanticLabel: 'Something else',
  ),
  CoilQuestion.multiple(
    id: 'platforms',
    title: Text('Which platforms ship first?'),
    options: [
      CoilQuestionOption(value: 'ios', label: Text('iOS')),
      CoilQuestionOption(value: 'android', label: Text('Android')),
      CoilQuestionOption(value: 'web', label: Text('Web')),
      CoilQuestionOption(value: 'macos', label: Text('macOS')),
    ],
    otherPlaceholder: Text('Another platform'),
    otherSemanticLabel: 'Another platform',
  ),
  CoilQuestion.single(
    id: 'tone',
    title: Text('How should replies sound?'),
    layout: CoilQuestionLayout.stacked,
    options: [
      CoilQuestionOption(
        value: 'brief',
        label: Text('Brief'),
        description: Text('Short answers, no small talk.'),
      ),
      CoilQuestionOption(
        value: 'warm',
        label: Text('Warm'),
        description: Text('Friendly, with a little context for each step.'),
      ),
    ],
  ),
  CoilQuestion.freeText(
    id: 'name',
    title: Text('What should we call the project?'),
    placeholder: Text('Project name'),
    lines: 1,
    validator: _nameRule,
  ),
];

Widget? _nameRule(String text) =>
    text.length < 3 ? const Text('Use at least 3 characters') : null;

class AskUserQuestionsPage extends StatefulWidget {
  const AskUserQuestionsPage({super.key});

  @override
  State<AskUserQuestionsPage> createState() => _AskUserQuestionsPageState();
}

class _AskUserQuestionsPageState extends State<AskUserQuestionsPage> {
  final _flow = CoilAskUserQuestionsController<String>();
  Map<Object, CoilAnswer<String>>? _answers;

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  static const _labels = {
    'stack': 'Stack',
    'platforms': 'Platforms',
    'tone': 'Tone',
    'name': 'Project name',
  };

  static String _picks(CoilAnswer<String> answer) => [
    ...answer.values,
    if (answer.text.isNotEmpty) answer.text,
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final answers = _answers;
    return CatalogPage(
      title: 'AskUserQuestions',
      summary:
          'An agent asks what it needs before it starts, one question at a '
          'time, and you can go back or skip a question. On a pointer the '
          'number keys pick the rows, while on touch the numbers are hidden '
          'and the rows grow to 44.',
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          const CoilChatMessage(
            sender: CoilChatSender.user,
            entrance: CoilChatMessageEntrance.none,
            child: Text('Build me a habit tracker'),
          ),
          const CoilChatMessage(
            sender: CoilChatSender.assistant,
            entrance: CoilChatMessageEntrance.none,
            child: Text('Happy to. Four quick questions before I start.'),
          ),
          if (answers == null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CoilAskUserQuestions<String>(
                questions: _questions,
                controller: _flow,
                onCompleted: (a) => setState(() => _answers = a),
              ),
            )
          else ...[
            CoilChatMessage(
              sender: CoilChatSender.assistant,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Got it. I am starting with:'),
                  const SizedBox(height: 8),
                  for (final MapEntry(:key, :value) in answers.entries)
                    Text(
                      '${_labels[key] ?? key}: '
                      '${value.skipped ? 'skipped' : _picks(value)}',
                      style: text.muted.body,
                    ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CoilButton(
                variant: CoilButtonVariant.secondary,
                size: CoilSize.compact,
                onPressed: () => setState(() {
                  _answers = null;
                  _flow.reset();
                }),
                child: const Text('Ask again'),
              ),
            ),
          ],
        ],
      ),
      usage: '''
CoilAskUserQuestions<String>(
  questions: const [
    CoilQuestion.single(
      id: 'stack',
      title: Text('Which stack should the app use?'),
      options: [
        CoilQuestionOption(value: 'flutter', label: Text('Flutter')),
        CoilQuestionOption(value: 'swift', label: Text('SwiftUI')),
      ],
    ),
  ],
  onCompleted: (answers) => start(answers),
)''',
      notes: const [
        CatalogNote(
          'Keyboard',
          'The keys 1 to 9 pick the matching row, Up and Down move between '
              'rows and Enter picks the active one. Escape goes back a '
              'question, and Ctrl or ⌘ with Enter continues.',
        ),
        CatalogNote(
          'Touch',
          'The number keys and the submit arrow are hidden, and rows are 44 '
              'tall with a fill while pressed. Picking a row never takes '
              'focus, so the keyboard stays down until you tap a field.',
        ),
        CatalogNote(
          'Motion',
          'Moving to the next question springs the card to its new height on '
              'the standard spring, while the old question fades out and the '
              'new one fades in.',
        ),
        CatalogNote(
          'Accessibility',
          'When a typed answer is rejected, the field is marked invalid and '
              'its message appears underneath in a live region, so a screen '
              'reader reads it out as it arrives.',
        ),
      ],
      children: const [
        DemoSection(
          title: 'Compact, with the keys at the start',
          description:
              'A step denser for a narrow panel, with each number sitting '
              'before its label instead of after it.',
          child: CoilAskUserQuestions<String>(
            size: CoilSize.compact,
            questions: [
              CoilQuestion.multiple(
                id: 'checks',
                title: Text('Which checks should run?'),
                keyPosition: CoilQuestionKeyPosition.start,
                options: [
                  CoilQuestionOption(value: 'lint', label: Text('Lint')),
                  CoilQuestionOption(value: 'test', label: Text('Unit tests')),
                  CoilQuestionOption(value: 'golden', label: Text('Goldens')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
