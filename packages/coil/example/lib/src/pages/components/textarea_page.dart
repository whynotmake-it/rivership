import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const textareaEntry = CatalogEntry(
  slug: 'textarea',
  title: 'Textarea',
  group: CatalogGroup.leafControls,
  summary: 'CoilInput.multiline: grows from 3 lines to 10, then scrolls.',
  page: TextareaPage.new,
);

class TextareaPage extends StatefulWidget {
  const TextareaPage({super.key});

  @override
  State<TextareaPage> createState() => _TextareaPageState();
}

class _TextareaPageState extends State<TextareaPage> {
  static const _limit = 280;
  var _length = 0;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Textarea',
    summary:
        'Return inserts a newline. Growth is instant: an animated height '
        'jitters while you type.',
    children: [
      DemoSection(
        title: 'Feedback',
        description: 'Type past three lines to watch it grow.',
        child: CoilField(
          label: const Text('What could be better?'),
          description: Text('$_length of $_limit characters'),
          invalid: _length > _limit,
          error: _length > _limit
              ? const Text('Shorten it to 280 characters or fewer')
              : null,
          child: CoilInput.multiline(
            placeholder: const Text(
              'The export dialog forgets my last folder…',
            ),
            invalid: _length > _limit,
            onChanged: (text) => setState(() => _length = text.length),
          ),
        ),
      ),
      const DemoSection(
        title: 'Sizes and states',
        child: DemoColumn(
          children: [
            CoilField(
              label: Text('Two lines minimum, four maximum'),
              child: CoilInput.multiline(
                minLines: 2,
                maxLines: 4,
                placeholder: Text('Short note'),
              ),
            ),
            CoilField(
              label: Text('Compact'),
              child: CoilInput.multiline(
                size: CoilSize.compact,
                placeholder: Text('Comment'),
              ),
            ),
            CoilField(
              label: Text('Disabled'),
              child: CoilInput.multiline(
                enabled: false,
                placeholder: Text('Comments are closed'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
