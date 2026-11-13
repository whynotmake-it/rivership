import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const thinkingStepsEntry = CatalogEntry(
  slug: 'thinking-steps',
  title: 'ThinkingSteps',
  group: CatalogGroup.layoutAndDisplay,
  summary: "An assistant's reasoning, folded into a summary line.",
  page: ThinkingStepsPage.new,
);

class ThinkingStepsPage extends StatefulWidget {
  const ThinkingStepsPage({super.key});

  @override
  State<ThinkingStepsPage> createState() => _ThinkingStepsPageState();
}

class _ThinkingStepsPageState extends State<ThinkingStepsPage> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'ThinkingSteps',
    summary: 'The indicator cycles words while the answer is on its way.',
    children: [
      const DemoSection(
        title: 'Indicator',
        child: CoilThinkingIndicator(
          words: ['Thinking', 'Searching', 'Reading'],
        ),
      ),
      DemoSection(
        title: 'Steps',
        child: CoilThinkingSteps(
          label: const Text('Thought for 12 seconds'),
          expanded: _expanded,
          onChanged: (v) => setState(() => _expanded = v),
          steps: const [
            CoilThinkingStep(title: 'Read the spec'),
            CoilThinkingStep(
              title: 'Compared three options',
              detail: 'Kept the one with the fewest moving parts.',
            ),
            CoilThinkingStep(title: 'Wrote the answer'),
          ],
        ),
      ),
    ],
  );
}
