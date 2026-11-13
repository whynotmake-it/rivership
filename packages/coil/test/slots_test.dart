import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => CoilTheme(
    data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
    child: Center(child: child),
  ),
);

/// Records the IconTheme it is given.
class _Probe extends StatelessWidget {
  const _Probe(this.onTheme);

  final ValueChanged<IconThemeData> onTheme;

  @override
  Widget build(BuildContext context) {
    onTheme(IconTheme.of(context));
    return const SizedBox.square(dimension: 16);
  }
}

void main() {
  testWidgets('icon slots get size, color and a hover weight via IconTheme', (
    tester,
  ) async {
    late IconThemeData seen;
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(
      _app(
        CoilButton(
          onPressed: () {},
          statesController: states,
          leading: _Probe((t) => seen = t),
          child: const Text('Go'),
        ),
      ),
    );
    expect(seen.size, 16);
    expect(seen.weight, CoilIconWeight.rest);
    expect(seen.color, CoilColors.light.background);

    states.update(WidgetState.hovered, true);
    await settle(tester);
    expect(seen.weight, moreOrLessEquals(CoilIconWeight.emphasis));
  });

  testWidgets('loadingIndicator replaces the spinner', (tester) async {
    await tester.pumpWidget(
      _app(
        CoilButton(
          onPressed: () {},
          loading: true,
          loadingIndicator: const Text('…', key: ValueKey('mine')),
          child: const Text('Save'),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('mine')), findsOneWidget);
  });

  testWidgets('glyphBuilder replaces the checkbox tick', (tester) async {
    final calls = <(CoilCheckboxGlyph, double)>[];
    await tester.pumpWidget(
      _app(
        CoilCheckbox(
          value: true,
          onChanged: (_) {},
          glyphBuilder: (context, glyph, progress, color, size) {
            calls.add((glyph, progress));
            return SizedBox.square(dimension: size);
          },
        ),
      ),
    );
    expect(calls.last, (CoilCheckboxGlyph.check, 1.0));
  });
}
