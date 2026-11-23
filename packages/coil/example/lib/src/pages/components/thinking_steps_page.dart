import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const thinkingStepsEntry = CatalogEntry(
  slug: 'thinking-steps',
  title: 'ThinkingSteps',
  group: CatalogGroup.layoutAndDisplay,
  summary: "An assistant's reasoning, folded into a summary line.",
  page: ThinkingStepsPage.new,
);

/// A research agent's steps, streamed in one by one by the demo.
const _research = [
  CoilThinkingStep(
    leading: CatalogIcon(Glyph.search),
    title: Text('Searching for profiles'),
    sources: [Text('x.com'), Text('instagram.com'), Text('github.com')],
  ),
  CoilThinkingStep(
    leading: CatalogIcon(Glyph.user),
    title: Text('Found a profile photo'),
    detail: Text('The newest one, from x.com.'),
  ),
  CoilThinkingStep(
    leading: CatalogIcon(Glyph.globe),
    title: Text('Reading the portfolio'),
  ),
  CoilThinkingStep(
    leading: CatalogIcon(Glyph.brain),
    title: Text('Analyzing results'),
    detail: Text('Compiling findings into a summary.'),
  ),
  CoilThinkingStep(
    leading: CatalogIcon(Glyph.sparkles),
    title: Text('Research complete'),
  ),
];

class ThinkingStepsPage extends StatefulWidget {
  const ThinkingStepsPage({super.key});

  @override
  State<ThinkingStepsPage> createState() => _ThinkingStepsPageState();
}

class _ThinkingStepsPageState extends State<ThinkingStepsPage> {
  var _details = true;
  var _sources = true;
  var _icons = true;
  var _expanded = true;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'ThinkingSteps',
    summary:
        'What an assistant did on the way to its answer, folded under a '
        'summary line. Steps grow in as they arrive.',
    hero: const _AgentRun(),
    usage: '''
CoilThinkingSteps(
  label: Text(done ? 'Thought for 4 seconds' : 'Researching'),
  expanded: expanded,
  onChanged: (open) => setState(() => expanded = open),
  steps: [
    for (final step in streamed)
      CoilThinkingStep(
        leading: Icon(step.icon),
        title: Text(step.title),
        sources: [for (final site in step.sites) Text(site)],
      ),
  ],
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'The trigger is a tab stop; Enter or Space opens and closes the '
            'list.',
      ),
      CatalogNote(
        'Motion',
        'The list opens on standard. A step that arrives later grows on '
            'gentle and fades in 80 ms after; source badges pop in from '
            '0.85 with a blur.',
      ),
      CatalogNote(
        "Do / Don't",
        'Append steps to the list; steps present at the first build show '
            'at once. A one-line step draws no connector, so details and '
            'sources are what link steps.',
      ),
      CatalogNote(
        'Screen readers',
        'The indicator is a polite live region that announces a word at '
            'most once every 4 seconds.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Steps',
        description:
            'A connector runs from each glyph down beside the details to '
            'the next step. Without a glyph the step gets a small dot.',
        controls: DemoControls(
          children: [
            DemoControl.toggle(
              label: 'Details',
              value: _details,
              onChanged: (v) => setState(() => _details = v),
            ),
            DemoControl.toggle(
              label: 'Sources',
              value: _sources,
              onChanged: (v) => setState(() => _sources = v),
            ),
            DemoControl.toggle(
              label: 'Glyphs',
              value: _icons,
              onChanged: (v) => setState(() => _icons = v),
            ),
          ],
        ),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: CoilThinkingSteps(
            label: const Text('Thought for 4 seconds'),
            expanded: _expanded,
            onChanged: (v) => setState(() => _expanded = v),
            steps: [
              for (final step in _research)
                CoilThinkingStep(
                  leading: _icons ? step.leading : null,
                  title: step.title,
                  detail: _details ? step.detail : null,
                  sources: _sources ? step.sources : const [],
                ),
            ],
          ),
        ),
      ),
      const DemoSection(
        title: 'Indicator',
        description:
            'Shown while the answer is on its way. The word cycles every 4 '
            'seconds, and the row is as wide as the longest word.',
        child: DemoWrap(
          spacing: 32,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            Labeled(
              'With a glyph',
              child: CoilThinkingIndicator(
                leading: CatalogIcon(Glyph.sparkles),
                words: [Text('Thinking'), Text('Searching'), Text('Reading')],
              ),
            ),
            Labeled(
              'Words only',
              child: CoilThinkingIndicator(
                words: [Text('Thinking'), Text('Writing')],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// An agent run: steps stream in a second apart, the indicator cycles while
/// it works, and Replay starts it over.
class _AgentRun extends StatefulWidget {
  const _AgentRun();

  @override
  State<_AgentRun> createState() => _AgentRunState();
}

class _AgentRunState extends State<_AgentRun> {
  static const _interval = Duration(seconds: 1);

  var _expanded = true;
  var _streamed = 0;
  Timer? _timer;

  bool get _done => _streamed >= _research.length;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _run() {
    _timer?.cancel();
    setState(() {
      _streamed = 1;
      _expanded = true;
    });
    _timer = Timer.periodic(_interval, (timer) {
      setState(() => _streamed++);
      if (_done) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Who is Ada Lovelace?', style: text.title),
            ),
            CoilButton(
              variant: CoilButtonVariant.ghost,
              size: CoilSize.compact,
              leading: const CatalogIcon(Glyph.rotate),
              onPressed: _run,
              child: const Text('Replay'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoilThinkingSteps(
            label: Text(
              _done ? 'Thought for ${_research.length - 1} seconds' : 'Working',
            ),
            expanded: _expanded,
            onChanged: (v) => setState(() => _expanded = v),
            steps: _research.take(_streamed).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: CoilTheme.metricsOf(context).controlPaddingX,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: _done
                ? Text(
                    'Ada Lovelace wrote the first published program, for the '
                    'Analytical Engine.',
                    style: text.body,
                  )
                : const CoilThinkingIndicator(
                    leading: CatalogIcon(Glyph.sparkles),
                    words: [
                      Text('Thinking'),
                      Text('Searching'),
                      Text('Reading'),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
