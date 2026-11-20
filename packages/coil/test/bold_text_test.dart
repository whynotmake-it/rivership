import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bold text makes regular roles semibold', (tester) async {
    late CoilTextTheme plain;
    late CoilTextTheme bold;
    Widget probe(void Function(CoilTextTheme) out, {required bool boldText}) =>
        MediaQuery(
          data: MediaQueryData(boldText: boldText),
          child: Builder(
            builder: (context) {
              out(CoilTheme.of(context).typography.pointer);
              return const SizedBox();
            },
          ),
        );
    await tester.pumpWidget(
      CoilTheme(
        data: CoilThemeData.light,
        child: Column(
          children: [
            probe((t) => plain = t, boldText: false),
            probe((t) => bold = t, boldText: true),
          ],
        ),
      ),
    );
    expect(plain.body.fontWeight ?? FontWeight.normal, FontWeight.normal);
    expect(bold.body.fontWeight, FontWeight.w600);
    expect(bold.display.fontWeight, plain.display.fontWeight);
  });

  test('a variable font weight axis follows', () {
    final theme = CoilThemeData.light.copyWith(
      typography: CoilThemeData.light.typography.map(
        (role) => role.copyWith(
          fontVariations: const [FontVariation.weight(400)],
        ),
      ),
    );
    final body = theme.boldText().typography.pointer.body;
    expect(body.fontVariations, const [FontVariation.weight(600)]);
  });
}
