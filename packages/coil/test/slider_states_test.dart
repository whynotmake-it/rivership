import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

void main() {
  testWidgets('slider state sheet', (tester) async {
    final controllers = <WidgetStatesController>[];
    Widget slider(SheetState s, CoilSliderVariant variant) {
      final states = s.controller();
      controllers.add(states);
      return SizedBox(
        width: 220,
        child: CoilSlider(
          value: .5,
          divisions:
              variant == CoilSliderVariant.pips ||
                  variant == CoilSliderVariant.pillPips
              ? 4
              : null,
          variant: variant,
          label: const Text('Level'),
          valueBuilder: (_, v) => Text('${(v * 100).round()}%'),
          statesController: states,
          onChanged: s.isDisabled ? null : (_) {},
        ),
      );
    }

    Widget range(SheetState s) {
      final states = s.controller();
      controllers.add(states);
      return SizedBox(
        width: 220,
        child: CoilRangeSlider(
          values: const CoilRangeValues(.25, .75),
          label: const Text('Level'),
          valueBuilder: (_, v) => Text('${(v * 100).round()}'),
          statesController: states,
          onChanged: s.isDisabled ? null : (_) {},
        ),
      );
    }

    final sheet = await pumpSheet(
      tester,
      ThemedPair(
        title: 'Slider',
        direction: Axis.vertical,
        builder: (context) => StateTable(
          rows: [
            SheetRow('scrubber', (s) => slider(s, CoilSliderVariant.scrubber)),
            SheetRow('pips', (s) => slider(s, CoilSliderVariant.pips)),
            SheetRow('pill', (s) => slider(s, CoilSliderVariant.pill)),
            SheetRow(
              'pill pips',
              (s) => slider(s, CoilSliderVariant.pillPips),
            ),
            SheetRow('range', range),
          ],
        ),
      ),
    );
    addTearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });
    await expectSheetGolden(tester, sheet, 'goldens/slider.png');
  });
}
