import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

const switchEntry = CatalogEntry(
  slug: 'switch',
  title: 'Switch',
  group: CatalogGroup.leafControls,
  summary: 'Drag, flick or tap; the thumb squishes and stretches.',
  page: SwitchPage.new,
);

class SwitchPage extends StatefulWidget {
  const SwitchPage({super.key});

  @override
  State<SwitchPage> createState() => _SwitchPageState();
}

class _SwitchPageState extends State<SwitchPage> {
  var _wifi = true;
  var _bluetooth = false;
  var _airplane = false;
  var _bare = false;
  var _compact = true;
  var _bouncy = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Switch',
    summary:
        'For settings that apply immediately. Drag the thumb past the edge '
        'to stretch the track; flick it and the projected position decides.',
    children: [
      DemoSection(
        title: 'Labeled rows',
        description: 'The whole row is the target.',
        child: CoilFieldGroup(
          children: [
            CoilSwitch(
              value: _wifi && !_airplane,
              onChanged: _airplane ? null : (v) => setState(() => _wifi = v),
              label: const Text('Wi-Fi'),
            ),
            CoilSwitch(
              value: _bluetooth && !_airplane,
              onChanged: _airplane
                  ? null
                  : (v) => setState(() => _bluetooth = v),
              label: const Text('Bluetooth'),
            ),
            CoilSwitch(
              value: _airplane,
              onChanged: (v) => setState(() => _airplane = v),
              label: const Text('Airplane mode'),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'In a field',
        child: CoilField(
          label: const Text('Auto-save'),
          description: const Text('Saves your draft every 30 seconds.'),
          orientation: CoilFieldOrientation.horizontal,
          child: CoilSwitch(
            value: _bare,
            onChanged: (v) => setState(() => _bare = v),
          ),
        ),
      ),
      DemoSection(
        title: 'Compact and disabled',
        child: DemoWrap(
          spacing: 24,
          children: [
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
        title: 'Per-track motion',
        description:
            'motions: overrides one track. This thumb uses a bouncy 500 ms '
            'spring; squish and tint keep the theme tokens.',
        child: CoilSwitch(
          value: _bouncy,
          onChanged: (v) => setState(() => _bouncy = v),
          motions: {
            CoilSwitchTrack.thumb: const CupertinoMotion(
              bounce: 0.4,
            ),
          },
          label: const Text('Bouncy thumb'),
        ),
      ),
    ],
  );
}
