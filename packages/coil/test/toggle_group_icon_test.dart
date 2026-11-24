import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/test_icons.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'a segment shows its icon before its label and tracks the selection '
      '($direction)',
      (tester) async {
        final values = ValueNotifier<Set<String>>({'a'});
        addTearDown(values.dispose);
        await tester.pumpWidget(
          Directionality(
            textDirection: direction,
            child: CoilTheme(
              data: const CoilThemeData(tier: CoilTier.pointer),
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: values,
                  builder: (context, selected, _) => CoilToggleGroup<String>(
                    values: selected,
                    onChanged: (next) => values.value = next,
                    options: const [
                      CoilOption(
                        value: 'a',
                        icon: TestIcon(TestGlyph.heart, key: Key('icon-a')),
                        label: Text('Alpha'),
                      ),
                      CoilOption(
                        value: 'b',
                        icon: TestIcon(TestGlyph.home, key: Key('icon-b')),
                        label: Text('Beta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final ltr = direction == TextDirection.ltr;
        for (final (name, text) in [('a', 'Alpha'), ('b', 'Beta')]) {
          final icon = tester.getCenter(find.byKey(Key('icon-$name')));
          final label = tester.getCenter(find.text(text));
          expect(
            ltr ? icon.dx < label.dx : icon.dx > label.dx,
            isTrue,
            reason: 'the icon of $text precedes it in reading order',
          );
        }

        Color? colorOf(String name) =>
            IconTheme.of(tester.element(find.byKey(Key('icon-$name')))).color;
        final selectedColor = colorOf('a');
        final idleColor = colorOf('b');
        expect(selectedColor, isNot(idleColor));

        await tester.tap(find.text('Beta'));
        await tester.pumpAndSettle();
        expect(values.value, {'a', 'b'});
        expect(colorOf('b'), selectedColor);

        await tester.tap(find.text('Alpha'));
        await tester.pumpAndSettle();
        expect(values.value, {'b'});
        expect(colorOf('a'), idleColor);
      },
    );
  }
}
