import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const checkboxGroupEntry = CatalogEntry(
  slug: 'checkbox-group',
  title: 'CheckboxGroup',
  group: CatalogGroup.groupedControls,
  summary: 'Checked rows merge into one block; it splits when you uncheck.',
  page: CheckboxGroupPage.new,
);

class CheckboxGroupPage extends StatefulWidget {
  const CheckboxGroupPage({super.key});

  @override
  State<CheckboxGroupPage> createState() => _CheckboxGroupPageState();
}

class _CheckboxGroupPageState extends State<CheckboxGroupPage> {
  var _days = {'mon', 'tue'};
  var _compact = false;
  var _long = false;
  var _unavailable = false;

  static const _schedule = [
    ('mon', 'Monday', 'Monday: standup and planning'),
    (
      'tue',
      'Tuesday',
      'Tuesday: design review with the whole product team, including the '
          'people joining remotely',
    ),
    ('wed', 'Wednesday', 'Wednesday: focus day'),
    ('thu', 'Thursday', 'Thursday: demos'),
  ];

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'CheckboxGroup',
    summary:
        'Check the row between two runs to watch them merge; uncheck the '
        'middle of a run to watch it split. Each row is a tab stop.',
    hero: const _NotificationChannels(),
    usage: '''
CoilCheckboxGroup<String>(
  values: channels,
  onChanged: (values) => setState(() => channels = values),
  options: const [
    CoilOption(value: 'email', label: Text('Email')),
    CoilOption(value: 'push', label: Text('Push')),
    CoilOption(value: 'slack', label: Text('Slack')),
  ],
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Every row is a tab stop. Up and Down move with wrapping, Home and '
            'End jump, Space or Enter toggles.',
      ),
      CatalogNote(
        'Touch',
        'A press fills the row; selection is the merged blocks. Rows are '
            'full width, so the whole row is the hit target.',
      ),
      CatalogNote(
        'Screen readers',
        'A labeled group of checkable rows. Give the group a semanticLabel '
            'or wrap it in a FieldSet with a legend.',
      ),
      CatalogNote(
        'Do / Don’t',
        'Do use it for 2 to 10 related options. Don’t use it for '
            'mutually exclusive ones; that is a RadioGroup.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description:
            'Labels wrap and grow their row; a disabled row stays out of '
            'the tab order.',
        controls: DemoControls(
          children: [
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
            DemoControl.toggle(
              label: 'Long labels',
              value: _long,
              onChanged: (v) => setState(() => _long = v),
            ),
            DemoControl.toggle(
              label: 'Wednesday off',
              value: _unavailable,
              onChanged: (v) => setState(() => _unavailable = v),
            ),
          ],
        ),
        child: CoilFieldSet(
          legend: const Text('Meeting days'),
          children: [
            CoilCheckboxGroup<String>(
              size: _compact ? CoilSize.compact : null,
              values: _days,
              onChanged: (values) => setState(() => _days = values),
              options: [
                for (final (value, short, long) in _schedule)
                  CoilOption(
                    value: value,
                    label: Text(_long ? long : short),
                    searchText: _long ? long : short,
                    enabled: !(_unavailable && value == 'wed'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// Where a team hears about failed deploys: the merged block follows the
/// checked rows, and a line below says what it adds up to.
class _NotificationChannels extends StatefulWidget {
  const _NotificationChannels();

  @override
  State<_NotificationChannels> createState() => _NotificationChannelsState();
}

class _NotificationChannelsState extends State<_NotificationChannels> {
  var _channels = {'email', 'push'};

  static const _names = {
    'email': 'Email',
    'push': 'Push notifications',
    'sms': 'Text message',
    'slack': 'Slack',
  };

  String get _summary {
    final names = [
      for (final entry in _names.entries)
        if (_channels.contains(entry.key)) entry.value,
    ];
    return switch (names.length) {
      0 => 'You won’t hear about failed deploys.',
      1 => 'Failed deploys notify you by ${names.single}.',
      _ =>
        'Failed deploys notify you by '
            '${names.sublist(0, names.length - 1).join(', ')} and '
            '${names.last}.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final all = _channels.length == _names.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoilFieldSet(
          legend: const Text('Deploy alerts'),
          description: const Text('Choose where we reach you.'),
          children: [
            CoilCheckboxGroup<String>(
              values: _channels,
              onChanged: (values) => setState(() => _channels = values),
              options: [
                for (final entry in _names.entries)
                  CoilOption(
                    value: entry.key,
                    label: Text(entry.value),
                    searchText: entry.value,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text(_summary, style: text.muted.caption)),
            const SizedBox(width: 12),
            CoilButton(
              variant: CoilButtonVariant.ghost,
              size: CoilSize.compact,
              onPressed: () => setState(
                () => _channels = all ? {} : _names.keys.toSet(),
              ),
              child: Text(all ? 'Clear all' : 'Select all'),
            ),
          ],
        ),
      ],
    );
  }
}
