import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a window shorter than its margins lays out without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 40)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: CoilTheme(
            data: CoilThemeData.light,
            child: OverflowBox(
              maxHeight: 1000,
              child: CoilSettingsDialog<int>(
                title: const Text('Settings'),
                sections: [
                  CoilSettingsSection<int>(
                    value: 0,
                    label: const Text('General'),
                    builder: (context) => const Text('General panel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final errors = <Object>[];
    Object? e;
    while ((e = tester.takeException()) != null) {
      errors.add(e!);
    }
    expect(
      errors.where((e) => '$e'.contains('BoxConstraints')),
      isEmpty,
    );
  });
}
