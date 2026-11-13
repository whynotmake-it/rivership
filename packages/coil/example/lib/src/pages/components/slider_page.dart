import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const sliderEntry = CatalogEntry(
  slug: 'slider',
  title: 'Slider',
  group: CatalogGroup.groupedControls,
  summary: 'One value: scrubber, pips or pill. Drags never coast.',
  page: SliderPage.new,
);

class SliderPage extends StatefulWidget {
  const SliderPage({super.key});

  @override
  State<SliderPage> createState() => _SliderPageState();
}

class _SliderPageState extends State<SliderPage> {
  var _volume = 0.6;
  var _quality = 3.0;
  var _brightness = 0.4;
  var _price = 120.0;
  var _compact = 0.5;

  static String _percent(double v) => '${(v * 100).round()} %';

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Slider',
    summary:
        'Tap to jump, drag to set. With a mouse, hovering previews the value '
        'under the pointer; with a finger, a bubble shows the value above '
        'the thumb. Arrows step, Shift+arrow steps 10 %.',
    children: [
      DemoSection(
        title: 'Scrubber',
        description: 'A full-width row with the label and value inside.',
        child: DemoColumn(
          children: [
            CoilSlider(
              label: const Text('Volume'),
              value: _volume,
              valueFormatter: _percent,
              onChanged: (v) => setState(() => _volume = v),
            ),
            CoilSlider(
              label: const Text('Price limit'),
              max: 500,
              divisions: 50,
              value: _price,
              valueFormatter: (v) => '€${v.round()}',
              onChanged: (v) => setState(() => _price = v),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Pips',
        description: 'A dot at every step.',
        child: CoilSlider(
          label: const Text('Quality'),
          variant: CoilSliderVariant.pips,
          min: 1,
          max: 5,
          divisions: 4,
          value: _quality,
          valueFormatter: (v) =>
              const ['Draft', 'Low', 'Medium', 'High', 'Best'][v.round() - 1],
          onChanged: (v) => setState(() => _quality = v),
        ),
      ),
      DemoSection(
        title: 'Pill',
        description: 'A thin track with a knob, between label and value.',
        child: CoilSlider(
          label: const Text('Brightness'),
          variant: CoilSliderVariant.pill,
          value: _brightness,
          valueFormatter: _percent,
          onChanged: (v) => setState(() => _brightness = v),
        ),
      ),
      DemoSection(
        title: 'Compact and disabled',
        child: DemoColumn(
          children: [
            CoilSlider(
              label: const Text('Zoom'),
              size: CoilSize.compact,
              value: _compact,
              valueFormatter: _percent,
              onChanged: (v) => setState(() => _compact = v),
            ),
            const CoilSlider(
              label: Text('Locked'),
              value: 0.3,
              onChanged: null,
            ),
          ],
        ),
      ),
    ],
  );
}
