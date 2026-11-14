import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const sliderEntry = CatalogEntry(
  slug: 'slider',
  title: 'Slider',
  group: CatalogGroup.groupedControls,
  summary:
      'One value or a range: scrubber, pips or pill, steps, typed values '
      'and tooltips. Drags never coast.',
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
  var _range = const CoilRangeValues(80, 320);
  var _rating = 0.7;
  var _opacity = 0.75;
  var _tooltip = 0.3;
  var _tooltipRange = const CoilRangeValues(.2, .6);

  static const _ratings = [0.1, 0.5, 0.7, 1.1, 1.3];

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
        title: 'Range',
        description:
            'Two thumbs that never cross. A tap or a drag moves the nearest '
            'one; Tab moves between them.',
        child: CoilRangeSlider(
          label: const Text('Price'),
          max: 500,
          divisions: 50,
          values: _range,
          valueFormatter: (v) => '€${v.round()}',
          onChanged: (v) => setState(() => _range = v),
        ),
      ),
      DemoSection(
        title: 'Step list',
        description: 'Any allowed values, not only even steps.',
        child: CoilSlider(
          label: const Text('Rating'),
          variant: CoilSliderVariant.pips,
          min: _ratings.first,
          max: _ratings.last,
          steps: _ratings,
          value: _rating,
          valueFormatter: (v) => '$v A',
          onChanged: (v) => setState(() => _rating = v),
        ),
      ),
      DemoSection(
        title: 'Editable value',
        description:
            'Click or tap the value, or press Enter, to type one. Enter '
            'applies it, snapped to a step; Esc cancels.',
        child: CoilSlider(
          label: const Text('Opacity'),
          variant: CoilSliderVariant.pill,
          valueDisplay: CoilSliderValueDisplay.editable,
          divisions: 100,
          value: _opacity,
          onChanged: (v) => setState(() => _opacity = v),
        ),
      ),
      DemoSection(
        title: 'Tooltip',
        description:
            'The value rides the thumb while the slider is hovered, pressed '
            'or focused with the keyboard.',
        child: DemoColumn(
          children: [
            CoilSlider(
              label: const Text('Blur'),
              variant: CoilSliderVariant.pill,
              valueDisplay: CoilSliderValueDisplay.tooltip,
              value: _tooltip,
              valueFormatter: _percent,
              onChanged: (v) => setState(() => _tooltip = v),
            ),
            CoilRangeSlider(
              label: const Text('Window'),
              valueDisplay: CoilSliderValueDisplay.tooltip,
              values: _tooltipRange,
              valueFormatter: _percent,
              onChanged: (v) => setState(() => _tooltipRange = v),
            ),
          ],
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
