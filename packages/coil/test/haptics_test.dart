import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plays [event] under a theme with [haptics] and returns the haptic
/// feedback calls sent to the platform.
Future<List<Object?>> _play(
  WidgetTester tester,
  CoilHapticEvent event, {
  CoilHaptics? haptics,
}) async {
  final played = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') played.add(call.arguments);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  late BuildContext context;
  await tester.pumpWidget(
    CoilTheme(
      data: CoilThemeData(haptics: haptics),
      child: Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    ),
  );
  await CoilHaptics.play(context, event);
  return played;
}

void main() {
  testWidgets(
    'iOS plays its conventions by default',
    (tester) async {
      expect(await _play(tester, .toggle), [
        'HapticFeedbackType.selectionClick',
      ]);
      expect(await _play(tester, .detent), ['HapticFeedbackType.lightImpact']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Android plays nothing for a toggle, a click for a copy',
    (tester) async {
      expect(await _play(tester, .toggle), isEmpty);
      expect(await _play(tester, .copy), ['HapticFeedbackType.selectionClick']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'the theme remaps or silences them',
    (tester) async {
      expect(
        await _play(
          tester,
          .toggle,
          haptics: const CoilHaptics(toggle: .heavyImpact),
        ),
        ['HapticFeedbackType.heavyImpact'],
      );
      expect(
        await _play(tester, .toggle, haptics: CoilHaptics.none),
        isEmpty,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
