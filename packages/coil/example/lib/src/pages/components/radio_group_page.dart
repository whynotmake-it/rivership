import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const radioGroupEntry = CatalogEntry(
  slug: 'radio-group',
  title: 'RadioGroup',
  group: CatalogGroup.groupedControls,
  summary: 'One choice; the selected fill glides between rows.',
  page: RadioGroupPage.new,
);

class RadioGroupPage extends StatefulWidget {
  const RadioGroupPage({super.key});

  @override
  State<RadioGroupPage> createState() => _RadioGroupPageState();
}

class _RadioGroupPageState extends State<RadioGroupPage> {
  var _shipping = 'standard';
  String? _size;
  var _density = 'comfortable';

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'RadioGroup',
    summary:
        'For up to 7 options; use a Select for more. With a keyboard the '
        'selected row is the tab stop, and arrows move and select.',
    children: [
      DemoSection(
        title: 'Shipping',
        child: CoilFieldSet(
          legend: const Text('Shipping speed'),
          children: [
            CoilRadioGroup<String>(
              semanticLabel: 'Shipping speed',
              value: _shipping,
              onChanged: (value) => setState(() => _shipping = value),
              options: const [
                CoilOption(value: 'standard', label: 'Standard, 5–7 days'),
                CoilOption(value: 'express', label: 'Express, 2 days'),
                CoilOption(value: 'overnight', label: 'Overnight'),
                CoilOption(
                  value: 'pickup',
                  label: 'Store pickup (unavailable)',
                  enabled: false,
                ),
              ],
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Nothing selected yet',
        child: CoilRadioGroup<String>(
          semanticLabel: 'Size',
          value: _size,
          onChanged: (value) => setState(() => _size = value),
          options: const [
            CoilOption(value: 's', label: 'Small'),
            CoilOption(value: 'm', label: 'Medium'),
            CoilOption(value: 'l', label: 'Large'),
          ],
        ),
      ),
      DemoSection(
        title: 'Compact',
        child: CoilRadioGroup<String>(
          semanticLabel: 'Density',
          size: CoilSize.compact,
          value: _density,
          onChanged: (value) => setState(() => _density = value),
          options: const [
            CoilOption(value: 'comfortable', label: 'Comfortable'),
            CoilOption(value: 'compact', label: 'Compact'),
          ],
        ),
      ),
    ],
  );
}
