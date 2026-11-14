import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
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
  String? _summary;

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  String _describe(Map<Object, CoilAnswer<String>> answers) => [
    for (final MapEntry(:key, :value) in answers.entries)
      '$key: ${value.skipped ? 'skipped' : _picks(value)}',
  ].join(' · ');

  static String _picks(CoilAnswer<String> answer) => [
    ...answer.values,
    if (answer.text.isNotEmpty) '"${answer.text}"',
  ].join(', ');

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'AskUserQuestions',
    summary:
        'Single, multiple and typed answers, with Back and Skip. On pointer '
        'the number keys pick rows; touch hides them and uses 44 pt rows.',
    children: [
      DemoSection(
        title: 'Four questions',
        description:
            'Picking a single option moves on. Keys: 1–9, Up and Down, '
            'Enter, Escape to go back, Ctrl/⌘+Enter to continue.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            CoilAskUserQuestions<String>(
              questions: _questions,
              controller: _flow,
              onCompleted: (answers) =>
                  setState(() => _summary = _describe(answers)),
            ),
            if (_summary case final summary?) ...[
              Text(summary),
              CoilButton(
                variant: CoilButtonVariant.secondary,
                size: CoilSize.compact,
                onPressed: () => setState(() {
                  _summary = null;
                  _flow.reset();
                }),
                child: const Text('Start over'),
              ),
            ],
          ],
        ),
      ),
      const DemoSection(
        title: 'Keys at the start, compact',
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
