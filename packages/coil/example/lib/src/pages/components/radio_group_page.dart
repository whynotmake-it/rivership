import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
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
  String? _size = 'm';
  var _compact = false;
  var _unselected = false;
  var _unavailable = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'RadioGroup',
    summary:
        'One choice from a short list; the selected fill glides from row to '
        'row. For more than 7 options, use a Select.',
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
        'The selected row is the one tab stop. Arrows move and select, '
            'wrapping at the ends; Home and End jump.',
      ),
      CatalogNote(
        'Touch',
        'A press fills the row and selects on release. Disabled rows are '
            'skipped by arrows and by Tab.',
      ),
      CatalogNote(
        'Accessibility',
        'Rows are mutually exclusive and report checked. Give the group a '
            'semanticLabel or a FieldSet legend. Nothing is selected until '
            'value is non-null.',
      ),
      CatalogNote(
        'Do / Don’t',
        'Do use CoilRadioGroup.custom to lay radios out as choice cards. '
            'Don’t go past 7 options.',
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
