import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const radioGroupEntry = CatalogEntry(
  slug: 'radio-group',
  title: 'RadioGroup',
  group: CatalogGroup.groupedControls,
  summary: 'A single choice from a short list of rows.',
  page: RadioGroupPage.new,
);

class RadioGroupPage extends StatefulWidget {
  const RadioGroupPage({super.key});

  @override
  State<RadioGroupPage> createState() => _RadioGroupPageState();
}

class _RadioGroupPageState extends State<RadioGroupPage> {
  String? _size = 'm';
  var _compact = false;
  var _unselected = false;
  var _unavailable = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'RadioGroup',
    summary:
        'A radio group lets people pick one option from a short list, and '
        'the selected fill glides from row to row. For more than 7 options, '
        'a Select works better.',
    hero: const _ShippingSpeed(),
    usage: '''
CoilRadioGroup<String>(
  semanticLabel: 'Delivery',
  value: speed,
  onChanged: (value) => setState(() => speed = value),
  options: const [
    CoilOption(value: 'standard', label: Text('Standard')),
    CoilOption(value: 'express', label: Text('Express')),
  ],
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'The selected row takes the group’s single tab stop. The arrow keys '
            'move and select in one step and wrap around at the ends, while '
            'Home and End jump to the first and last row.',
      ),
      CatalogNote(
        'Touch',
        'Pressing a row fills it, and releasing selects it. Disabled rows '
            'are skipped by the arrow keys and by Tab.',
      ),
      CatalogNote(
        'Accessibility',
        'Screen readers announce the rows as mutually exclusive and report '
            'which one is checked, so give the group a semanticLabel or a '
            'field set legend. Nothing is selected until value is non-null.',
      ),
      CatalogNote(
        'Do / Don’t',
        'CoilRadioGroup.custom lays the radios out as choice cards when '
            'rows are too plain. Beyond about 7 options, switch to a Select.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        controls: DemoControls(
          children: [
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
            DemoControl.toggle(
              label: 'Nothing selected',
              value: _unselected,
              onChanged: (v) => setState(() {
                _unselected = v;
                _size = v ? null : 'm';
              }),
            ),
            DemoControl.toggle(
              label: 'Large off',
              value: _unavailable,
              onChanged: (v) => setState(() => _unavailable = v),
            ),
          ],
        ),
        child: CoilFieldSet(
          legend: const Text('T-shirt size'),
          children: [
            CoilRadioGroup<String>(
              semanticLabel: 'T-shirt size',
              size: _compact ? CoilSize.compact : null,
              value: _size,
              onChanged: (value) => setState(() {
                _size = value;
                _unselected = false;
              }),
              options: [
                const CoilOption(value: 's', label: Text('Small')),
                const CoilOption(value: 'm', label: Text('Medium')),
                CoilOption(
                  value: 'l',
                  label: const Text('Large'),
                  enabled: !_unavailable,
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// Checkout: the delivery speed with its price, and a total that follows the
/// selected row.
class _ShippingSpeed extends StatefulWidget {
  const _ShippingSpeed();

  @override
  State<_ShippingSpeed> createState() => _ShippingSpeedState();
}

class _ShippingSpeedState extends State<_ShippingSpeed> {
  var _speed = 'standard';

  static const _subtotal = 64.0;
  static const _speeds = [
    ('standard', 'Standard, 5–7 days', 0.0),
    ('express', 'Express, 2 days', 9.9),
    ('overnight', 'Overnight', 19.0),
  ];

  static String _price(double value) =>
      value == 0 ? 'Free' : '€${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final shipping = _speeds.firstWhere((s) => s.$1 == _speed).$3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoilFieldSet(
          legend: const Text('Delivery'),
          description: const Text('Orders placed before 14:00 ship today.'),
          children: [
            CoilRadioGroup<String>(
              semanticLabel: 'Delivery',
              value: _speed,
              onChanged: (value) => setState(() => _speed = value),
              options: [
                for (final (value, label, price) in _speeds)
                  CoilOption(
                    value: value,
                    label: Row(
                      children: [
                        Expanded(child: Text(label)),
                        Text(_price(price)),
                      ],
                    ),
                    searchText: label,
                    semanticLabel: '$label, ${_price(price)}',
                  ),
                const CoilOption(
                  value: 'pickup',
                  label: Text('Store pickup, unavailable'),
                  enabled: false,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _line(text, 'Subtotal', _price(_subtotal), muted: true),
        const SizedBox(height: 4),
        _line(text, 'Shipping', _price(shipping), muted: true),
        const SizedBox(height: 8),
        _line(text, 'Total', _price(_subtotal + shipping), muted: false),
      ],
    );
  }

  Widget _line(
    CoilTextTheme text,
    String label,
    String value, {
    required bool muted,
  }) {
    final style = muted
        ? text.muted.body
        : text.body.copyWith(fontWeight: text.emphasis);
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
