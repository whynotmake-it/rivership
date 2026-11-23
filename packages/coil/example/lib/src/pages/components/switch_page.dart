import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

const switchEntry = CatalogEntry(
  slug: 'switch',
  title: 'Switch',
  group: CatalogGroup.leafControls,
  summary: 'A setting that applies as soon as you flip it, by tap or by drag.',
  page: SwitchPage.new,
);

class SwitchPage extends StatefulWidget {
  const SwitchPage({super.key});

  @override
  State<SwitchPage> createState() => _SwitchPageState();
}

class _SwitchPageState extends State<SwitchPage> {
  var _regular = true;
  var _compact = true;
  var _bouncy = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Switch',
    summary:
        'A switch is for a setting that applies the moment you flip it. You '
        'can tap it, or drag the thumb and let go, and the side it is closest '
        'to decides the result.',
    hero: const _NotificationSettings(),
    usage: '''
CoilField(
  label: const Text('Mentions'),
  orientation: CoilFieldOrientation.horizontal,
  child: CoilSwitch(
    value: mentions,
    onChanged: (v) => setState(() => mentions = v),
  ),
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Space and Enter both toggle the switch, and the focus ring sits '
            '2 px outside the track.',
      ),
      CatalogNote(
        'Pointer',
        'Hovering grows the thumb by 2 and pressing widens it, and dragging '
            'past either end stretches the track a little.',
      ),
      CatalogNote(
        'Touch',
        'The track is larger on touch, and a switch with a label takes the '
            'whole row as its target. On iOS a drag that flips the switch '
            'also plays a selection click.',
      ),
      CatalogNote(
        'Screen readers',
        'A switch is read as a toggle together with its label, so give it a '
            'semanticLabel when it has no visible label.',
      ),
      CatalogNote(
        'Do / Don’t',
        'A choice that is only saved when the form is submitted is better '
            'as a checkbox, because a switch implies the change has already '
            'taken effect.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Sizes and states',
        child: DemoWrap(
          spacing: 24,
          children: [
            Labeled(
              'Regular',
              child: CoilSwitch(
                value: _regular,
                semanticLabel: 'Regular',
                onChanged: (v) => setState(() => _regular = v),
              ),
            ),
            Labeled(
              'Compact',
              child: CoilSwitch(
                size: CoilSize.compact,
                value: _compact,
                semanticLabel: 'Compact',
                onChanged: (v) => setState(() => _compact = v),
              ),
            ),
            const Labeled(
              'Disabled off',
              child: CoilSwitch(
                value: false,
                onChanged: null,
                semanticLabel: 'Disabled off',
              ),
            ),
            const Labeled(
              'Disabled on',
              child: CoilSwitch(
                value: true,
                onChanged: null,
                semanticLabel: 'Disabled on',
              ),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Custom motion',
        description:
            'The thumb, the squish and the tint each follow a spring from '
            'the theme, and motions replaces any of them. Here the thumb '
            'gets a bounce of 0.4.',
        child: CoilSwitch(
          value: _bouncy,
          onChanged: (v) => setState(() => _bouncy = v),
          motions: {
            CoilSwitchTrack.thumb: const CupertinoMotion(bounce: 0.4),
          },
          label: const Text('Bouncy thumb'),
        ),
      ),
    ],
  );
}

/// Notification settings: each switch applies at once, and the line below
/// says what the settings now do.
class _NotificationSettings extends StatefulWidget {
  const _NotificationSettings();

  @override
  State<_NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<_NotificationSettings> {
  var _enabled = true;
  var _mentions = true;
  var _replies = true;
  var _digest = false;
  var _sound = true;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final kinds = [
      if (_mentions) 'mentions',
      if (_replies) 'replies',
      if (_digest) 'the weekly digest',
    ];
    final summary = !_enabled
        ? 'Notifications are off, so nothing will reach you.'
        : kinds.isEmpty
        ? 'Notifications are on, but every kind is off.'
        : 'You will hear about ${_join(kinds)}'
              '${_sound ? ', with a sound' : ', silently'}.';
    Widget row(
      String label,
      String description, {
      required bool value,
      required ValueChanged<bool> onChanged,
      bool nested = false,
    }) => CoilField(
      label: Text(label),
      description: Text(description),
      orientation: CoilFieldOrientation.horizontal,
      child: CoilSwitch(
        value: value,
        onChanged: nested && !_enabled ? null : onChanged,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Notifications', style: text.title),
        const SizedBox(height: 16),
        DemoColumn(
          children: [
            row(
              'Allow notifications',
              'Turns every kind of notification on or off at once.',
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            row(
              'Mentions',
              'When someone mentions you.',
              value: _enabled && _mentions,
              onChanged: (v) => setState(() => _mentions = v),
              nested: true,
            ),
            row(
              'Replies',
              'When someone answers your thread.',
              value: _enabled && _replies,
              onChanged: (v) => setState(() => _replies = v),
              nested: true,
            ),
            row(
              'Weekly digest',
              'A Monday summary by email.',
              value: _enabled && _digest,
              onChanged: (v) => setState(() => _digest = v),
              nested: true,
            ),
            row(
              'Play a sound',
              'A short chime for each notification.',
              value: _enabled && _sound,
              onChanged: (v) => setState(() => _sound = v),
              nested: true,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(summary, style: text.muted.caption),
      ],
    );
  }

  static String _join(List<String> items) => items.length == 1
      ? items.single
      : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}
