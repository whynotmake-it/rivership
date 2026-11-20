import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
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
  var _expanded = false;
  var _streamExpanded = true;
  var _streamed = 0;
  Timer? _stream;

  @override
  void initState() {
    super.initState();
    _replay();
  }

  @override
  void dispose() {
    _stream?.cancel();
    super.dispose();
  }

  /// Streams the research steps in again, one every 0.9 s.
  void _replay() {
    _stream?.cancel();
    setState(() {
      _streamed = 0;
      _streamExpanded = true;
    });
    _stream = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      setState(() => _streamed++);
      if (_streamed >= _research.length) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'ThinkingSteps',
    summary: 'The indicator cycles words while the answer is on its way.',
    children: [
      const DemoSection(
        title: 'Indicator',
        child: CoilThinkingIndicator(
          words: [Text('Thinking'), Text('Searching'), Text('Reading')],
        ),
      ),
      DemoSection(
        title: 'Steps',
        child: CoilThinkingSteps(
          label: const Text('Thought for 12 seconds'),
          expanded: _expanded,
          onChanged: (v) => setState(() => _expanded = v),
          steps: const [
            CoilThinkingStep(title: Text('Read the spec')),
            CoilThinkingStep(
              title: Text('Compared three options'),
              detail: Text('Kept the one with the fewest moving parts.'),
            ),
            CoilThinkingStep(title: Text('Wrote the answer')),
          ],
        ),
      ),
      DemoSection(
        title: 'Streaming',
        description:
            'Steps grow in as they arrive. A connector runs from each '
            "glyph down beside the step's details to the next step.",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            CoilThinkingSteps(
              label: const Text('Research agent'),
              expanded: _streamExpanded,
              onChanged: (v) => setState(() => _streamExpanded = v),
              steps: _research.take(_streamed).toList(),
            ),
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: _replay,
              child: const Text('Replay'),
            ),
          ],
        ),
      ),
    ],
  );
}
