import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _options = [
  CoilOption(value: 'a', label: Text('Alpha'), searchText: 'Alpha'),
  CoilOption(value: 'b', label: Text('Beta'), searchText: 'Beta'),
];

/// Each toggle-type control, built so that tapping "Beta" (or the control
/// itself) changes its value.
final _controls = <String, Widget Function(ValueChanged<Object?> changed)>{
  'switch': (changed) =>
      CoilSwitch(value: false, onChanged: changed, label: const Text('Beta')),
  'checkbox': (changed) => Row(
    children: [
      CoilCheckbox(value: false, onChanged: changed),
      const Text('Beta'),
    ],
  ),
  'radio group': (changed) =>
      CoilRadioGroup<String>(options: _options, value: 'a', onChanged: changed),
  'checkbox group': (changed) => CoilCheckboxGroup<String>(
    options: _options,
    values: const {'a'},
    onChanged: changed,
  ),
  'toggle group': (changed) => CoilToggleGroup<String>(
    options: _options,
    values: const {'a'},
    onChanged: changed,
  ),
};

void main() {
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });

  for (final MapEntry(key: name, value: build) in _controls.entries) {
    testWidgets(
      '$name: a change clicks on iOS only',
      (tester) async {
        var changes = 0;
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xFF000000),
            builder: (context, _) => CoilTheme(
              data: CoilThemeData.light,
              child: Center(child: build((_) => changes++)),
            ),
          ),
        );
        final target = name == 'checkbox'
            ? find.byType(CoilCheckbox)
            : find.text('Beta').first;
        await tester.tap(target);
        await tester.pumpAndSettle();

        expect(changes, 1);
        expect(
          haptics,
          debugDefaultTargetPlatformOverride == TargetPlatform.iOS
              ? ['HapticFeedbackType.selectionClick']
              : isEmpty,
        );
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
    );
  }
}
