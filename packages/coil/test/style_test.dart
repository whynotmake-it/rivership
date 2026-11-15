import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {CoilThemeData theme = CoilThemeData.light}) =>
    WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, _) => CoilTheme(
        data: theme.copyWith(tier: CoilTier.pointer),
        child: Center(child: child),
      ),
    );

Finder _box(Finder of) =>
    find.descendant(of: of, matching: find.byType(Container));

void main() {
  test('styles merge field by field, the other side winning', () {
    const a = CoilButtonStyle(radius: 4, iconSize: 12);
    const b = CoilButtonStyle(radius: 10);
    final merged = a.merge(b);
    expect(merged.radius, 10);
    expect(merged.iconSize, 12);
    expect(a.merge(null), a);
  });

  test('styles have value equality and live in the theme by type', () {
    expect(const CoilInputStyle(radius: 3), const CoilInputStyle(radius: 3));
    final theme = CoilThemeData.light
        .withComponentStyle(const CoilButtonStyle(radius: 3))
        .withComponentStyle(const CoilButtonStyle(iconSize: 20));
    expect(theme.componentStyle<CoilButtonStyle>()!.radius, 3);
    expect(theme.componentStyle<CoilButtonStyle>()!.iconSize, 20);
    expect(theme.componentStyle<CoilInputStyle>(), isNull);
    expect(
      theme,
      CoilThemeData.light
          .withComponentStyle(const CoilButtonStyle(radius: 3))
          .withComponentStyle(const CoilButtonStyle(iconSize: 20)),
    );
  });

  testWidgets('fallback < theme type override < instance style', (
    tester,
  ) async {
    const red = Color(0xFFFF0000);
    const blue = Color(0xFF0000FF);
    Color trackOf() {
      final decoration =
          tester
                  .widget<Container>(
                    _box(find.byType(CoilSwitch)).first,
                  )
                  .decoration!
              as ShapeDecoration;
      return decoration.color!;
    }

    await tester.pumpWidget(_app(CoilSwitch(value: true, onChanged: (_) {})));
    expect(trackOf(), CoilThemeData.light.colors.brand);

    final themed = CoilThemeData.light.withComponentStyle(
      const CoilSwitchStyle(track: WidgetStatePropertyAll(red)),
    );
    await tester.pumpWidget(
      _app(CoilSwitch(value: true, onChanged: (_) {}), theme: themed),
    );
    expect(trackOf(), red);

    await tester.pumpWidget(
      _app(
        CoilSwitch(
          value: true,
          onChanged: (_) {},
          style: const CoilSwitchStyle(track: WidgetStatePropertyAll(blue)),
        ),
        theme: themed,
      ),
    );
    expect(trackOf(), blue);
  });

  testWidgets('a subtree override merges onto the parent style', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CoilTheme.override(
          transform: (t) =>
              t.withComponentStyle(const CoilCheckboxStyle(size: 30)),
          child: CoilCheckbox(value: true, onChanged: (_) {}),
        ),
        theme: CoilThemeData.light.withComponentStyle(
          const CoilCheckboxStyle(borderWidth: 3),
        ),
      ),
    );
    final box = tester.getSize(_box(find.byType(CoilCheckbox)).first);
    expect(box, const Size.square(30));
  });
}
