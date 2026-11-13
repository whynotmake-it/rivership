import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';

const toggleGroupEntry = CatalogEntry(
  slug: 'toggle-group',
  title: 'ToggleGroup',
  group: CatalogGroup.groupedControls,
  summary: 'A segmented row for multi-select formatting.',
  page: ToggleGroupPage.new,
);

class ToggleGroupPage extends StatefulWidget {
  const ToggleGroupPage({super.key});

  @override
  State<ToggleGroupPage> createState() => _ToggleGroupPageState();
}

class _ToggleGroupPageState extends State<ToggleGroupPage> {
  var _format = {'bold'};
  var _channels = {'email', 'push'};

  @override
  Widget build(BuildContext context) {
    final style = TypeRole.subtitle.styleOf(
      context,
      weight: _format.contains('bold') ? CoilWeight.bold : CoilWeight.normal,
    );
    return CatalogPage(
      title: 'ToggleGroup',
      summary:
          'Adjacent selected segments merge. For a single choice, use Tabs '
          'or a RadioGroup instead. Left and Right move, Space toggles.',
      children: [
        DemoSection(
          title: 'Formatting',
          child: DemoColumn(
            children: [
              CoilToggleGroup<String>(
                values: _format,
                onChanged: (values) => setState(() => _format = values),
                options: const [
                  CoilOption(
                    value: 'bold',
                    label: 'Bold',
                    child: CatalogIcon(Glyph.bold, semanticLabel: 'Bold'),
                  ),
                  CoilOption(
                    value: 'italic',
                    label: 'Italic',
                    child: CatalogIcon(Glyph.italic, semanticLabel: 'Italic'),
                  ),
                  CoilOption(
                    value: 'underline',
                    label: 'Underline',
                    child: CatalogIcon(
                      Glyph.underline,
                      semanticLabel: 'Underline',
                    ),
                  ),
                  CoilOption(
                    value: 'strike',
                    label: 'Strikethrough',
                    child: CatalogIcon(
                      Glyph.strikethrough,
                      semanticLabel: 'Strikethrough',
                    ),
                  ),
                ],
              ),
              Text(
                'The quick brown fox',
                style: style.copyWith(
                  fontStyle: _format.contains('italic')
                      ? FontStyle.italic
                      : FontStyle.normal,
                  decoration: TextDecoration.combine([
                    if (_format.contains('underline')) TextDecoration.underline,
                    if (_format.contains('strike')) TextDecoration.lineThrough,
                  ]),
                ),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'Notify me by',
          child: CoilToggleGroup<String>(
            values: _channels,
            onChanged: (values) => setState(() => _channels = values),
            options: const [
              CoilOption(value: 'email', label: 'Email'),
              CoilOption(value: 'push', label: 'Push'),
              CoilOption(value: 'sms', label: 'SMS'),
            ],
          ),
        ),
        DemoSection(
          title: 'Compact',
          child: CoilToggleGroup<String>(
            size: CoilSize.compact,
            values: _format,
            onChanged: (values) => setState(() => _format = values),
            options: const [
              CoilOption(value: 'bold', label: 'Bold'),
              CoilOption(value: 'italic', label: 'Italic'),
              CoilOption(value: 'underline', label: 'Underline'),
            ],
          ),
        ),
      ],
    );
  }
}
