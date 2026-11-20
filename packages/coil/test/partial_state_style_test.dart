import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A state property that names only the hovered state, so it resolves to
/// null at rest.
WidgetStateProperty<Color?> hoverOnly(Color color) =>
    WidgetStateProperty<Color?>.fromMap({WidgetState.hovered: color});

const _red = Color(0xFFFF0000);

Widget _app(Widget child, {CoilThemeData Function(CoilThemeData)? theme}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: CoilTheme(
        data: (theme ?? (t) => t)(CoilThemeData.light),
        child: Center(child: SizedBox(width: 320, child: child)),
      ),
    );

const _options = [
  CoilOption(value: 0, label: Text('One'), searchText: 'One'),
  CoilOption(value: 1, label: Text('Two'), searchText: 'Two'),
];

void main() {
  group('CoilComponentStyle.mergeStates', () {
    test('falls back per state and compares by value', () {
      const base = WidgetStatePropertyAll<Color?>(Color(0xFF000000));
      final merged = CoilComponentStyle.mergeStates(base, hoverOnly(_red))!;
      expect(merged.resolve({}), const Color(0xFF000000));
      expect(merged.resolve({WidgetState.hovered}), _red);
      expect(
        CoilComponentStyle.mergeStates(base, hoverOnly(_red)),
        merged,
      );
      expect(CoilComponentStyle.mergeStates(base, null), same(base));
      expect(CoilComponentStyle.mergeStates<Color>(null, base), same(base));
    });

    test('a style merge keeps the lower layer for unnamed states', () {
      const fallback = CoilButtonStyle(
        fill: WidgetStatePropertyAll(Color(0xFF000000)),
      );
      final merged = fallback.merge(CoilButtonStyle(fill: hoverOnly(_red)));
      expect(merged.fill!.resolve({}), const Color(0xFF000000));
      expect(merged.fill!.resolve({WidgetState.hovered}), _red);
      expect(
        merged,
        fallback.merge(CoilButtonStyle(fill: hoverOnly(_red))),
      );
    });
  });

  group('a partial state override renders at rest', () {
    final cases = <String, (Widget, CoilThemeData Function(CoilThemeData))>{
      'button (style:)': (
        CoilButton(
          onPressed: () {},
          style: CoilButtonStyle(
            fill: hoverOnly(_red),
            foreground: hoverOnly(_red),
          ),
          child: const Text('Save'),
        ),
        (t) => t,
      ),
      'button (theme)': (
        CoilButton(onPressed: () {}, child: const Text('Save')),
        (t) => t.withComponentStyle(CoilButtonStyle(fill: hoverOnly(_red))),
      ),
      'input': (
        CoilInput(
          style: CoilInputStyle(fill: hoverOnly(_red), border: hoverOnly(_red)),
        ),
        (t) => t,
      ),
      'input message': (
        CoilInputMessage(onSend: (_) {}),
        (t) => t.withComponentStyle(
          CoilInputStyle(fill: hoverOnly(_red), border: hoverOnly(_red)),
        ),
      ),
      'tabs': (
        CoilTabs(
          tabs: const [
            CoilTab(value: 0, label: Text('A')),
            CoilTab(value: 1, label: Text('B')),
          ],
          value: 0,
          onChanged: (_) {},
          style: CoilTabsStyle(label: hoverOnly(_red)),
        ),
        (t) => t,
      ),
      'toggle group': (
        CoilToggleGroup<int>(
          values: const {0},
          onChanged: (_) {},
          options: _options,
          style: CoilToggleGroupStyle(label: hoverOnly(_red)),
        ),
        (t) => t,
      ),
      'checkbox group': (
        CoilCheckboxGroup<int>(
          values: const {0},
          onChanged: (_) {},
          options: _options,
          style: CoilCheckboxGroupStyle(label: hoverOnly(_red)),
        ),
        (t) => t,
      ),
      'radio group': (
        CoilRadioGroup<int>(
          value: 0,
          onChanged: (_) {},
          options: _options,
          style: CoilRadioGroupStyle(
            label: hoverOnly(_red),
            border: hoverOnly(_red),
          ),
        ),
        (t) => t,
      ),
      'accordion (disclosure trigger)': (
        CoilAccordion<int>.single(
          value: null,
          onChanged: (_) {},
          items: const [
            CoilAccordionItem(value: 0, label: Text('A'), panel: Text('a')),
          ],
          style: CoilAccordionStyle(
            triggerFill: hoverOnly(_red),
            label: hoverOnly(_red),
          ),
        ),
        (t) => t,
      ),
    };
    for (final MapEntry(key: name, value: (widget, theme)) in cases.entries) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(_app(widget, theme: theme));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
