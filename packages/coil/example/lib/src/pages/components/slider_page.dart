import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
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

enum _Style {
  scrubber('Scrubber', CoilSliderVariant.scrubber),
  pill('Pill', CoilSliderVariant.pill),
  pips('Pips', CoilSliderVariant.pips),
  pillPips('Pill pips', CoilSliderVariant.pillPips);

  const _Style(this.label, this.variant);

  final String label;
  final CoilSliderVariant variant;
}

enum _Display {
  text('Text', CoilSliderValueDisplay.text),
  editable('Editable', CoilSliderValueDisplay.editable),
  tooltip('Tooltip', CoilSliderValueDisplay.tooltip);

  const _Display(this.label, this.display);

  final String label;
  final CoilSliderValueDisplay display;
}

class _SliderPageState extends State<SliderPage> {
  var _style = _Style.scrubber;
  var _display = _Display.text;
  var _compact = false;
  var _disabled = false;
  var _opacity = 60.0;

  var _pips = false;
  var _rangeDisplay = _Display.text;
  var _price = const CoilRangeValues(80, 320);

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Slider',
    summary:
        'Tap to jump, drag to set. A mouse previews the value under the '
        'pointer; a finger gets a bubble above the thumb.',
    hero: const _ClipSettings(),
    usage: r'''
CoilSlider(
  label: const Text('Playback speed'),
  variant: CoilSliderVariant.pillPips,
  steps: const [0.5, 0.75, 1, 1.25, 1.5, 2],
  value: speed,
  valueBuilder: (_, v) => Text('$v×'),
  onChanged: (v) => setState(() => speed = v),
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Arrows step by one step, a step list walks the list. PageUp, '
            'PageDown and Shift+arrow move 10 %; Home and End jump to the '
            'ends. A range is two tab stops.',
      ),
      CatalogNote(
        'Pointer',
        'Hovering shows a preview bar and the value under the pointer. '
            'Click or tap an editable value, or press Enter, to type one; '
            'Enter applies it snapped to a step, Esc cancels.',
      ),
      CatalogNote(
        'Touch',
        'No preview. A bubble sits 8 above the track under your finger '
            'and springs onto the thumb on release. A stepped slider ticks '
            'a haptic per step moved.',
      ),
      CatalogNote(
        'Screen readers',
        'An adjustable slider with increase and decrease actions. Pass '
            'semanticFormatter so it reads "1.25×", not "1.25".',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description:
            'Row styles draw the label and value inside the track; the pill '
            'puts them either side.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Style',
              value: _style,
              values: _Style.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _style = v),
            ),
            DemoControl.choice(
              label: 'Value',
              value: _display,
              values: _Display.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _display = v),
            ),
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
            DemoControl.toggle(
              label: 'Disabled',
              value: _disabled,
              onChanged: (v) => setState(() => _disabled = v),
            ),
          ],
        ),
        child: CoilSlider(
          label: const Text('Opacity'),
          variant: _style.variant,
          valueDisplay: _display.display,
          size: _compact ? CoilSize.compact : null,
          max: 100,
          divisions: 10,
          value: _opacity,
          valueBuilder: (_, v) => Text('${v.round()} %'),
          semanticFormatter: (v) => '${v.round()} percent',
          onChanged: _disabled ? null : (v) => setState(() => _opacity = v),
        ),
      ),
      DemoSection(
        title: 'Range',
        description:
            'Two thumbs that never cross. A tap or a drag moves the nearest '
            'one; Tab moves between them.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Value',
              value: _rangeDisplay,
              values: const [_Display.text, _Display.tooltip],
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _rangeDisplay = v),
            ),
            DemoControl.toggle(
              label: 'Pips',
              value: _pips,
              onChanged: (v) => setState(() => _pips = v),
            ),
          ],
        ),
        child: CoilRangeSlider(
          label: const Text('Price'),
          variant: _pips ? CoilSliderVariant.pillPips : CoilSliderVariant.pill,
          valueDisplay: _rangeDisplay.display,
          max: 500,
          divisions: 50,
          values: _price,
          valueBuilder: (_, v) => Text('€${v.round()}'),
          semanticFormatter: (v) => '${v.round()} euros',
          onChanged: (v) => setState(() => _price = v),
        ),
      ),
    ],
  );
}

/// A clip in a video editor: a step list for the speed, a scrubber for the
/// volume and a range for the trim.
class _ClipSettings extends StatefulWidget {
  const _ClipSettings();

  @override
  State<_ClipSettings> createState() => _ClipSettingsState();
}

class _ClipSettingsState extends State<_ClipSettings> {
  var _speed = 1.25;
  var _volume = 0.8;
  var _trim = const CoilRangeValues(12, 108);

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const _length = 150.0;

  static String _speedName(double v) =>
      '${v == v.roundToDouble() ? v.round() : v}×';

  static String _percent(double v) => '${(v * 100).round()} %';

  static String _time(double v) {
    final seconds = v.round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final gap = CoilTheme.metricsOf(context).gap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Clip settings', style: text.title),
        const SizedBox(height: 4),
        Text(
          'Kept: ${_time(_trim.end - _trim.start)} of '
          '${_time(_length)}.',
          style: text.muted.body,
        ),
        const SizedBox(height: 20),
        Column(
          spacing: gap + 4,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoilSlider(
              label: const Text('Playback speed'),
              variant: CoilSliderVariant.pillPips,
              min: _speeds.first,
              max: _speeds.last,
              steps: _speeds,
              value: _speed,
              valueBuilder: (_, v) => Text(_speedName(v)),
              semanticFormatter: _speedName,
              onChanged: (v) => setState(() => _speed = v),
            ),
            CoilSlider(
              label: const Text('Volume'),
              value: _volume,
              valueBuilder: (_, v) => Text(_percent(v)),
              semanticFormatter: _percent,
              onChanged: (v) => setState(() => _volume = v),
            ),
            CoilRangeSlider(
              label: const Text('Trim'),
              max: _length,
              divisions: _length.round(),
              values: _trim,
              valueBuilder: (_, v) => Text(_time(v)),
              semanticFormatter: _time,
              onChanged: (v) => setState(() => _trim = v),
            ),
          ],
        ),
      ],
    );
  }
}
