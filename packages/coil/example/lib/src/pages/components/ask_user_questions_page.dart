import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const askUserQuestionsEntry = CatalogEntry(
  slug: 'ask-user-questions',
  title: 'AskUserQuestions',
  group: CatalogGroup.shellAndComposites,
  summary: "An assistant's questions, one at a time.",
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
          'An agent asks before it starts: one question at a time, with Back '
          'and Skip. On a pointer the number keys pick rows; touch hides '
          'them and uses 44 pt rows.',
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
          '1 to 9 pick rows, Up and Down move, Enter picks, Escape goes '
              'back and Ctrl or ⌘ with Enter continues.',
        ),
        CatalogNote(
          'Touch',
          'No number keys or submit arrow. Rows are 44 tall and show the '
              'press fill; a tap never pulls focus, so the keyboard stays '
              'down until a field is tapped.',
        ),
        CatalogNote(
          'Motion',
          'Between questions the card’s height springs on standard while '
              'the old question fades out and the new one fades in.',
        ),
        CatalogNote(
          'Accessibility',
          'A rejected typed answer shows its message under the field in a '
              'live region and the field turns invalid.',
        ),
      ],
      children: const [
        DemoSection(
          title: 'Compact, keys at the start',
          description:
              'One step denser for a narrow panel; the number sits before '
              'the label.',
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
