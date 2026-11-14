// Changing the size tier while the app runs (a window resize, a tablet
// docking a keyboard) rebuilds every component on the new tier's sizes.
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/test_icons.dart';

const _options = [
  CoilOption(value: 0, label: Text('One'), searchText: 'One'),
  CoilOption(value: 1, label: Text('Two'), searchText: 'Two'),
];

Widget _everything() => SizedBox(
  width: 360,
  child: SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoilButton(
          onPressed: () {},
          leading: const TestIcon(TestGlyph.plus),
          child: const Text('Save'),
        ),
        CoilButton.icon(
          onPressed: () {},
          semanticLabel: 'Add',
          icon: const TestIcon(TestGlyph.plus),
        ),
        CoilButton(onPressed: () {}, loading: true, child: const Text('Busy')),
        CoilCheckbox(value: true, onChanged: (_) {}),
        CoilSwitch(
          value: true,
          onChanged: (_) {},
          label: const Text('Wi-Fi'),
        ),
        CoilTabs<int>(
          tabs: const [
            CoilTab(value: 0, label: Text('One')),
            CoilTab(value: 1, label: Text('Two')),
          ],
          value: 0,
          onChanged: (_) {},
        ),
        const CoilInput(placeholder: Text('Search')),
        const CoilInputCopy(value: 'abc'),
        CoilSelect<int>(options: _options, value: 0, onChanged: (_) {}),
        CoilCheckboxGroup<int>(
          options: _options,
          values: const {0},
          onChanged: (_) {},
        ),
        CoilRadioGroup<int>(
          options: _options,
          value: 0,
          onChanged: (_) {},
        ),
        CoilToggleGroup<int>(
          options: _options,
          values: const {0},
          onChanged: (_) {},
        ),
        CoilSlider(value: 0.5, onChanged: (_) {}),
        const CoilBadge(child: Text('New')),
        const CoilField(label: Text('Name'), child: CoilInput()),
      ],
    ),
  ),
);

/// Heights of the controls whose size follows the tier.
List<double> _heights(WidgetTester tester) => [
  for (final finder in [
    find.byType(CoilButton).first,
    find.byType(CoilSwitch),
    find.byType(CoilInput).first,
    find.byType(CoilSelect<int>),
  ])
    tester.getSize(finder).height,
];

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required CoilTier tier,
    required bool scope,
  }) => tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, _) => CoilTheme(
        data: CoilThemeData.light.copyWith(tier: scope ? null : tier),
        child: scope
            ? CoilAdaptiveScope(tier: tier, child: _everything())
            : _everything(),
      ),
    ),
  );

  for (final scope in [false, true]) {
    testWidgets(
      'switching the tier at runtime (${scope ? 'adaptive scope' : 'theme'}) '
      'rebuilds every component on the new sizes',
      (tester) async {
        await pump(tester, tier: CoilTier.pointer, scope: scope);
        await tester.pump(const Duration(milliseconds: 500));
        final pointer = _heights(tester);

        await pump(tester, tier: CoilTier.touch, scope: scope);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 500));
        final touch = _heights(tester);
        for (final (i, height) in touch.indexed) {
          expect(
            height,
            greaterThanOrEqualTo(pointer[i]),
            reason: 'control $i is at least as tall on touch',
          );
        }
        expect(touch.first, greaterThan(pointer.first));

        await pump(tester, tier: CoilTier.pointer, scope: scope);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        expect(_heights(tester), pointer, reason: 'and back again');
      },
    );
  }
}
