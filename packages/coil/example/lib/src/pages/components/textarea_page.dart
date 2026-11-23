import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const textareaEntry = CatalogEntry(
  slug: 'textarea',
  title: 'Textarea',
  group: CatalogGroup.leafControls,
  summary:
      'A multi-line input that grows from three lines to ten, then '
      'scrolls.',
  page: TextareaPage.new,
);

class TextareaPage extends StatefulWidget {
  const TextareaPage({super.key});

  @override
  State<TextareaPage> createState() => _TextareaPageState();
}

class _TextareaPageState extends State<TextareaPage> {
  var _minLines = 3;
  var _maxLines = 10;
  var _compact = false;
  var _disabled = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Textarea',
    summary:
        'CoilInput.multiline is the same input for more than one line. It '
        'starts three lines tall and grows as you type, up to ten lines, '
        'after which the text scrolls inside it.',
    hero: const _FeedbackForm(),
    usage: r'''
CoilField(
  label: const Text('What could be better?'),
  description: Text('$length of $limit'),
  invalid: length > limit,
  child: CoilInput.multiline(
    controller: controller,
    invalid: length > limit,
  ),
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Return inserts a newline, so the surrounding form decides which '
            'key sends, as a message composer does.',
      ),
      CatalogNote(
        'Motion',
        'The height changes instantly, because animating it would make the '
            'text jitter while you type, but the colors still fade.',
      ),
      CatalogNote(
        'Touch',
        'Past maxLines (10 by default) the text scrolls inside the input '
            'instead of growing the page, and the input scrolls itself clear '
            'of the keyboard.',
      ),
      CatalogNote(
        'Accessibility',
        'Pair it with a field label rather than relying on a placeholder '
            'alone. The count and the error belong to the field, so a screen '
            'reader announces them with the input.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description:
            'Type past the last line to watch the input grow, and past the '
            'maximum to see it scroll.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Min lines',
              value: _minLines,
              values: const [1, 2, 3],
              labelOf: (v) => '$v',
              onChanged: (v) => setState(() => _minLines = v),
            ),
            DemoControl.choice(
              label: 'Max lines',
              value: _maxLines,
              values: const [4, 6, 10],
              labelOf: (v) => '$v',
              onChanged: (v) => setState(() => _maxLines = v),
            ),
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
            DemoControl.toggle(
              label: 'Disabled',
              value: _disabled,
              onChanged: (v) => setState(() => _disabled = v),
            ),
          ],
        ),
        child: CoilField(
          label: const Text('Notes'),
          child: CoilInput.multiline(
            minLines: _minLines,
            maxLines: _maxLines,
            size: _compact ? CoilSize.compact : null,
            enabled: !_disabled,
            placeholder: const Text('Anything the team should know'),
          ),
        ),
      ),
    ],
  );
}

/// A feedback form with a live character count and a limit: past it the
/// field turns invalid and Send waits.
class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm();

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  static const _limit = 280;

  final _controller = TextEditingController();
  var _sent = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed() => setState(() => _sent = false);

  void _send() {
    _controller.removeListener(_changed);
    _controller.clear();
    _controller.addListener(_changed);
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final length = _controller.text.characters.length;
    final over = length > _limit;
    final blank = _controller.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Send feedback', style: text.title),
        const SizedBox(height: 16),
        CoilField(
          label: const Text('What could be better?'),
          description: Text('$length of $_limit characters'),
          invalid: over,
          error: over ? Text('Shorten it by ${length - _limit}') : null,
          child: CoilInput.multiline(
            controller: _controller,
            invalid: over,
            placeholder: const Text('The export dialog forgets my folder'),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            CoilButton(
              onPressed: blank || over ? null : _send,
              child: const Text('Send'),
            ),
            const SizedBox(width: 12),
            if (_sent)
              Expanded(
                child: Text(
                  'Thanks, we read every one.',
                  style: text.muted.caption,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
