// Cases are built with a positional "ink" flag for brevity.
// ignore_for_file: avoid_positional_boolean_parameters

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

import 'src/ink_centering.dart';
import 'src/test_icons.dart';

/// Label ink centering for the built-in components. New components add
/// their own `inkCenteringTests` call in their test file.
void main() {
  // Each case builds the control with the label shown or hidden.
  final cases = <String, InkCase>{
    for (final v in CoilButtonVariant.values) ...{
      'button/${v.name}': (ink) => CoilButton(
        onPressed: () {},
        variant: v,
        child: InkLabel(ink, const Text('HEH')),
      ),
      'button/${v.name}+icons': (ink) => CoilButton(
        onPressed: () {},
        variant: v,
        leading: const TestIcon(TestGlyph.plus),
        trailing: const TestIcon(TestGlyph.arrowRight),
        child: InkLabel(ink, const Text('HEH')),
      ),
    },
    'tabs/text': (ink) => CoilTabs(
      tabs: [
        CoilTab(
          value: 0,
          label: InkLabel(ink, const Text('HEH')),
          semanticLabel: 'HEH',
        ),
        CoilTab(
          value: 1,
          label: InkLabel(ink, const Text('HEH')),
          semanticLabel: 'HEH',
        ),
      ],
      value: 0,
      onChanged: (_) {},
    ),
    'tabs/icons': (ink) => CoilTabs(
      tabs: [
        CoilTab(
          value: 0,
          icon: const TestIcon(TestGlyph.home),
          label: InkLabel(ink, const Text('HEH')),
          semanticLabel: 'HEH',
        ),
      ],
      value: 0,
      onChanged: (_) {},
    ),
    'input/text': (ink) => SizedBox(
      width: 200,
      child: CoilInput(
        controller: TextEditingController(text: ink ? 'HEH' : ''),
      ),
    ),
    'input/placeholder': (ink) => SizedBox(
      width: 200,
      child: CoilInput(placeholder: InkLabel(ink, const Text('HEH'))),
    ),
    // With a leading icon, as a search or filter field.
    'input/icon+text': (ink) => SizedBox(
      width: 200,
      child: CoilInput(
        leading: const TestIcon(TestGlyph.search),
        controller: TextEditingController(text: ink ? 'HEH' : ''),
      ),
    ),
    'input/icon+placeholder': (ink) => SizedBox(
      width: 200,
      child: CoilInput(
        leading: const TestIcon(TestGlyph.search),
        placeholder: InkLabel(ink, const Text('HEH')),
      ),
    ),
    'textarea/one-line': (ink) => SizedBox(
      width: 200,
      child: CoilInput.multiline(
        minLines: 1,
        controller: TextEditingController(text: ink ? 'HEH' : ''),
      ),
    ),
    'input-copy/value': (ink) => SizedBox(
      width: 200,
      child: CoilInputCopy(value: ink ? 'HEH' : ''),
    ),
    'input-copy/button': (ink) => SizedBox(
      width: 200,
      child: CoilInputCopy(
        value: '',
        variant: CoilInputCopyVariant.button,
        labels: CoilInputCopyLabels(copy: Text(ink ? 'HEH' : '')),
      ),
    ),
    'checkbox-group/row': (ink) => SizedBox(
      width: 200,
      child: CoilCheckboxGroup(
        values: const {0},
        onChanged: (_) {},
        options: [
          CoilOption(
            value: 0,
            label: InkLabel(ink, const Text('HEH')),
            searchText: 'HEH',
            semanticLabel: 'HEH',
          ),
        ],
      ),
    ),
    'radio-group/row': (ink) => SizedBox(
      width: 200,
      child: CoilRadioGroup(
        value: 0,
        onChanged: (_) {},
        options: [
          CoilOption(
            value: 0,
            label: InkLabel(ink, const Text('HEH')),
            searchText: 'HEH',
            semanticLabel: 'HEH',
          ),
        ],
      ),
    ),
    'badge/solid': (ink) => CoilBadge(child: InkLabel(ink, const Text('HEH'))),
    'badge/dot': (ink) => CoilBadge(
      variant: CoilBadgeVariant.dot,
      child: InkLabel(ink, const Text('HEH')),
    ),
    'toggle-group/item': (ink) => CoilToggleGroup(
      values: const {0},
      onChanged: (_) {},
      options: [
        CoilOption(
          value: 0,
          label: InkLabel(ink, const Text('HEH')),
          searchText: 'HEH',
          semanticLabel: 'HEH',
        ),
      ],
    ),
    'select/trigger': (ink) => SizedBox(
      width: 200,
      child: CoilSelect<int>(
        options: [
          CoilOption(
            value: 0,
            label: InkLabel(ink, const Text('HEH')),
            searchText: 'HEH',
            semanticLabel: 'HEH',
          ),
        ],
        value: 0,
        indicator: const SizedBox.square(dimension: 16),
        onChanged: (_) {},
      ),
    ),
    'slider/label': (ink) => SizedBox(
      width: 240,
      child: CoilSlider(
        value: .4,
        onChanged: (_) {},
        label: InkLabel(ink, const Text('HEH')),
        valueBuilder: (_, _) => const Text('HEH'),
      ),
    ),
    'switch/label': (ink) => CoilSwitch(
      value: true,
      onChanged: (_) {},
      label: InkLabel(ink, const Text('HEH')),
    ),
  };

  inkCenteringTests(cases);
}
